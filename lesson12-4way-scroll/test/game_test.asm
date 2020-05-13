.include "../defs/game.asm"

.include "harness.asm"
.include "../lib/game.asm"

lattice:
  .repeat 9
    .include "../data/lattice_nametable.asm"
  .endrepeat

integer_nametable:
  .repeat 960
    .byte $01
  .endrepeat
  .repeat 960
    .byte $02
  .endrepeat

lattice_header:
  .byte 3 ;; 3 pages wide
  .byte 3 ;; 3 pages high
  .byte 32 ;; 32 bytes wide per page
  .byte 30 ;; 30 bytes high per page
  .word 960 ;; 960 bytes total per page
  .word 2880 ;; 2880 bytes total per row
  .addr lattice

integer_nametable_header:
  .byte 2 ;; 6 pages wide
  .byte 1 ;; 1 page high
  .byte 32 ;; 32 bytes wide per page
  .byte 30 ;; 30 bytes high per page
  .word 960 ;; 960 bytes total per page
  .word 1920 ;; 1920 bytes total per row
  .addr integer_nametable ;; No actual bytes

empty_nametable_header:
  .byte 6 ;; 6 pages wide
  .byte 5 ;; 5 pages high
  .byte 32 ;; 32 bytes wide per page
  .byte 30 ;; 30 bytes high per page
  .word 960 ;; 960 bytes total per page
  .word 5760 ;; 2880 bytes total per row
  .addr $FFFF ;; No actual bytes

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

.proc CheckWorldCoordinatesToName
    ;; set up page table: 6x5 nametables
    LDA #<empty_nametable_header
    STA PLO
    LDA #>empty_nametable_header
    STA PHI
    JSR LoadPageTable

    LDA #$1d ;; End up on page 29
    STA TEST_EXPECTED
    LDA #$02 ;; x-offset = 2
    STA TEST_EXPECTED+1
    LDA #$04 ;; y-offset = 4
    STA TEST_EXPECTED+2

    LDA #<$0515
    PHA_SP ;; X-coord 1301
    LDA #>$0515
    PHA_SP
    LDA #<$03e0
    PHA_SP ;; Y-coord 992
    LDA #>$03e0
    PHA_SP
    LDA #$08
    PHA_SP ;; name table byte is 8 pixels wide
    PHA_SP ;; name table byte is 8 pixels tall
    PHN_SP 3 ;; Add space for ret vals
    JSR CoordsWorld2Page

    PLA_SP
    STA TEST_ACTUAL+2
    PLA_SP
    STA TEST_ACTUAL+1
    PLA_SP
    STA TEST_ACTUAL
    PLN_SP 6 ;; Pop rest of sw stack

    SHOW
    RTS
.endproc

;; FillColumnFromPage tests start here
.proc FillColumnFromLattice
  ;; Expected: buffer is filled with a 30 value column from the topleft of the lattice
    LDX #$00
    .repeat 30, N
      LDA lattice+(N*32)
      STA TEST_EXPECTED,X
      INX
    .endrepeat

    ;; set up page table
    LDA #<lattice_header
    STA PLO
    LDA #>lattice_header
    STA PHI
    JSR LoadPageTable

    LDA #$00
    PHA_SP ;; pageN
    PHA_SP ;; offsetX
    PHA_SP ;; offsetY
    PHN_SP 2 ;; Add space for retvals
    JSR GetBytePtrFromPage
    LDA #<TEST_ACTUAL
    PHA_SP ;; targetLo
    LDA #>TEST_ACTUAL
    PHA_SP ;; targetHi
    LDA #$1E ;; 30 bytes
    PHA_SP ;; targetLen

    JSR FillColumnFromPage
    PLN_SP 8

    SHOW
    RTS
.endproc

