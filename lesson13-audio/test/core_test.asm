;; Harness includes core by default

.include "harness.asm"

integers:
  .repeat 255, n
    .byte n
  .endrepeat

.macro TestRotateBufferRightLenXAmountY LEN, SHIFT
  .scope ;; anonymous
      JMP test
    expected:
      .repeat SHIFT, n
        .byte n+(LEN-SHIFT)
      .endrepeat

      .repeat (LEN-SHIFT), n
        .byte n
      .endrepeat
    test:
      LDX #$00
    loop:
      LDA integers,X
      STA TEST_ACTUAL,X
      LDA expected,X
      STA TEST_EXPECTED,X
      INX
      CPX #LEN
      BNE loop

      LDA #<TEST_ACTUAL
      STA PLO
      LDA #>TEST_ACTUAL
      STA PHI

      LDA #LEN
      STA r0

      LDA #SHIFT
      STA r1

      JSR RotateBufferRight
      SHOW
  .endscope
.endmacro

.proc TestRotateBufferRightLen0
    LDA #$00
    STA PLO
    STA PHI
    STA r0
    STA r1
    JSR RotateBufferRight
    SHOW
    RTS
.endproc

.proc TestRotateBufferRightAmount0
    LDA #$00
    STA PLO
    STA PHI
    STA r1
    LDA #$FF
    STA r0 ;; Pretend there is a len

    JSR RotateBufferRight
    SHOW

    RTS
.endproc

.proc TestRotateBufferRightLen10Amount7
    TestRotateBufferRightLenXAmountY 10, 7
    RTS
.endproc

.proc TestRotateBufferRightLen6Amount2
    TestRotateBufferRightLenXAmountY 6, 2
    RTS
.endproc

.proc TestRotateBufferRightLen13Amount17
  ;; Note: No macro here since amount > len would break it
    JMP test
  expected:
    .byte $09, $0A, $0B, $0C
    .repeat 9, n
      .byte n
    .endrepeat
  test:
    LDX #$00
  loop:
    LDA integers,X
    STA TEST_ACTUAL,X
    LDA expected,X
    STA TEST_EXPECTED,X
    INX
    CPX #$0D
    BNE loop

    LDA #<TEST_ACTUAL
    STA PLO
    LDA #>TEST_ACTUAL
    STA PHI

    LDA #$0D
    STA r0 ;; len 13

    LDA #$11
    STA r1 ;; rotation 17

    JSR RotateBufferRight
    SHOW

    RTS
.endproc

.proc TestRotateBufferRightLen32Amount32
    TestRotateBufferRightLenXAmountY 32, 32
    RTS
.endproc

.proc TestRotateBufferRightLen255Amount197
    TestRotateBufferRightLenXAmountY 255, 197
    RTS
.endproc

.proc RunTests
  TEST TestRotateBufferRightLen0    ;; Test 0
  TEST TestRotateBufferRightAmount0    ;; Test 1
  TEST TestRotateBufferRightLen10Amount7    ;; Test 2
  TEST TestRotateBufferRightLen6Amount2    ;; Test 3
  TEST TestRotateBufferRightLen13Amount17    ;; Test 4
  TEST TestRotateBufferRightLen32Amount32    ;; Test 5
  TEST TestRotateBufferRightLen255Amount197  ;; Test 6
  RTS
.endproc
