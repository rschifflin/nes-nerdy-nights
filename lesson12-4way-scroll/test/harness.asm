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
TEST_EXPECTED = $5000
TEST_ACTUAL   = $6000

TEST_COUNT_TOTAL         = $7FFC
TEST_COUNT_CURRENT_FILE  = $7FFD
TEST_CURRENT_FILE        = $7FFE
TEST_SHOW                = $7FFF

.include "../data/constants.asm"

.segment "ZEROPAGE"
.include "../data/zp.asm"
.segment "BSS"
.include "../data/bss.asm"
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
.macro TEST subroutine
  INC TEST_COUNT_TOTAL
  INC TEST_COUNT_CURRENT_FILE
  JSR TestClearExpectedValue
  JSR TestClearActualValue
  JSR subroutine
.endmacro
.macro SHOW
  LDA TEST_COUNT_TOTAL
  LDX TEST_CURRENT_FILE
  LDY TEST_COUNT_CURRENT_FILE
  INC TEST_SHOW
  DEC TEST_SHOW
.endmacro

run:
  LDA #$00
  STA TEST_COUNT_TOTAL
  STA TEST_COUNT_CURRENT_FILE
  STA TEST_CURRENT_FILE

  INC TEST_CURRENT_FILE
  TEST XAtFloor ;; Test 1, File 1:1
  TEST XWithSpace ;; Test 2, File 1:2

  LDA $00
  STA TEST_COUNT_CURRENT_FILE
  INC TEST_CURRENT_FILE
  TEST XAtFloor ;; Test 3, File 2:1
  TEST XWithSpace ;; Test 4, File 2:2
