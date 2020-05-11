#!/usr/bin/guile -s
!#
(use-modules (ice-9 popen)
             (ice-9 rdelim)
             (srfi srfi-9))

;; parse-test-file-in parses a .test file containing a list of test metadata and produces a list of test records
;; generate-soft65c02-input takes a list of test records and creates an input string for running the tests
;; parse-test-file-out parses the result of the tests, and prints each pass or failure

;; Test metadata is arranged as such:
;;  The literal "name" on its own line
;;  A test name
;;  The literal "description" on its own line
;;  A test description
;;  The literal "rows" on its own line
;;  A number of 16-byte buffer rows to compare the actual and expected data across

(define-record-type <test>
  (make-test name desc rows)
  is_test?
  (name test-name)
  (desc test-desc)
  (rows test-rows))

(define (call-with-output-pipe cmd out-pred)
  (let* ((pipe (open-input-output-pipe cmd))
         (read_result (out-pred pipe))
         (status (close-pipe pipe)))
    (and status read_result)))

(define (call-with-input-output-pipe cmd in-pred out-pred)
  (let* ((pipe (open-input-output-pipe cmd))
         (write_result (in-pred pipe))
         (read_result (out-pred pipe))
         (status (close-pipe pipe)))
    (and status write_result read_result)))

(define (read-nonempty-line port)
  (let ((line (read-line port)))
    (if (eof-object? line)
      line
      (if (or (string=? line "") ;; Ignore empty line
              (string=? (string-take line 1) "#")) ;; Ignore line starting with comments
        (read-nonempty-line port)
        line))))

(define (generate-soft65c02-input test-list)
  (define (continue test-list generated)
    (if (eqv? test-list '())
      generated
      (let ((head (car test-list)))
          (continue (cdr test-list)
                    (string-append generated
                                   "registers show\n"
                                   "memory show #0x5000 " (number->string (test-rows head)) "\n"
                                   "memory show #0x6000 " (number->string (test-rows head)) "\n"
                                   "run until #0x7FFF > 0x00\n")))))
  (continue test-list
            (string-append
              "memory load #0x8000 \"out/test.bin\"\n"
              "run init until #0x7FFF > 0x00\n")))

(define (parse-test-name port)
  (define (parse port name)
    (let ((line (read-nonempty-line port)))
      (cond
        ((eof-object? line)
          #f)
        ((string-ci=? line "name")
          (parse port name))
        ((string-ci=? line "description")
          name)
        (#t
          (parse port (string-append name line " "))))))
  (parse port ""))

(define (parse-test-desc port)
  (define (parse port desc)
    (let ((line (read-nonempty-line port)))
      (if (eof-object? line)
        #f
        (if (string-ci=? line "rows")
          desc
          (parse port (string-append desc line " "))))))
  (parse port ""))

(define (parse-test-rows port)
  (let ((line (read-nonempty-line port)))
    (if (eof-object? line)
      #f
      (string->number line))))

(define (parse-test port)
  (let* ((name (parse-test-name port))
         (desc (and name (parse-test-desc port)))
         (rows (and desc (parse-test-rows port))))
      (and name desc rows (make-test name desc rows))))

(define (parse-test-file-in port)
  (define (continue port test-list)
    (let ((test (parse-test port)))
      (if test
        (continue port (cons test test-list))
        (reverse test-list))))
  (continue port '()))

(define (parse-test-file-out port test-list)
  (define (continue port test-list test-number compare-stack)
    (let ((line (read-line port)))
      (if (eof-object? line)
        #t
        (cond
          ;; Case "R" ex
          ;; Registers [A:0x04, X:0x02, Y:0x02 | SP:0xfd, CP:0x930d | nv-BdIzc]
          ((string=? "R" (string-take line 1))
            (let* ((register-a (substring line 15 17))
                   (register-x (substring line 23 25))
                   (test-number (- (string->number (string-append register-x register-a) 16) 1)))
               (continue port test-list test-number compare-stack)))

          ;; Case "#5" ex
          ;; #5000:  fd 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00
          ((string=? "#5" (string-take line 2))
            (continue port test-list test-number (cons line compare-stack)))

          ;; Case "#6" ex
          ;; #6000:  fd 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00
          ((string=? "#6" (string-take line 2))
            (let* ((actual-full line)
                   (actual (string-drop actual-full 8))
                   (expected-full (car (reverse compare-stack)))
                   (expected (string-drop expected-full 8)))
              (if (string=? actual expected)
                (begin
                  (display (string-append "    " (test-name (list-ref test-list test-number)) "- pass\n"))
                  (continue port test-list test-number (reverse (cdr (reverse compare-stack)))))
                (begin
                  (display (string-append
                             "    FAIL\n      " (test-name (list-ref test-list test-number)) "\n"
                             "      Description: " (test-desc (list-ref test-list test-number)) "\n"
                             "      expected:\n        " expected-full "\n"
                             "      actual:\n        "   actual-full "\n"))
                  #f))))
          (#t (begin
                (display (string-append
                             "Got unexpected string: "
                             line "\n"))
                  #f))))))
  (continue port test-list 0 '()))

(let* ((name (cadr (command-line)))
       (file_test (string-append "test/" name ".test"))
       (file_asm  (string-append "test/" name "_test.asm"))
       (file_out  "out/test.o"))
  (and
    (eq? (status:exit-val (system* "ca65" "-t" "nes" file_asm "-g" "-o" file_out))
         EXIT_SUCCESS)
    (begin
      (display "  TEST: assembler ok!\n")
      (eq? (status:exit-val (system* "ld65" "-C" "test.cfg" "-o" "out/test.bin" "out/test.o"))
           EXIT_SUCCESS))
    (begin
      (display "  TEST: linker ok!\n")
      #t)
    (let* ((test-list (call-with-input-file file_test parse-test-file-in))
           (generated (generate-soft65c02-input test-list))
           (write-test-input (lambda (port) (display generated port)))
           (read-test-output (lambda (port)
                               (parse-test-file-out port test-list))))
      (and
        (call-with-output-file "test.run" write-test-input)
        (call-with-output-pipe
          (string-append "cat \"test.run\" | soft65c02 -s | rg \"Registers|#5|#6\"")
          read-test-output)))
    (begin
      (display "  TEST: all tests pass!\n")
      #t)))
