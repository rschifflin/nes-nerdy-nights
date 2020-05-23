;; Harness includes stack by default
.include "harness.asm"

integers:
  .repeat 255, n
    .byte n
  .endrepeat

.macro PushIntegers count
  .scope ;; anonymous
      LDY #$00

    loop_expected:
      LDA integers,Y
      STA TEST_EXPECTED,Y
      PHA_SP
      INY
      CPY #count
      BNE loop_expected

      LDY #$00
    loop_actual:
      LDA SW_STACK,Y
      STA TEST_ACTUAL,Y
      INY
      CPY #count
      BNE loop_actual

      SHOW
  .endscope
.endmacro

.macro PullIntegers count
  .scope ;; anonymous
      LDY #$00
    loop_expected:
      LDA integers,Y
      STA TEST_EXPECTED,Y
      INY
      CPY #count
      BNE loop_expected

      LDX #$00
      LDY #count
    loop_fill_stack:
      DEY
      LDA integers,X
      STA SW_STACK,Y
      INX
      CPY #$00
      BNE loop_fill_stack

      LDA #count
      STA SP

      LDY #$00
    loop_actual:
      PLA_SP
      STA TEST_ACTUAL,Y
      INY
      CPY #count
      BNE loop_actual

      SHOW
  .endscope
.endmacro

.proc TestPush1
    PushIntegers 1
    RTS
.endproc

.proc TestPush55
    PushIntegers 55
    RTS
.endproc

.proc TestPush255
    PushIntegers 255
    RTS
.endproc

.proc TestPull1
    PullIntegers 1
    RTS
.endproc

.proc TestPull133
    PullIntegers 133
    RTS
.endproc

.proc TestPull255
    PullIntegers 255
    RTS
.endproc

.proc TestPushPull
    LDY #$00
  loop_expected:
    LDA integers,Y
    STA TEST_EXPECTED,Y
    INY
    CPY #$40 ;; Expect to finish with 64
    BNE loop_expected


  push_92: ;; Stack holds 0-91
    LDY #$00
  @loop:
    LDA integers,Y
    PHA_SP
    INY
    CPY #$5c
    BNE @loop

  pull_50: ;; Stack holds 0-41
    LDY #$32
  @loop:
    PLA_SP
    DEY
    BNE @loop

  push_83: ;; Stack holds 0-124
    LDY #$2A
  @loop:
    LDA integers,Y
    PHA_SP
    INY
    CPY #$7D
    BNE @loop

  pull_64: ;; Stack holds 0-63
    LDY #$3D
  @loop:
    PLA_SP
    DEY
    BNE @loop

    LDX #$40
  loop_actual:
    LDA SW_STACK,X
    STA TEST_ACTUAL,X
    DEX
    BNE loop_actual

    SHOW
    RTS
.endproc

.proc TestPushN
    LDA #$9A
    STA TEST_EXPECTED
    PHN_SP 154

    LDA SP
    STA TEST_ACTUAL
    SHOW
    RTS
.endproc

.proc TestPullN
    LDA #$3F
    STA TEST_EXPECTED
    LDA #$FF
    STA SP
    PLN_SP 192

    LDA SP
    STA TEST_ACTUAL
    SHOW
    RTS
.endproc

.proc RunTests
  TEST TestPush1    ;; Test 0
  TEST TestPush55   ;; Test 1
  TEST TestPush255  ;; Test 2

  TEST TestPull1    ;; Test 3
  TEST TestPull133  ;; Test 4
  TEST TestPull255  ;; Test 5

  TEST TestPushPull ;; Test 6
  TEST TestPushN    ;; Test 7
  TEST TestPullN    ;; Test 8
  RTS
.endproc
