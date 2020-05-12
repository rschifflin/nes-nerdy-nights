;;;; GAME-SPECIFIC SUBROUTINES AND MACROS

MAX_X_SCROLL = $0300
MIN_X_SCROLL = $0000
MAX_X_SCROLL_SPEED = $07
MIN_X_SCROLL_SPEED = $01

;; Ensures cam_x + cam_dx doesnt exceed world bounds; decrease cam_dx to the limit if so.
.proc CheckBounds
    LDA cam_dx
    BEQ done
    BMI negative
  positive:
    ;; Only time we care is when cam_x+1 is 1 short of the border and cam_x is within 8
    LDA #<MAX_X_SCROLL
    SEC
    SBC cam_x
    ROL r0 ;; Preserve the carry bit

    ;; If the lo byte of max - current is > scroll_speed_max, we know its safe
    CMP #MAX_X_SCROLL_SPEED
    BPL done ;; TODO: replace with uglier BEQ continue, BCS DONE for <= logic
    TAY ;; Hold onto the lo difference

    LDA #>MAX_X_SCROLL
    ROR r0 ;; To retrieve the carry
    SBC cam_x+1

    ;; If the hi byte of max - current is > 0, we know its safe
    BNE done

    ;; Finally, take the min of the lo difference and cam_dx
    TYA
    CMP cam_dx
    BEQ done ;; If they're equal, just use cam_dx as is
    BCS done ;; If there's plenty of space, just use cam_dx as is
    STA cam_dx ;; Otherwise, set cam_dx to the difference
  negative:
    STA_TWOS_COMP cam_dx
    ;; Only time we care is when cam_x+1 is 1 short of the border and cam_x is within 8
    LDA #<MIN_X_SCROLL
    CLC
    ADC cam_x
    ROL r0 ;; Preserve the carry bit

    ;; If the lo byte of min + current is > scroll_speed_max, we know its safe
    CMP #MAX_X_SCROLL_SPEED
    BCS done_negative
    TAY ;; Hold onto the lo difference

    LDA #>MIN_X_SCROLL
    ROR r0 ;; To retrieve the carry
    ADC cam_x+1

    ;; If the hi byte of min + current is > 0, we know its safe
    BNE done_negative

    ;; Finally, take the min of the lo sum and cam_dx
    TYA
    CMP cam_dx
    BEQ done_negative ;; If they're equal, just use cam_dx as is
    BCS done_negative ;; If there's plenty of space, just use cam_dx as is
    STA cam_dx ;; Otherwise, set cam_dx to the difference
  done_negative:
    STA_TWOS_COMP cam_dx
  done:
.endproc

;;;; CoordsWorld2Mem
;; 2-byte stack frame: 2 arguments, 0 locals, 0 return
;; Convert a world pixel x-coordinate to its equivalent byte in memory
;; Arg0: originLo
;; Arg1: originHi
;; PLO in baseMemLo
;; PHI in baseMemHi
;; PLO out targetLo
;; PHI out targetHi
.proc CoordsWorld2Name
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

;;;; CoordsWorld2Attr
;; 2-byte stack frame: 2 arguments, 0 locals, 0 return
;; Convert a world pixel x-coordinate to its equivalent byte in attr-table memory
;; Arg0: originLo
;; Arg1: originHi
;; PLO in baseMemLo
;; PHI in baseMemHi
;; PLO out targetLo
;; PHI out targetHi
.proc CoordsWorld2Attr
  origin  = SW_STACK-1
  ;; Definitions: region = 32x32px screen region painted by a single attr_table byte

  ;; We convert the world coordinates of the origin x-pixel to its attribute table region address
  ;; This means turning pixels into a byte offset from some base tile0 in memory

  ;; Each page of 64 bytes of memory spans 8 regions on the x-axis
  ;; originHi is a scalar of 8 regions on the x-axis
  ;; originLo represents the offset in pixels to the desired region. Divide by 32 to get the offset in regions
  ;; So the effective byte address is
  ;; Base + (8 * OriginHi) + (OriginLo >> 5)

  LDX SP
  LDA origin+1,X
  BEQ add_origin_lo
multiply_origin_hi: ;; Mulitply originHi*8 and add to the base address
  LDY #$00
  STY r0
  CLC
  .repeat 6
    ROL A
    ROL r0
  .endrepeat
  ADC PLO
  STA PLO
  LDA r0
  ADC PHI
  STA PHI
add_origin_lo: ;; Add the region bits of originLo to the address
  .repeat 5
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


.proc FillRightNameBuffer
  fetch:
    ;; The rightmost buffer origin is 256 + 8 pixels right of camera, so add 8 to the low, 1 to the high byte
    LDA cam_x
    CLC
    ADC #$08  ;; 8 to the low
    PHA_SP
    LDA cam_x+1
    ADC #$01 ;; 1 to the high, plus carry if needed
    PHA_SP
    LDA #<name_table
    STA PLO
    LDA #>name_table
    STA PHI
    ;;;;
    JSR CoordsWorld2Name
    PLN_SP $02

    LDX #$00
  write:
    LDY #$00
  write_8:
    LDA (PLO), Y
    STA scroll_buffer_right_name, X
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

.proc FillRightAttrBuffer
  fetch:
    LDA cam_x
    CLC
    ADC #$20 ;; The rightmost buffer origin is 256 pixels + 32px right of camera, so add 1 to the high byte, 32 to the low byte
    PHA_SP
    LDA cam_x+1
    ADC #$01 ;; The rightmost buffer origin is 256 pixels + 32px right of camera, so add 1 to the high byte, 32 to the low byte
    PHA_SP
    LDA #<attribute_table
    STA PLO
    LDA #>attribute_table
    STA PHI
    ;;;;
    JSR CoordsWorld2Attr
    PLN_SP $02

    LDX #$00
    LDY #$00
  write:
    LDA (PLO), Y
    STA scroll_buffer_right_attr, X
    INX
    CPX #$08
    BEQ write_done
    TYA
    CLC
    ADC #$08 ;; Next column cell is 8 bytes away
    TAY
    JMP write
  write_done:
    RTS
