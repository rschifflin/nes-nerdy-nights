;; Run using soft65c02, see test.sh
;; Expected output has the memory space $5000-$5FFF
;; Actual output has the memory space $6000-$6FFF
;; Test control flags have the memory space $7000-$7FFF
;; Program ROM at $8000 - $FFFF
;; Tests should have four parts:
;;   Fill the expected buffer with values
;;   Run
;;   Fill the actual buffer with return values
;;   Call the SHOW macro
;; The testrunner assumes test output is printed when 0x7fff becomes 1
;; The testrunner assumes a program breakpoint is hit when 0x7fff becomes 2
TEST_EXPECTED = $5000
TEST_ACTUAL   = $6000

TEST_COUNT_TOTAL_LO      = $7FFC
TEST_COUNT_TOTAL_HI      = $7FFD
TEST_RESERVED            = $7FFE ;; Dunno what to do with this yet
TEST_SHOW                = $7FFF

.include "../defs/core.def"

.segment "ZEROPAGE"
ZEROBYTE: .res 1 ;; Bug in soft65c02 maybe? Cant INC byte so we start our zp at 1
.include "../mem/core.zp.asm"

.segment "BSS"
.include "../mem/stack.bss.asm"

.segment "IVT"
  .addr 0       ;; Non-maskable interrupt
  .addr RESET   ;; Processor turns on or reset button is pressed
  .addr 0       ;; Other interrupts.
.segment "PRG" ;; Fixed PRG ROM. Always present
;; Entrypoint, sets up the test harness.
RESET:
  SEI     ;; Disable IRQs
  CLD     ;; Disable decimal mode (NES 6502s dont have a decimal mode)

  LDA #$00
  TAX
clear_stack:
  STA $0100, x
  INX
  BNE clear_stack
  DEX ;; X -> $FF
  TXS ;; Set stack pointer to $FF
  ;;;;
  JMP run

.macro TEST subroutine
  LDA TEST_COUNT_TOTAL_LO
  CLC
  ADC #$01
  STA TEST_COUNT_TOTAL_LO
  LDA TEST_COUNT_TOTAL_HI
  ADC #$00
  STA TEST_COUNT_TOTAL_HI
  JSR TestClearRAM
  JSR TestClearExpectedValue
  JSR TestClearActualValue
  JSR subroutine
.endmacro
.macro SHOW
  LDA TEST_COUNT_TOTAL_LO
  LDX TEST_COUNT_TOTAL_HI
  LDY TEST_RESERVED
  INC TEST_SHOW
  DEC TEST_SHOW
.endmacro
.macro BREAKPOINT
  PHA
  LDA #$02
  STA TEST_SHOW
  LDA #$00
  STX TEST_SHOW
  PLA
.endmacro

;; Helpful libraries go here
.include "../lib/core.asm"
.include "../lib/stack.asm"

palette:
  .include "../data/palette.asm"

name_table:
  .include "../data/name_table.asm"

attribute_table:
  .include "../data/attr_table.asm"

sprites:
  .include "../data/sprites.asm"

strings:
  .include "../data/strings.asm"

;; Takes PLO,PHI to be a ptr to a 4kb block of mem to be zeroed
.proc TestClearLoop
    LDA #$00
    LDX #$10
    LDY #$00
  loop:
    STA (PLO),Y
    INY
    BNE loop
    INC PHI
    DEX
    BNE loop
  RTS
.endproc
.proc TestClearExpectedValue
    LDA #<TEST_EXPECTED
    STA PLO
    LDA #>TEST_EXPECTED
    STA PHI
    JMP TestClearLoop ;; tail call
.endproc
.proc TestClearActualValue
    LDA #<TEST_ACTUAL
    STA PLO
    LDA #>TEST_ACTUAL
    STA PHI
    JMP TestClearLoop ;; tail call
.endproc
.proc TestClearRAM
    LDA #<PHI+1
    STA PLO
    LDA #<PHI+2
    STA PHI
    JSR TestClearLoop ;; tail call
    LDA #$00
    STA SP
    STA PLO
    STA PHI
    RTS
.endproc

run:
  LDA #$00
  STA TEST_COUNT_TOTAL_LO
  STA TEST_COUNT_TOTAL_HI
  STA TEST_RESERVED
  JSR RunTests
  BRK
