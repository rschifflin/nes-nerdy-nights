;; Uses ZEROPAGE byte $SP as software stack pointer offset
;; Note, the value at $SOFTWARE_STACK+$SP is the most-recently pushed data.
;; On the hardware stack, it points to the empty space of the _next_ value to be pushed.
;; Callee is responsible for pushing space for return value
;; Callee is responsible for popping the stack after

.macro PHA_SP
  INC SP
  LDX SP
  STA SW_STACK,X
.endmacro

.macro PLA_SP
  LDX SP
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
