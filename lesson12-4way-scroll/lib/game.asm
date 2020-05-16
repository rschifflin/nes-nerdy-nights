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

;; LoadPageTable
;; Expects P to hold pointer to a PageTable struct
;; Copies struct into the PageTable area of zeropage
.proc LoadPageTable
    LDY #$00
  loop:
    LDA (PLO),Y
    STA page_table,Y
    INY
    CPY #.sizeof(PageTable)
    BNE loop

    RTS
.endproc

;;;; CoordsWorld2Page
;; 9-byte stack frame: 6 arguments, 3 returns
;; Looks up a world pixel xy-coordinate and returns its page reference
.proc CoordsWorld2Page
    ;; Stack frame:
    xLo  = SW_STACK-8
    xHi  = SW_STACK-7
    yLo  = SW_STACK-6
    yHi  = SW_STACK-5
    xPerPageByte = SW_STACK-4
    yPerPageByte = SW_STACK-3
    pageN = SW_STACK-2
    offsetX = SW_STACK-1
    offsetY = SW_STACK

    ;; page variables from mem
    spanWidth            = PageTable::span_width + page_table
    spanHeight           = PageTable::span_height + page_table
    widthBytes           = PageTable::width_bytes + page_table
    heightBytes          = PageTable::height_bytes + page_table

    ;; Initial return values are all 0
    LDX SP
    LDA #$00
    STA pageN,X
    STA offsetX,X
    STA offsetY,X

    .scope handle_x
      ;; For sanity, assume x/yPerPageByte is a multiple of 2
      ;; Convert x from pixels to bytes
      loop_convert:
        LSR xHi,X
        ROR xLo,X
        LSR xPerPageByte,X
        LDA #$01
        CMP xPerPageByte,X
        BNE loop_convert

        LDY #$00 ;; represents PageN
        LDA xHi,X
        BEQ offset_lo
        LDA xLo,X
        SEC
      loop_offset_hi:
        SBC widthBytes
        INY
        BCS loop_offset_hi
        DEC xHi,X
        SEC
        BNE loop_offset_hi
      offset_lo:
        LDA xLo,X
        SEC
      loop_offset_lo:
        CMP widthBytes
        BCC done
        SBC widthBytes
        INY
        JMP loop_offset_lo
      done:
        STA offsetX,X
        TYA
        STA pageN,X
    .endscope

    .scope handle_y
      ;; For sanity, assume x/yPerPageByte is a multiple of 2
      ;; Convert y from pixels to bytes
      loop_convert:
        LSR yHi,X
        ROR yLo,X
        LSR yPerPageByte,X
        LDA #$01
        CMP yPerPageByte,X
        BNE loop_convert

        LDY #$00 ;; represents PageN
        LDA yHi,X
        BEQ offset_lo
        LDA yLo,X
        SEC
      loop_offset_hi:
        SBC heightBytes
        INY
        BCS loop_offset_hi
        DEC yHi,X
        SEC
        BNE loop_offset_hi
      offset_lo:
        LDA yLo,X
        SEC
      loop_offset_lo:
        CMP heightBytes
        BCC done_offset
        SBC heightBytes
        INY
        JMP loop_offset_lo
      done_offset:
        STA offsetY,X

        CPY #$00
        BEQ done
        LDA pageN,X
      loop_pagen:
        CLC
        ADC spanWidth
        DEY
        BNE loop_pagen
        STA pageN,X
      done:
    .endscope
    RTS
.endproc

