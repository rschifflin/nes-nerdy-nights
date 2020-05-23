#!/usr/local/bin/guile -s
!#
(use-modules (ice-9 popen)
             (ice-9 rdelim)
             (ice-9 ftw)
             (ice-9 sandbox)
             (srfi srfi-1)
             (srfi srfi-9)
             (srfi srfi-13))

;; parse-test-file-in reads a .scm file containing a sequence of scheme expressions evaluating to test records and returns a list of records
;; generate-soft65c02-input takes a list of test records and creates an input string for running the tests
;; parse-test-file-out parses the result of the tests, and prints each pass or failure

;; Test records can be defined with a descriptive syntatic wrapper
;;  (asm-test
;;    (name "my test name")
;;    (description "my test description"
;;                 "multiple strings are ok"
;;                 "they get concatenated with a space separator")
;;    (rows 3)) ;; Optional, defaults to 1 row
;;  Rows are a number of 16-byte buffer rows to compare the actual and expected data across

(define-record-type <asm-test>
  (make-asm-test name desc rows)
  is-asm-test?
  (name asm-test-name)
  (desc asm-test-desc)
  (rows asm-test-rows))

(define-syntax asm-test
  (syntax-rules .. ()
    ((asm-test asm-defs ..)
     (begin
       (define-syntax asm-test-builder
         (syntax-rules (name description rows body)
           ((_ body name-arg description-arg rows-arg) ;; Base case pattern
             (cond
               ((not (string? name-arg))
                (raise-exception (list "Bad asm-test format in name field. Expected string, got " name-arg)))
               ((not (string? description-arg))
                (raise-exception (list "Bad asm-test format in description field. Expected string, got " description-arg)))
               ((not (number? rows-arg))
                (raise-exception (list "Bad asm-test format in rows field. Expected number, got " rows-arg)))
               (#t (make-asm-test name-arg description-arg rows-arg))))

           ((_ (name str strings ...) exprs ... body _ description-arg rows-arg) ;; Name pattern
            (let ((name-arg (string-join (list str strings ...))))               ;; Name template
              (asm-test-builder exprs ... body name-arg description-arg rows-arg)))

           ((_ (description str strings ...) exprs ... body name-arg _ rows-arg) ;; Desc pattern
            (let ((description-arg (string-join (list str strings ...))))        ;; Desc template
              (asm-test-builder exprs ... body name-arg description-arg rows-arg)))

           ((_ (rows n) exprs ... body name-arg description-arg _) ;; Row pattern
            (let ((rows-arg n))                                    ;; Row template
              (asm-test-builder exprs ... body name-arg description-arg rows-arg)))))
       (asm-test-builder asm-defs .. body #f #f 1)))))

(define (asm-test-sandbox)
  (export asm-test)
  (let* ((symbols '(asm-test))
         (bindings (cons (module-name (current-module)) symbols)))
    (make-sandbox-module (cons bindings all-pure-bindings))))

(define (call-with-output-pipe cmd out-pred)
  (let* ((pipe (open-input-output-pipe cmd))
         (read_result (out-pred pipe))
         (status (close-pipe pipe)))
    (and status read_result)))

(define (generate-soft65c02-input test-list file-basename)
  (define (continue test-list generated)
    (if (null? test-list)
      generated
      (let ((current-test (car test-list)))
          (continue (cdr test-list)
                    (string-append generated
                                   "registers show\n"
                                   "memory show #0x5000 " (number->string (asm-test-rows current-test)) "\n"
                                   "memory show #0x6000 " (number->string (asm-test-rows current-test)) "\n"
                                   "run until #0x7FFF = 0x01\n")))))
  (continue test-list
            (string-append
              "memory load #0x8000 \"out/test/" file-basename ".bin\"\n"
              "run init until #0x7FFF = 0x01\n")))

(define (parse-test-file-in port)
  (define (continue port test-list)
    (let ((result (read port)))
      (if (eof-object? result)
        (reverse test-list)
        (let ((parsed (eval-in-sandbox result #:module (asm-test-sandbox))))
           (if (is-asm-test? parsed)
             (continue port (cons parsed test-list))
             #f)))))
  (continue port '()))

(define (parse-test-file-out port test-list)
  (define (continue port test-list test-number compare-stack)
    (let ((line (read-line port)))
      (if (eof-object? line)
        #t
        (cond
          ;; Case "R" ex
          ;; Registers [A:0x04, X:0x02, Y:0x02 | SP:0xfd, CP:0x930d | nv-BdIzc]
          ((string-prefix? "R" line)
            (let* ((register-a (substring line 15 17))
                   (register-x (substring line 23 25))
                   (test-number (- (string->number (string-append register-x register-a) 16) 1)))
               (continue port test-list test-number compare-stack)))

          ;; Case "#5" ex
          ;; #5000:  fd 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00
          ((string-prefix? "#5" line)
            (continue port test-list test-number (cons line compare-stack)))

          ;; Case "#6" ex
          ;; #6000:  fd 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00
          ((string-prefix? "#6" line)
            (let* ((actual-full line)
                   (actual (string-drop actual-full 8))
                   (expected-full (car (reverse compare-stack)))
                   (expected (string-drop expected-full 8)))
              (cond
                ((and (string=? actual expected) (null? (cdr compare-stack)))
                  (begin
                    (display (string-append "    " (asm-test-name (list-ref test-list test-number)) "- pass\n"))
                    (continue port test-list test-number (reverse (cdr (reverse compare-stack))))))
                ((string=? actual expected)
                  (continue port test-list test-number (reverse (cdr (reverse compare-stack)))))
                (else
                  (begin
                    (display (string-append
                               "  FAIL\n"
                               "    " (asm-test-name (list-ref test-list test-number)) "\n"
                               "      " (asm-test-desc (list-ref test-list test-number)) "\n"
                               "    expected:\n        " expected-full "\n"
                               "    actual:\n        "   actual-full "\n"))
                    #f)))))
          (#t (begin
                (display (string-append
                             "Got unexpected string: "
                             line "\n"))
                  #f))))))
  (continue port test-list 0 '()))

(define (lookup-test-file-basenames)
  (map (lambda (file-name) (basename file-name ".bin"))
       (scandir "out/test"
                (lambda (file-name) (string-suffix? ".bin" file-name)))))

(let* ((args (cdr (command-line)))
       (test-file-basenames (if (zero? (length args))
                    (lookup-test-file-basenames)
                    args)))
  (and
    (fold (lambda (test-file-basename last)
            (and
              last
              (begin (display (string-append "  TEST: " test-file-basename "\n")) #t)
              (let* ((test-file (string-append "test/" test-file-basename ".scm"))
                     (test-list (call-with-input-file test-file parse-test-file-in))
                     (generated (generate-soft65c02-input test-list test-file-basename))
                     (write-test-input (lambda (port) (display generated port)))
                     (read-test-output (lambda (port) (parse-test-file-out port test-list))))
                    (and
                      (call-with-output-file "out/test/test.run" write-test-input)
                      (call-with-output-pipe (string-append "cat \"out/test/test.run\" |"
                                                            "soft65c02 -s |"
                                                            "rg \"Registers|#5|#6\"")
                                             read-test-output)))))
          #t
          test-file-basenames)
    (begin
      (display "  TEST: all tests pass!\n")
      #t)))