.proc FillColumnFromPageFromXYOffset
  ;; Expected: buffer is filled with a 30 value column from the topleft of the lattice
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

    ;; set up page table
    LDA #<lattice_header
    STA PLO
    LDA #>lattice_header
    STA PHI
    JSR LoadPageTable

    LDA #$00
    PHA_SP ;; pageN
    LDA #$07
    PHA_SP ;; offsetX
    LDA #$04
    PHA_SP ;; offsetY
    PHN_SP 2 ;; Add space for retvals
    JSR GetBytePtrFromPage
    LDA #<TEST_ACTUAL
    PHA_SP ;; targetLo
    LDA #>TEST_ACTUAL
    PHA_SP ;; targetHi
    LDA #$1E ;; 30 bytes
    PHA_SP ;; targetLen

    JSR FillColumnFromPage
    PLN_SP 8

    SHOW
    RTS
.endproc

.proc FillColumnFromPageFromCorner
  ;; Expected: buffer is filled with a 30 value column from the bottom-right of the lattice
    JMP after_data
    expected_data:
      .byte $DF, $0F, $1F, $2F, $3F, $4F, $5F, $6F
      .byte $7F, $8F, $9F, $AF, $BF, $CF, $DF, $EF
      .byte $FF, $0F, $1F, $2F, $3F, $4F, $5F, $6F
      .byte $7F, $8F, $9F, $AF, $BF, $CF
    after_data:
    LDX #$00
    loop:
      LDA expected_data,X
      STA TEST_EXPECTED,X
      INX
      CPX #$1E
      BNE loop

    ;; set up page table
    LDA #<lattice_header
    STA PLO
    LDA #>lattice_header
    STA PHI
    JSR LoadPageTable

    LDA #$03
    PHA_SP ;; pageN
    LDA #$1F
    PHA_SP ;; offsetX - 31
    LDA #$1D
    PHA_SP ;; offsetY - 29
    PHN_SP 2 ;; Add space for retvals
    JSR GetBytePtrFromPage
    LDA #<TEST_ACTUAL
    PHA_SP ;; targetLo
    LDA #>TEST_ACTUAL
    PHA_SP ;; targetHi
    LDA #$1E ;; 30 bytes
    PHA_SP ;; targetLen

    JSR FillColumnFromPage
    PLN_SP 8

    SHOW
    RTS
.endproc

.proc FillColumnFromPage2
  ;; Expected: buffer is filled with a 30 value column of all 2s
    JMP after_data
    expected_data:
      .repeat 30
        .byte $02
      .endrepeat
    after_data:

    LDX #$00
    loop:
      LDA expected_data,X
      STA TEST_EXPECTED,X
      INX
      CPX #$1E
      BNE loop

    ;; set up page table
    LDA #<integer_nametable_header
    STA PLO
    LDA #>integer_nametable_header
    STA PHI
    JSR LoadPageTable

    LDA #$01
    PHA_SP ;; pageN
    LDA #$00
    PHA_SP ;; offsetX 0
    PHA_SP ;; offsetY 0
    PHN_SP 2 ;; Add space for retvals
    JSR GetBytePtrFromPage
    LDA #<TEST_ACTUAL
    PHA_SP ;; targetLo
    LDA #>TEST_ACTUAL
    PHA_SP ;; targetHi
    LDA #$1E ;; 30 bytes
    PHA_SP ;; targetLen

    JSR FillColumnFromPage
    PLN_SP 8

    SHOW
    RTS
.endproc

.proc FillColumnFromPage2WithWorldXY
  ;; Expected: buffer is filled with a 30 value column of all 2s
    JMP after_data
    expected_data:
      .repeat 30
        .byte $02
      .endrepeat
    after_data:

    LDX #$00
    loop:
      LDA expected_data,X
      STA TEST_EXPECTED,X
      INX
      CPX #$1E
      BNE loop

    ;; set up page table
    LDA #<integer_nametable_header
    STA PLO
    LDA #>integer_nametable_header
    STA PHI
    JSR LoadPageTable

    LDA #$08
    PHA_SP
    LDA #$01
    PHA_SP ;; X = 256 + 8
    LDA #$00
    PHA_SP
    PHA_SP ;; Y = 0
    LDA #$08
    PHA_SP ;; name table byte is 8 pixels wide
    PHA_SP ;; name table byte is 8 pixels tall
    PHN_SP 3 ;; Add space for ret vals
    JSR CoordsWorld2Page
    PHN_SP 2 ;; Add space for retvals
    JSR GetBytePtrFromPage
    LDA #<TEST_ACTUAL
    PHA_SP
    LDA #>TEST_ACTUAL
    PHA_SP
    LDA #$1E ;; scroll buffer len is 30 bytes
    PHA_SP
    JSR FillColumnFromPage
    PLN_SP 14 ;; Pop all

    SHOW
    RTS