.proc FillRightNameBufferFromPage
    LDA cam_x
    CLC
    ADC #$08
    PHA_SP ;; Right name buffer starts 256 + 8 pixels right of camera
    LDA cam_x+1
    ADC #$01
    PHA_SP ;; Right name buffer starts 256 + 8 pixels right of camera
    LDA cam_y
    PHA_SP
    LDA cam_y+1
    PHA_SP
    LDA #$08
    PHA_SP ;; name table byte is 8 pixels wide
    PHA_SP ;; name table byte is 8 pixels tall
    PHN_SP 3 ;; Add space for ret vals
    JSR CoordsWorld2Page
    PHN_SP 2 ;; Add space for ret vals
    JSR GetBytePtrFromPage
    LDA #<scroll_buffer_right_name
    PHA_SP
    LDA #>scroll_buffer_right_name
    PHA_SP
    LDA #$1E ;; scroll buffer len is 30 bytes
    PHA_SP
    JSR FillColumnFromPage
    PLN_SP 14 ;; Pop all

    ;; Now rotate the buffer based on scroll-y
    LDA #<scroll_buffer_right_name
    STA PLO ; Src buffer lo
    LDA #>scroll_buffer_right_name
    STA PHI ;; Src buffer hi
    LDA #$1E
    STA r0 ;; Len is 30
    LDA ppu_scroll_y
    .repeat 3
      LSR A
    .endrepeat
    STA r1 ;; Shift by scroll_y tiles
    JSR RotateBufferRight

    RTS
.endproc

.proc FillRightAttrBufferFromPage
    LDA cam_x
    CLC
    ADC #$08
    PHA_SP ;; Right attr buffer starts 256 + 8 pixels right of camera
    LDA cam_x+1
    ADC #$01
    PHA_SP ;; Right attr buffer starts 256 + 8 pixels right of camera
    LDA cam_y
    PHA_SP
    LDA cam_y+1
    PHA_SP
    LDA #$20
    PHA_SP ;; attr table byte is 32 pixels wide
    PHA_SP ;; attr table byte is 32 pixels tall
    PHN_SP 3 ;; Add space for ret vals
    JSR CoordsWorld2Page
    PHN_SP 2 ;; Add space for ret vals
    JSR GetBytePtrFromPage
    LDA #<scroll_buffer_right_attr
    PHA_SP
    LDA #>scroll_buffer_right_attr
    PHA_SP
    LDA #$08 ;; scroll buffer len is 8 bytes
    PHA_SP
    JSR FillColumnFromPage
    PLN_SP 14 ;; Pop all

    ;; Now rotate the buffer based on scroll-y
    LDA #<scroll_buffer_right_attr
    STA PLO ; Src buffer lo
    LDA #>scroll_buffer_right_attr
    STA PHI ;; Src buffer hi
    LDA #$08
    STA r0 ;; Len is 8
    LDA ppu_scroll_y
    .repeat 5
      LSR A
    .endrepeat
    STA r1 ;; Shift by scroll_y regions
    JSR RotateBufferRight

    RTS
.endproc

.proc FillLeftNameBufferFromPage
    LDA cam_x
    SEC
    SBC #$08
    PHA_SP ;; Left buffer starts 8 pixels left of camera
    LDA cam_x+1
    SBC #$00
    PHA_SP ;; Left buffer starts 8 pixels left of camera
    LDA cam_y
    PHA_SP
    LDA cam_y+1
    PHA_SP
    LDA #$08
    PHA_SP ;; name table byte is 8 pixels wide
    PHA_SP ;; name table byte is 8 pixels tall
    PHN_SP 3 ;; Add space for ret vals
    JSR CoordsWorld2Page
    PHN_SP 2 ;; Add space for ret vals
    JSR GetBytePtrFromPage
    LDA #<scroll_buffer_left_name
    PHA_SP
    LDA #>scroll_buffer_left_name
    PHA_SP
    LDA #$1E ;; scroll buffer len is 30 bytes
    PHA_SP
    JSR FillColumnFromPage
    PLN_SP 14 ;; Pop all

    ;; Now rotate the buffer based on scroll-y
    LDA #<scroll_buffer_left_name
    STA PLO ; Src buffer lo
    LDA #>scroll_buffer_left_name
    STA PHI ;; Src buffer hi
    LDA #$1E
    STA r0 ;; Len is 30
    LDA ppu_scroll_y
    .repeat 3
      LSR A
    .endrepeat
    STA r1 ;; Shift by scroll_y tiles
    JSR RotateBufferRight

    RTS
.endproc

