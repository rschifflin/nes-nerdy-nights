;;;; GAME-SPECIFIC SUBROUTINES AND MACROS

MAX_X_SCROLL = $0200
MIN_X_SCROLL = $0000

;;;; CoordsWorld2Mem
;; 2-byte stack frame: 2 arguments, 0 locals, 0 return
;; Convert a world pixel x-coordinate to its equivalent byte in memory
;; Arg0: originLo
;; Arg1: originHi
;; PLO in baseMemLo
;; PHI in baseMemHi
;; PLO out targetLo
;; PHI out targetHi
.proc CoordsWorld2Mem
  origin  = SW_STACK-1
  ;; We convert the world coordinates of the origin x-pixel to its memory address
  ;; This means turning pixels into a byte offset from some base tile0 in memory

  ;; Each page of 960 bytes of memory spans 32 tiles on the x-axis
  ;; originHi is a scalar of 32 tiles on the x-axis
  ;; Each page of 960 bytes of memory begins with the 32 toprow tiles
  ;; originLo represents the offset in pixels to the desired toprow tile. Divide by 8 to get the offset in tiles
  ;; So the effective byte address is
  ;; Base + (960 * OriginHi) + (OriginLo >> 3)
  LDX SP
  LDA origin+1,X
  TAX
  BEQ add_origin_lo
multiply_origin_hi: ;; Mulitply originHi*960 and add to the base address
  LDA #$C0
  CLC
  ADC PLO
  STA PLO
  LDA #$03
  ADC PHI
  STA PHI
  DEX
  BNE multiply_origin_hi
add_origin_lo: ;; Add the tile bits of originLo to the address
  LDX SP
  .repeat 3
    LSR origin,X
  .endrepeat
  LDA origin,X
  CLC
  ADC PLO
  STA PLO
  BCC target_stored
  INC PHI
target_stored:
  RTS
.endproc
;;;;

.proc FillRightCamBuffer
  fetch:
    LDA cam_x
    PHA_SP
    LDA cam_x+1
    CLC
    ADC #$01 ;; The rightmost buffer origin is 256 pixels right of camera, so add 1 to the high byte
    PHA_SP
    LDA #<name_table
    STA PLO
    LDA #>name_table
    STA PHI
    ;;;;
    JSR CoordsWorld2Mem
    PLN_SP $02

    LDX #$00
  write:
    LDY #$00
  write_8:
    LDA (PLO), Y
    STA scroll_buffer_x_right, X
    INX
    CPX #$1E ;; Write 30 bytes per column
    BEQ write_done
    TYA
    CLC
    ADC #$20 ;; Next column cell is 32 bytes away
    TAY
    BNE write_8
    INC PHI
    BNE write ;; Bump offset by 256 every 8 writes
  write_done:
    RTS
.endproc

.proc FillLeftCamBuffer
    LDA cam_x
    SEC
    SBC #$08 ;; The leftmost buffer origin is 8 pixels left of camera, so sub 8
    PHA_SP
    LDA cam_x+1
    SBC #$00 ;; Applies the borrow if needed
    PHA_SP
    LDA #<name_table
    STA PLO
    LDA #>name_table
    STA PHI
    ;;;;
    JSR CoordsWorld2Mem
    PLN_SP $02

    LDX #$00
  write:
    LDY #$00
  write_8:
    LDA (PLO), Y
    STA scroll_buffer_x_left, X
    INX
    CPX #$1E ;; Write 30 bytes per column
    BEQ write_done
    TYA
    CLC
    ADC #$20 ;; Next column cell is 32 bytes away
    TAY
    BNE write_8
    INC PHI
    BNE write ;; Bump offset by 256 every 8 writes
  write_done:
    RTS
.endproc
