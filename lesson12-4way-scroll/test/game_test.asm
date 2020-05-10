.include "harness.asm"
.include "../lib/game.asm"

;; Test value of x becomes 0 when limits are low
.proc XAtFloor
    ;; Expected: cam_dx becomes 0
    LDA #$00
    STA TEST_EXPECTED

    LDA #$03
    STA cam_dx
    STA_TWOS_COMP cam_dx
    LDA #$00
    STA cam_x
    STA cam_x+1

    JSR CheckBounds

    ;; Actual:
    LDA cam_dx
    STA TEST_ACTUAL
    SHOW
  done:
  RTS
.endproc

.proc XWithSpace
    ;; Expected: cam_dx stays -3
    LDA #$03
    STA TEST_EXPECTED
    STA_TWOS_COMP TEST_EXPECTED

    LDA #$03
    STA cam_dx
    STA_TWOS_COMP cam_dx
    LDA #$00
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