.proc FillTopNameBufferFromPage
    LDA cam_x
    PHA_SP
    LDA cam_x+1
    PHA_SP

    LDA cam_y
    SEC
    SBC #$08
    PHA_SP ;; Top buffer starts 8 pixels top of camera
    LDA cam_y+1
    SBC #$00
    PHA_SP

    LDA #$08
    PHA_SP ;; name table byte is 8 pixels wide
    PHA_SP ;; name table byte is 8 pixels tall
    PHN_SP 3 ;; Add space for ret vals
    JSR CoordsWorld2Page
    PHN_SP 2 ;; Add space for ret vals
    JSR GetBytePtrFromPage
    LDA #<scroll_buffer_top_name
    PHA_SP
    LDA #>scroll_buffer_top_name
    PHA_SP
    LDA #$21 ;; scroll buffer len is 33 bytes
    PHA_SP
    JSR FillRowFromPage
    PLN_SP 14 ;; Pop all

    ;; Now rotate the buffer based on scroll-x
    LDA #<scroll_buffer_top_name
    STA PLO ; Src buffer lo
    LDA #>scroll_buffer_top_name
    STA PHI ;; Src buffer hi
    LDA #$21
    STA r0 ;; Len is 33
    LDA cam_x
    .repeat 3
      LSR A
    .endrepeat
    STA r1 ;; Shift by scroll_x tiles
    JSR RotateBufferRight
    RTS
.endproc

.proc FillBottomNameBufferFromPage
    LDA cam_x
    PHA_SP
    LDA cam_x+1
    PHA_SP

    LDA cam_y
    CLC
    ADC #$08
    PHA_SP ;; Top buffer starts 8 pixels past bottom of camera
    LDA cam_y+1
    ADC #$01
    PHA_SP

    LDA #$08
    PHA_SP ;; name table byte is 8 pixels wide
    PHA_SP ;; name table byte is 8 pixels tall
    PHN_SP 3 ;; Add space for ret vals
    JSR CoordsWorld2Page
    PHN_SP 2 ;; Add space for ret vals
    JSR GetBytePtrFromPage
    LDA #<scroll_buffer_bottom_name
    PHA_SP
    LDA #>scroll_buffer_bottom_name
    PHA_SP
    LDA #$21 ;; scroll buffer len is 33 bytes
    PHA_SP
    JSR FillRowFromPage
    PLN_SP 14 ;; Pop all

    ;; Now rotate the buffer based on scroll-x
    LDA #<scroll_buffer_bottom_name
    STA PLO ; Src buffer lo
    LDA #>scroll_buffer_bottom_name
    STA PHI ;; Src buffer hi
    LDA #$21
    STA r0 ;; Len is 33
    LDA cam_x
    .repeat 3
      LSR A
    .endrepeat
    STA r1 ;; Shift by scroll_x tiles
    JSR RotateBufferRight
    RTS
.endproc

.proc FillLeftAttrBufferFromPage
    LDA cam_x
    SEC
    SBC #$08
    PHA_SP ;; Left buffer starts 8 pixels left of camera
    LDA cam_x+1
    SBC #$00
    PHA_SP ;; Left buffer starts 8 pixels left of camera
    LDA cam_y
    PHA_SP
    LDA cam_y+1
    PHA_SP
    LDA #$20
    PHA_SP ;; attr table byte is 32 pixels wide
    PHA_SP ;; attr table byte is 32 pixels tall
    PHN_SP 3 ;; Add space for ret vals
    JSR CoordsWorld2Page
    PHN_SP 2 ;; Add space for ret vals
    JSR GetBytePtrFromPage
    LDA #<scroll_buffer_left_attr
    PHA_SP
    LDA #>scroll_buffer_left_attr
    PHA_SP
    LDA #$08 ;; scroll buffer len is 8 bytes
    PHA_SP
    JSR FillColumnFromPage
    PLN_SP 14 ;; Pop all

    ;; Now rotate the buffer based on scroll-y
    LDA #<scroll_buffer_left_attr
    STA PLO ; Src buffer lo
    LDA #>scroll_buffer_left_attr
    STA PHI ;; Src buffer hi
    LDA #$08
    STA r0 ;; Len is 8
    LDA ppu_scroll_y
    .repeat 5
      LSR A
    .endrepeat
    STA r1 ;; Shift by scroll_y regions
    JSR RotateBufferRight

    RTS