.endproc

;;;; FillNameColumn
;; 8-byte stack: 8 args, 0 return
;; pageN: Page # to write from
;; offsetX: Within pageN, number of x-bytes offset from 0 to start from
;; offsetY: Within pageN, number of y-bytes offset from 0 to start from
;; srcLo: Lo byte of buffer to write from
;; srcHi: Hi byte of buffer to write from
;; targetLo: Lo byte of buffer to write to
;; targetHi: Hi byte of buffer to write to
;; targetLen: Number of buffer bytes to write
.proc FillColumnNamePage
    pageN     =     SW_STACK-7
    offsetX   =     SW_STACK-6
    offsetY   =     SW_STACK-5
    srcLo     =     SW_STACK-4
    srcHi     =     SW_STACK-3
    targetLo  =     SW_STACK-2
    targetHi  =     SW_STACK-1
    targetLen =     SW_STACK

    offsetYBottom  = SW_STACK-5 ;; Gets repurposed after offsetY is used to calculate plo/phi

    ;; If targetLen is 0, early return
    LDX SP
    LDA targetLen,X
    BNE @nonzero_len
    RTS
  @nonzero_len:
    LDA srcLo,X
    STA PLO
    LDA srcHi,X
    STA PHI

    ;; Adjusts P by pagen/offsetx/offsety
  page_row:
    LDY SP
    LDX pageN,Y ;; Assuming pages are 3x3 row major, find byte offset of topleft of page n, starting at P
  @loop:
    CPX #$03
    BCC page_col ;; < 3
    TXA
    SBC #$03 ;; the CPX above lets us know the carry is set; otherwise the BCC instruction would have branched past us
    TAX
    CLC
    LDA #<$0b40 ;; Add 960*3 to P
    ADC PLO
    STA PLO
    LDA #>$0b40
    ADC PHI
    STA PHI
    JMP @loop
  page_col:
    CPX #$00
  @loop:
    BEQ byte_row
    CLC
    LDA #<$03c0 ;; Add 960 to P
    ADC PLO
    STA PLO
    LDA #>$03c0
    ADC PHI
    STA PHI
    DEX
    JMP @loop
  byte_row:
    LDX offsetY,Y ;; Pages are 32x30 bytes, row major
  @loop:
    BEQ byte_col
    CLC
    LDA #$20 ;; Add 32 to P
    ADC PLO
    STA PLO
    LDA #$00
    ADC PHI
    STA PHI
    DEX
    JMP @loop
  byte_col:
    LDX SP
    LDA offsetX,X
    CLC
    ADC PLO
    STA PLO
    LDA #$00
    ADC PHI
    STA PHI

    LDX SP
    LDA targetLo,X
    STA r0
    LDA targetHi,X
    STA r1

    LDA #$1E ;; 30 Column bytes per page
    SEC
    SBC offsetY, X          ;; Column bytes skipped this page
    STA offsetYBottom, X ;; New value of offsetY, offset from the bottom now instead of the top

    LDX SP
    LDY #$00
  loop:
    LDA (PLO),Y
    STA (r0),Y
    INC16 r0

    ;; Add offset amount to P
    LDA PLO
    CLC
    ADC #$20 ;; 32 bytes to next column
    STA PLO
    LDA PHI ;; TODO: Is it faster to BCS and INC versus always loading and adding 0
    ADC #$00
    STA PHI

    ;; Increment target for tail call
    LDA targetLo,X
    CLC
    ADC #$01
    STA targetLo,X
    LDA targetHi,X
    ADC #$00
    STA targetHi,X

    DEC targetLen,X
    BEQ done ;; All bytes written
    DEC offsetYBottom,X
    BNE loop ;; Len is not 0 and page boundary not reached, loop

    ;; Else, we recursively call into the next vertical page
    ;; Modify PageN to be next vertical page
    LDA pageN,X
    ADC #$04 ;; 3 horizontal pages between each column
    STA pageN,X
    ;; Modify target to be next n bytes over
    ;; Notice the stack frame- pageN, targetHi, targetLo, targetLen, offsetY are all correct for the next call
    JMP FillColumnNamePage ;; Tail call: JMP (not jsr) FillColumnNamePage
  done:
    RTS
.endproc
;;;;

.proc FillLeftNameBuffer
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
    JSR CoordsWorld2Name
    PLN_SP $02

    LDX #$00
  write:
    LDY #$00
  write_8:
    LDA (PLO), Y
    STA scroll_buffer_left_name, X
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

.proc FillLeftAttrBuffer
    LDA cam_x
    SEC
    SBC #$08 ;; The leftmost buffer origin is 8 pixels left of camera, so sub 8
    PHA_SP
    LDA cam_x+1
    SBC #$00 ;; Applies the borrow if needed
    PHA_SP
    LDA #<attribute_table
    STA PLO
    LDA #>attribute_table
    STA PHI
    JSR CoordsWorld2Attr
    PLN_SP $02

    LDX #$00
    LDY #$00
  write:
    LDA (PLO), Y
    STA scroll_buffer_left_attr, X
    INX
    CPX #$08
    BEQ write_done
    TYA
    CLC
    ADC #$08 ;; Next column cell is 8 bytes away
    TAY
    JMP write
  write_done:
    RTS
.endproc
