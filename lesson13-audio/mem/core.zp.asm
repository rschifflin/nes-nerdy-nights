;;;; Memory registers.
;; Interrupts should preserve these values to stay re-entrant
;; Much like the real registers A,X and Y, these may be clobbered by JSR.
SP:            .res 1 ; Software stack pointer
PLO:           .res 1 ; pointer reg used for indirection
PHI:           .res 1 ; pointer reg used for indirection
;;
r0:            .res 1 ; Simple re-usable byte register
r1:            .res 1 ; Simple re-usable byte register
;;;;