.endproc

;;;; GetBytePtrFromPage
;; 5-byte stack: 3 args, 2 return
.proc GetBytePtrFromPage
  ;; Stack frame
    pageN     =     SW_STACK-4
    offsetX   =     SW_STACK-3
    offsetY   =     SW_STACK-2
    targetLo  =     SW_STACK-1
    targetHi  =     SW_STACK

  ;; Variables from mem
    spanWidth           = PageTable::span_width + page_table
    widthBytes          = PageTable::width_bytes + page_table
    pageBytesLo         = PageTable::page_bytes + page_table
    pageBytesHi         = PageTable::page_bytes+1 + page_table
    spanWidthBytesLo    = PageTable::span_width_bytes + page_table
    spanWidthBytesHi    = PageTable::span_width_bytes+1 + page_table
    srcLo               = PageTable::start_byte + page_table
    srcHi               = PageTable::start_byte+1 + page_table

    LDA srcLo
    STA PLO
    LDA srcHi
    STA PHI

    ;; Adjusts P by pagen/offsetx/offsety
  page_row:
    LDY SP
    LDX pageN,Y
  @loop:
    CPX spanWidth
    BCC page_col ;; In the correct page row already
    TXA
    SBC spanWidth ;; the CPX above lets us know the carry is set; otherwise the BCC instruction would have branched past us
    TAX
    CLC
    LDA spanWidthBytesLo ;; Increase byte offset to next row
    ADC PLO
    STA PLO
    LDA spanWidthBytesHi
    ADC PHI
    STA PHI
    JMP @loop
  page_col:
    CPX #$00
  @loop:
    BEQ byte_row
    CLC
    LDA pageBytesLo ;; Increase byte offset by one page
    ADC PLO
    STA PLO
    LDA pageBytesHi
    ADC PHI
    STA PHI
    DEX
    JMP @loop
  byte_row:
    LDX offsetY,Y ;; Pages are row major
  @loop:
    BEQ byte_col ;; Branch when we're on the correct byte row
    CLC
    LDA widthBytes ;; Increase byte offset to next byte row
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
    LDA PLO
    STA targetLo,X
    LDA PHI
    STA targetHi,X
    RTS
.endproc

;;;; FillColumnFromPage
;; 8-byte stack: 8 args, 0 return
;; pageN: Current page holding the byte to start from
;; offsetX: Within current page, number of x-bytes offset from 0 to start from
;; offsetY: Within current page, number of y-bytes offset from 0 to start from
;; srcLo: Lo byte of buffer to write from
;; srcHi: Hi byte of buffer to write from
;; targetLo: Lo byte of buffer to write to
;; targetHi: Hi byte of buffer to write to
;; targetLen: Number of buffer bytes to write
.proc FillColumnFromPage
  ;; Variables from stack
    pageN     =     SW_STACK-7
    offsetX   =     SW_STACK-6
    offsetY   =     SW_STACK-5
    srcLo     =     SW_STACK-4
    srcHi     =     SW_STACK-3
    targetLo  =     SW_STACK-2
    targetHi  =     SW_STACK-1
    targetLen =     SW_STACK

  ;; Variables from mem
    spanWidth           = PageTable::span_width + page_table
    widthBytes          = PageTable::width_bytes + page_table
    heightBytes         = PageTable::height_bytes + page_table
    spanWidthBytesLo    = PageTable::span_width_bytes + page_table
    spanWidthBytesHi    = PageTable::span_width_bytes+1 + page_table

    offsetYBottom       = offsetY ;; Gets repurposed after offsetY is used to calculate plo/phi

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

    LDX SP
    LDA targetLo,X
    STA r0
    LDA targetHi,X
    STA r1

    LDA heightBytes
    SEC
    SBC offsetY, X       ;; Column bytes skipped this page
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
    ADC widthBytes
    STA PLO
    LDA PHI ;; TODO: Is it faster to BCS and INC versus always loading and adding 0
    ADC #$00
    STA PHI

    ;; Increment target for tail call
    INC16_X targetLo

    DEC targetLen,X
    BEQ done ;; All bytes written
    DEC offsetYBottom,X
    BNE loop ;; Len is not 0 and page boundary not reached, loop

    ;; Else, we recursively call into the next vertical page
    LDA pageN,X
    ADC spanWidth
    STA pageN,X

    ;; Protect targetLen, targetHi, targetLo
    PLA_SP
    PHA
    PLA_SP
    PHA
    PLA_SP
    PHA
    ;; Stack frame is perfect to calculate next srclo/srcHi
    JSR GetBytePtrFromPage
    ;; Restore targetLen, targetHi, targetLo
    PLA
    PHA_SP
    PLA
    PHA_SP
    PLA
    PHA_SP

    ;; Notice the stack frame- pageN, offsetY, srcLo, srcHi, targetLo, targetHi, targetLen are all correct for the next call
    JMP FillColumnFromPage ;; Tail call: JMP (not jsr) FillColumnFromPage
  done:
    RTS