.endproc

;; FillRowFromPage tests start here
.proc FillRowFromLattice
  ;; Expected: buffer is filled with a 32 value row from the topleft of the lattice
    LDX #$00
    .repeat 32
      LDA lattice,X
      STA TEST_EXPECTED,X
      INX
    .endrepeat

    ;; set up page table
    LDA #<lattice_header
    STA PLO
    LDA #>lattice_header
    STA PHI
    JSR LoadPageTable

    LDA #$00
    PHA_SP ;; pageN
    PHA_SP ;; offsetX
    PHA_SP ;; offsetY
    PHN_SP 2 ;; Add space for retvals
    JSR GetBytePtrFromPage
    LDA #<TEST_ACTUAL
    PHA_SP ;; targetLo
    LDA #>TEST_ACTUAL
    PHA_SP ;; targetHi
    LDA #$20 ;; 32 bytes
    PHA_SP ;; targetLen

    JSR FillRowFromPage
    PLN_SP 8

    SHOW
    RTS
.endproc

.proc FillRowFromPageFromXYOffset
  ;; Expected: buffer is filled with a 32 value row from the topleft of the lattice
    JMP after_data
    expected_data:
      .byte $47, $48, $49, $4A, $4B, $4C, $4D, $4E
      .byte $4F, $40, $41, $42, $43, $44, $45, $46
      .byte $47, $48, $49, $4A, $4B, $4C, $4D, $4E
      .byte $4F, $40, $41, $42, $43, $44, $45, $46
    after_data:
    LDX #$00
    loop:
      LDA expected_data,X
      STA TEST_EXPECTED,X
      INX
      CPX #$20
      BNE loop

    ;; set up page table
    LDA #<lattice_header
    STA PLO
    LDA #>lattice_header
    STA PHI
    JSR LoadPageTable

    LDA #$00
    PHA_SP ;; pageN
    LDA #$07
    PHA_SP ;; offsetX
    LDA #$04
    PHA_SP ;; offsetY
    PHN_SP 2 ;; Add space for retvals
    JSR GetBytePtrFromPage
    LDA #<TEST_ACTUAL
    PHA_SP ;; targetLo
    LDA #>TEST_ACTUAL
    PHA_SP ;; targetHi
    LDA #$20 ;; 32 bytes
    PHA_SP ;; targetLen

    JSR FillRowFromPage
    PLN_SP 8

    SHOW
    RTS
.endproc

.proc FillRowFromPageFromCorner
  ;; Expected: buffer is filled with a 32 value row from the bottom-right of the lattice
    JMP after_data
    expected_data:
      .byte $DF, $D0, $D1, $D2, $D3, $D4, $D5, $D6
      .byte $D7, $D8, $D9, $DA, $DB, $DC, $DD, $DE
      .byte $DF, $D0, $D1, $D2, $D3, $D4, $D5, $D6
      .byte $D7, $D8, $D9, $DA, $DB, $DC, $DD, $DE
    after_data:
    LDX #$00
    loop:
      LDA expected_data,X
      STA TEST_EXPECTED,X
      INX
      CPX #$20
      BNE loop

    ;; set up page table
    LDA #<lattice_header
    STA PLO
    LDA #>lattice_header
    STA PHI
    JSR LoadPageTable

    LDA #$03
    PHA_SP ;; pageN
    LDA #$1F
    PHA_SP ;; offsetX - 31
    LDA #$1D
    PHA_SP ;; offsetY - 29
    PHN_SP 2 ;; Add space for retvals
    JSR GetBytePtrFromPage
    LDA #<TEST_ACTUAL
    PHA_SP ;; targetLo
    LDA #>TEST_ACTUAL
    PHA_SP ;; targetHi
    LDA #$20 ;; 32 bytes
    PHA_SP ;; targetLen

    JSR FillRowFromPage
    PLN_SP 8

    SHOW
    RTS
