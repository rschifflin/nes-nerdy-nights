#!/usr/bin/guile -s
!#
(use-modules (ice-9 popen)
             (ice-9 rdelim))

(define (do-open-input-pipe arg fn)
  (let* ((pipe (open-input-pipe arg))
         (result (fn pipe))
         (status (close-pipe pipe)))
    (and status result)))

;; TODO: Read simple test definition format
;; (define (interpret-test-in port)
  ;; Generate a list of test descriptions,
  ;; and output to feed to soft65c02
  ;; Exclude ;; comments
  ;; Exclude empty lines
  ;;
  ;; EX:
  ;; Name: MyTest
  ;; Description: Tests x against y
  ;; Compare lines: N (buffer size to compare)
;;)

(define (interpret-test-out port)
  (_interpret-test-out port 0 '()))
(define (_interpret-test-out port test-number compare-stack)
  (let ((line (read-line port)))
    (if (eof-object? line)
      #t
      (cond
        ;; Case "Registers [ A: 1, B: 2 ]"
        ;; Registers [A:0x04, X:0x02, Y:0x02 | SP:0xfd, CP:0x930d | nv-BdIzc]
        ;; Record byte at position A, B, C as Total Test, Current File, Current Test
        ((string=? "R" (string-take line 1))
          (let* ((register-a (substring line 15 17))
                 (register-x (substring line 23 25))
                 (test-number (string->number (string-append register-x register-a) 16)))
             (_interpret-test-out port test-number compare-stack)))

        ;; Case "#5" - push to compare-stack
        ;; #5000:  fd 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00
        ((string=? "#5" (string-take line 2))
          (_interpret-test-out port test-number (cons line compare-stack)))

        ;; Case "#6" - pop from compare-stack
        ;; #6000:  fd 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00
        ;; Pop from compare-stack and compare memory
        ;; If true, recurse
        ;; If false, print to stdout and return #f
        ((string=? "#6" (string-take line 2))
          (let* ((actual-full line)
                 (actual (string-drop actual-full 8))
                 (expected-full (car (reverse compare-stack)))
                 (expected (string-drop expected-full 8)))
            (if (string=? actual expected)
              (begin
                (display (string-append "  TEST " (number->string test-number) ": pass\n"))
                (_interpret-test-out port test-number (reverse (cdr (reverse compare-stack)))))
              (begin
                (display (string-append
                           "  TEST " (number->string test-number) ": FAIL\n"
                           "expected:\n  " expected-full "\n"
                           "actual:\n  "   actual-full "\n"))
                #f))))
        (#t (_interpret-test-out port test-number compare-stack))))))

(let* ((name (cadr (command-line)))
       (file_test (string-append "test/" name ".test"))
       (file_asm  (string-append "test/" name "_test.asm"))
       (file_out  "out/test.o"))
  (and
    (eq? (status:exit-val (system* "ca65" "-t" "nes" file_asm "-g" "-o" file_out))
         EXIT_SUCCESS)
    (begin (display "  TEST: assembler ok!\n") #t)
    (eq? (status:exit-val (system* "ld65" "-C" "test.cfg" "-o" "out/test.bin" "out/test.o"))
         EXIT_SUCCESS)
    (begin (display "  TEST: linker ok!\n") #t)
    (do-open-input-pipe
      (string-append "cat " file_test " | soft65c02 -s | rg \"Registers|#5|#6\"")
      interpret-test-out)
    (begin (display "  TEST: all tests pass!\n") #t)))