.endproc
;;;;

;;;; FillRowFromPage
;; 7-byte stack: 7 args, 0 return
;; pageN: Current page holding the byte to start from
;; offsetX: Within pageN, number of x-bytes offset from 0 to start from
;; offsetY: Within pageN, number of y-bytes offset from 0 to start from
;; srcLo: Lo byte of buffer to write from
;; srcHi: Hi byte of buffer to write from
;; targetLo: Lo byte of buffer to write to
;; targetHi: Hi byte of buffer to write to
;; targetLen: Number of buffer bytes to write
.proc FillRowFromPage
  ;; Variables from stack
    pageN     =     SW_STACK-7
    offsetX   =     SW_STACK-6
    offsetY   =     SW_STACK-5
    srcLo     =     SW_STACK-4
    srcHi     =     SW_STACK-3
    targetLo  =     SW_STACK-2
    targetHi  =     SW_STACK-1
    targetLen =     SW_STACK

  ;; Variables from mem
    spanWidth           = PageTable::span_width + page_table
    widthBytes          = PageTable::width_bytes + page_table
    heightBytes         = PageTable::height_bytes + page_table
    pageBytesLo         = PageTable::page_bytes + page_table
    pageBytesHi         = PageTable::page_bytes+1 + page_table

    offsetXRight        = offsetX ;; Gets repurposed after offsetX is used to calculate plo/phi

    ;; If targetLen is 0, early return
    LDX SP
    LDA targetLen,X
    BNE @nonzero_len
    RTS
  @nonzero_len:
    LDX SP
    LDA targetLo,X
    STA r0
    LDA targetHi,X
    STA r1

    LDA widthBytes
    SEC
    SBC offsetX, X      ;; Row bytes skipped this page
    STA offsetXRight, X ;; New value of offsetX, offset from the right now instead of the left

    LDX SP
    LDY #$00
  loop:
    LDA (PLO),Y
    STA (r0),Y
    INC16 r0
    INC16 PLO
    INC16_X targetLo

    DEC targetLen,X
    BEQ done ;; All bytes written
    DEC offsetXRight,X
    BNE loop ;; Len is not 0 and page boundary not reached, loop

    ;; Else, we recursively call into the next horizontal page
    INC pageN,X

    ;; Protect targetLen, targetHi, targetLo
    PLA_SP
    PHA
    PLA_SP
    PHA
    PLA_SP
    PHA
    ;; Stack frame is perfect to calculate next srclo/srcHi
    JSR GetBytePtrFromPage
    ;; Restore targetLen, targetHi, targetLo
    PLA
    PHA_SP
    PLA
    PHA_SP
    PLA
    PHA_SP

    ;; Notice the stack frame- pageN, offsetX, srcLo, srcHi, targetLo, targetHi, targetLen are all correct for the next call
    JMP FillRowFromPage ;; Tail call: JMP (not jsr) FillRowFromPage
  done:
    RTS
.endproc
;;;;
