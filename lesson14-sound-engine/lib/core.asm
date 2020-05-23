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
  .scope ;; anonymous
      INC mem_loc
      BNE no_carry
      INC mem_loc+1
    no_carry:
  .endscope
.endmacro

.macro INC16_X mem_loc
  .scope ;; anonymous
      INC mem_loc,X
      BNE no_carry
      INC mem_loc+1,X
    no_carry:
  .endscope
.endmacro

;; Multiply two 8 bit numbers stored in A and X.
;; The result is a 16 bit number, stored in A-lo X-hi
.proc Mul8
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

;;;; RotateBufferRight
;; 0-byte stack frame: 0 args, 0 return
;; Expects PLO and PHI to hold the address of a buffer
;; Expects r0 to hold the len of the buffer
;; Expects r1 to hold the amount to rotate by
.proc RotateBufferRight
    ;; Arguments
    srcLo       = PLO
    srcHi       = PHI
    bufferLen   = r0
    shiftAmount = r1

    ;; Locals
    temp = STACK+4
    swap = STACK+3
    counter = STACK+2
    startIndex = STACK+1

    ;; Guard clause
    LDA bufferLen
    BEQ @early_return
    LDA shiftAmount
    BNE continue
  @early_return:
    RTS
  continue:

    ;; Adjust shiftAmount until its range [0,bufferLen)
    LDA shiftAmount
  @modulo_buffer_len:
    SEC
    SBC bufferLen
    BCC @modulo_done
  @modulo_loop:
    TAX
    SEC
    SBC bufferLen
    BCS @modulo_loop
    STX shiftAmount
  @modulo_done:

    ;; Set up stack locals
    PHA ;; temp
    PHA ;; swap
    PHA ;; counter
    PHA ;; startIndex
    TSX

    ;; Main loop
    LDA bufferLen
    STA counter,X
    LDY #$FF
  shift_from_index:
    INY
    TYA
    STA startIndex,X
    LDA (srcLo),Y
    STA temp,X
  loop:

    ;; Add index and wrap if needed
    TYA
    CLC
    ADC shiftAmount
    BCC @when_no_overflow
  ;; In the rare case we overflow, we manually wrap. Correct wrap position is shiftAmount - (bufferLen - Y)
    TYA
    STA swap,X
    LDA bufferLen
    SEC
    SBC swap,X
    STA swap,X
    LDA shiftAmount
    SEC
    SBC swap,X
    TAY
    JMP @no_wrap
  ;; Otherwise, apply wrap if needed as normal
  @when_no_overflow:
    TAY
    SEC
    SBC bufferLen
    BCC @no_wrap
    TAY
  @no_wrap:
    LDA (srcLo),Y
    STA swap,X
    LDA temp,X
    STA (srcLo),Y

    ;; After bufferLen writes, we're done
    DEC counter,X
    BEQ done

    TYA
    CMP startIndex,X
    BEQ shift_from_index ;; If we've come full circle to the start index, repeat the process starting from start+1
                         ;; Else, continue by preparing the next temp and looping
    LDA swap,X
    STA temp,X
    JMP loop
  done:
    PLA ;; startIndex
    PLA ;; counter
    PLA ;; swap
    PLA ;; temp
    RTS
.endproc
