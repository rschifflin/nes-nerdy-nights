.include "harness.asm"
.include "../lib/game.asm"

lattice:
  .repeat 8
    .include "../data/lattice_nametable.asm"
  .endrepeat

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

.proc FillColumnNamePageFrom0
  ;; Expected: buffer is filled with a 30 value column from the topleft of the integer page
    LDX #$00
    .repeat 30, N
      LDA lattice+(N*32)
      STA TEST_EXPECTED,X
      INX
    .endrepeat

    LDA #$00
    STA cam_x
    LDA #$01
    STA cam_x+1

    LDA #$00
    PHA_SP ;; pageN
    PHA_SP ;; offsetX
    PHA_SP ;; offsetY
    LDA #<lattice
    PHA_SP ;; srcLo
    LDA #>lattice
    PHA_SP ;; srcHi
    LDA #<TEST_ACTUAL
    PHA_SP ;; targetLo
    LDA #>TEST_ACTUAL
    PHA_SP ;; targetHi
    LDA #$1E ;; 30 bytes
    PHA_SP ;; targetLen

    JSR FillColumnNamePage
    PLN_SP 8

    SHOW
    RTS
.endproc

.proc FillColumnNamePageFromXYOffset
  ;; Expected: buffer is filled with a 30 value column from the topleft of the integer page
    JMP after_data
    expected_data:
      .byte $47, $57, $67, $77, $87, $97, $A7, $B7
      .byte $C7, $D7, $E7, $F7, $07, $17, $27, $37
      .byte $47, $57, $67, $77, $87, $97, $A7, $B7
      .byte $C7, $D7, $07, $17, $27, $37
    after_data:
    LDX #$00
    loop:
      LDA expected_data,X
      STA TEST_EXPECTED,X
      INX
      CPX #$1E
      BNE loop

    LDA #$00
    STA cam_x
    LDA #$01
    STA cam_x+1

    LDA #$00
    PHA_SP ;; pageN
    LDA #$07
    PHA_SP ;; offsetX
    LDA #$04
    PHA_SP ;; offsetY
    LDA #<lattice
    PHA_SP ;; srcLo
    LDA #>lattice
    PHA_SP ;; srcHi
    LDA #<TEST_ACTUAL
    PHA_SP ;; targetLo
    LDA #>TEST_ACTUAL
    PHA_SP ;; targetHi
    LDA #$1E ;; 30 bytes
    PHA_SP ;; targetLen

    JSR FillColumnNamePage
    PLN_SP 8

    SHOW
    RTS
.endproc

.proc RunTests
  TEST BoundsCheckDeltaUnderflow    ;; Test 0
  TEST BoundsCheckDeltaOverflow     ;; Test 1
  TEST BoundsCheckDeltaSafeNegative ;; Test 2
  TEST BoundsCheckDeltaSafePositive ;; Test 3
  TEST FillColumnNamePageFrom0      ;; Test 4
  TEST FillColumnNamePageFromXYOffset ;; Test 5
  RTS
.endproc