.endproc

.proc FillRowFromPage2
  ;; Expected: buffer is filled with a 32 value row of all 2s
    JMP after_data
    expected_data:
      .repeat 32
        .byte $02
      .endrepeat
    after_data:

    LDX #$00
    loop:
      LDA expected_data,X
      STA TEST_EXPECTED,X
      INX
      CPX #$20
      BNE loop

    ;; set up page table
    LDA #<integer_nametable_header
    STA PLO
    LDA #>integer_nametable_header
    STA PHI
    JSR LoadPageTable

    LDA #$01
    PHA_SP ;; pageN
    LDA #$00
    PHA_SP ;; offsetX 0
    PHA_SP ;; offsetY 0
    PHN_SP 2 ;; Add space for retvals
    JSR GetBytePtrFromPage
    LDA #<TEST_ACTUAL
    PHA_SP ;; targetLo
    LDA #>TEST_ACTUAL
    PHA_SP ;; targetHi
    LDA #$20 ;; 32 bytes
    PHA_SP ;; targetLen

    JSR FillRowFromPage
    PLN_SP 8

    SHOW
    RTS
.endproc

.proc FillRowFromPage2WithWorldXY
  ;; Expected: buffer is filled with a 32 value row of all 2s
    JMP after_data
    expected_data:
      .repeat 32
        .byte $02
      .endrepeat
    after_data:

    LDX #$00
    loop:
      LDA expected_data,X
      STA TEST_EXPECTED,X
      INX
      CPX #$20
      BNE loop

    ;; set up page table
    LDA #<integer_nametable_header
    STA PLO
    LDA #>integer_nametable_header
    STA PHI
    JSR LoadPageTable

    LDA #$00
    PHA_SP
    LDA #$01
    PHA_SP ;; X = 256
    LDA #$00
    PHA_SP
    PHA_SP ;; Y = 0
    LDA #$08
    PHA_SP ;; name table byte is 8 pixels wide
    PHA_SP ;; name table byte is 8 pixels tall
    PHN_SP 3 ;; Add space for ret vals
    JSR CoordsWorld2Page
    PHN_SP 2 ;; Add space for retvals
    JSR GetBytePtrFromPage
    LDA #<TEST_ACTUAL
    PHA_SP
    LDA #>TEST_ACTUAL
    PHA_SP
    LDA #$20 ;; scroll buffer len is 32 bytes
    PHA_SP
    JSR FillRowFromPage
    PLN_SP 14 ;; Pop all

    SHOW
    RTS
.endproc

.proc RunTests
  TEST BoundsCheckDeltaUnderflow    ;; Test 0
  TEST BoundsCheckDeltaOverflow     ;; Test 1
  TEST BoundsCheckDeltaSafeNegative ;; Test 2
  TEST BoundsCheckDeltaSafePositive ;; Test 3
  TEST CheckWorldCoordinatesToName ;; Test 4

  TEST FillColumnFromLattice      ;; Test 5
  TEST FillColumnFromPageFromXYOffset ;; Test 6
  TEST FillColumnFromPageFromCorner ;; Test 7
  TEST FillColumnFromPage2 ;; Test 8
  TEST FillColumnFromPage2WithWorldXY ;; Test 9

;;  TEST FillRowFromLattice      ;; Test 10
  TEST FillRowFromPageFromXYOffset ;; Test 11
  TEST FillRowFromPageFromCorner ;; Test 12
  TEST FillRowFromPage2 ;; Test 13
  TEST FillRowFromPage2WithWorldXY ;; Test 14
  RTS
.endproc
