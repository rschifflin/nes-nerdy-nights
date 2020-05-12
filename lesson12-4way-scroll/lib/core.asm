.macro PUSH_IRQ
  PHA ;; Push A
  TXA ;; X->A
  PHA ;; Push X
  TYA ;; Y->A
  PHA ;; Push Y
  LDA SP
  PHA ;; Push stack pointer offset
  LDA PLO
  PHA ;; Push ptrLo
  LDA PHI
  PHA ;; Push ptrHi
  LDA r0
  PHA ;; Push r0
  LDA r1
  PHA ;; Push r1
.endmacro

.macro POP_IRQ
  PLA ;; Pull r1
  STA r1
  PLA ;; Pull r0
  STA r0
  PLA ;; Pull ptrHi
  STA PHI
  PLA ;; Pull ptrLo
  STA PLO
  PLA ;; Pull stack pointer offset
  STA SP
  PLA ;; Pull Y
  TAY ;; A->Y
  PLA ;; Pull X
  TAX ;; A->X
  PLA ;; Pull A
.endmacro

.macro STA_TWOS_COMP mem_loc
  LDA #$FF
  SEC
  SBC mem_loc
  ADC #$00
  STA mem_loc
.endmacro

.macro INC16 mem_loc
.scope
    INC mem_loc
    BNE no_carry
    INC mem_loc+1
  no_carry:
.endscope
.endmacro

;;;; AdcDec
;; 0-byte stack frame: 0 args, 0 return
;; Acts like ADC but only operates on two decimal bytes guaranteed to be between 0-9.
;; Result is a decimal byte 0-9, with the carry bit indicating overflow
;; Sets Carry bit on oveflow
;; A <- Augend in decimal
;; X <- Addend in decimal
;; A -> Sum
.proc AdcDec
    STX r0
    ADC r0
    CMP #$0A
    BCC done ; done if result < 10
    SEC
    SBC #$0A

    SEC ;; Indicate overflow
  done:
    RTS
.endproc
;;;;
