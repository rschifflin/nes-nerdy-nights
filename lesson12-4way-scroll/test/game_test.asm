.include "harness.asm"
.include "../lib/game.asm"

;; Test value of x becomes 0 when limits are low
.proc BoundsCheckDeltaUnderflow
    ;; Expected: cam_dx adjusted to -2
    LDA #$02
    STA TEST_EXPECTED
    STA_TWOS_COMP TEST_EXPECTED

    LDA #$04
    STA cam_dx
    STA_TWOS_COMP cam_dx
    LDA #$02
    STA cam_x
    LDA #$00
    STA cam_x+1

    JSR CheckBounds

    ;; Actual:
    LDA cam_dx
    STA TEST_ACTUAL
    SHOW
  done:
  RTS
.endproc

.proc BoundsCheckDeltaOverflow
    ;; Expected: cam_dx adjusted to +1
    LDA #$01
    STA TEST_EXPECTED

    LDA #$07
    STA cam_dx
    LDA #$FF
    STA cam_x
    LDA #$02
    STA cam_x+1

    JSR CheckBounds

    ;; Actual:
    LDA cam_dx
    STA TEST_ACTUAL
    SHOW
  done:
  RTS
.endproc

.proc BoundsCheckDeltaSafeNegative
    ;; Expected: cam_dx stays -3
    LDA #$03
    STA TEST_EXPECTED
    STA_TWOS_COMP TEST_EXPECTED
    STA cam_dx

    LDA #$02
    STA cam_x
    LDA #$01
    STA cam_x+1

    JSR CheckBounds

    ;; Actual:
    LDA cam_dx
    STA TEST_ACTUAL
    SHOW
  done:
  RTS
.endproc

.proc BoundsCheckDeltaSafePositive
    ;; Expected: cam_dx stays +4
    LDA #$04
    STA TEST_EXPECTED
    STA cam_dx

    LDA #$FE
    STA cam_x
    LDA #$01
    STA cam_x+1

    JSR CheckBounds

    ;; Actual:
    LDA cam_dx
    STA TEST_ACTUAL
    SHOW
  done:
  RTS
.endproc

.proc RunTests
  TEST BoundsCheckDeltaUnderflow    ;; Test 0
  TEST BoundsCheckDeltaOverflow     ;; Test 1
  TEST BoundsCheckDeltaSafeNegative ;; Test 2
  TEST BoundsCheckDeltaSafePositive ;; Test 3
  RTS
.endproc
