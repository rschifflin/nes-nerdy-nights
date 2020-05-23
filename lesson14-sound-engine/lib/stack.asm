;; Uses ZEROPAGE byte $SP as software stack pointer offset
;; Note, the value at $SOFTWARE_STACK+$SP is the next spot to be pushed.
;; Callee is responsible for pushing space for return value
;; Callee is responsible for popping the stack after
;; Note, these calls preserve A but clobber X!

.macro PHA_SP
  LDX SP
  INC SP
  STA SW_STACK,X
.endmacro

.macro PLA_SP
  LDX SP
  DEX
  LDA SW_STACK,X
  DEC SP
.endmacro

.macro PLN_SP n
  LDA SP
  SEC
  SBC #n
  STA SP
.endmacro

.macro PHN_SP n
  LDA SP
  CLC
  ADC #n
  STA SP
.endmacro
