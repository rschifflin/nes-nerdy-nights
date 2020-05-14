.macro UPDATE_SCROLL_BUFFER
.scope
  LDA #PPUCTRL_INC32
  STA PPUCTRL

.endscope
.endmacro

.proc UpdateRightScrollName
    LDA #$00
    STA scroll_buffer_status

    LDA cam_x
    .repeat 3
      LSR A
    .endrepeat
    TAX
    INX
    CPX #$20 ;; 32 tiles = 256 bytes, which means we wrapped around to 0
    BNE handle_nonzero
  handle_zero: ;; Special case- We want to buffer bytes from the left edge of the current nametable
    .scope zero_case
        LDX #$00
        LDA render_flags
        AND #RENDER_FLAG_NAMETABLES_FLIPPED
        BNE when_flipped
      when_default:
        LDY #$20
        JSR SetPPUAddress
        JMP write
      when_flipped:
        LDY #$24
        JSR SetPPUAddress
        JMP write
    .endscope
  handle_nonzero: ;; Common case- We want to buffer bytes from 8 pixels right of our offset in the opposite nametable
    .scope nonzero_case
        LDA render_flags
        AND #RENDER_FLAG_NAMETABLES_FLIPPED
        BNE when_flipped
      when_default:
        LDY #$24
        JSR SetPPUAddress
        JMP write
      when_flipped:
        LDY #$20
        JSR SetPPUAddress
    .endscope
  write:
    LDA #PPUCTRL_INC32
    STA PPUCTRL
    Call_WritePPUBytes scroll_buffer_right_name, $1E ;; 30 bytes
    RTS
.endproc

.proc UpdateRightScrollAttr
    LDA #$00
    STA scroll_buffer_status

    LDA cam_x
    .repeat 5
      LSR A
    .endrepeat
    TAX
    INX
    CPX #$08 ;; 8 regions = 256 pixels, we wrapped around to 0
    BNE handle_nonzero
  handle_zero:
    .scope zero_case
        LDA #$C0
        STA PLO
        LDA render_flags
        AND #RENDER_FLAG_NAMETABLES_FLIPPED
        BNE when_flipped
      when_default:
        LDA #$23
        STA PHI
        JMP write
      when_flipped:
        LDA #$27
        STA PHI
        JMP write
    .endscope
  handle_nonzero:
    .scope nonzero_case
        TXA
        CLC
        ADC #$C0
        STA PLO
        LDA render_flags
        AND #RENDER_FLAG_NAMETABLES_FLIPPED
        BNE when_flipped
      when_default:
        LDA #$27
        STA PHI
        JMP write
      when_flipped:
        LDA #$23
        STA PHI
    .endscope
  write:
    LDX #$00
  loop:
    LDA PPUSTATUS
    LDA PHI
    STA PPUADDR
    LDA PLO
    STA PPUADDR
    LDA scroll_buffer_right_attr,X
    STA PPUDATA
    LDA PLO
    CLC
    ADC #$08
    STA PLO
    LDA PHI
    ADC #$00
    STA PHI
    INX
    CPX #$08
    BNE loop

    RTS
.endproc

.proc UpdateLeftScrollName
    LDA #$00
    STA scroll_buffer_status

    LDA cam_x
    .repeat 3
      LSR A
    .endrepeat
    BNE handle_nonzero
  handle_zero: ;; Special case- We want to buffer bytes from the right edge of the opposite nametable
    .scope zero_case
        LDX #$1F
        LDA render_flags
        AND #RENDER_FLAG_NAMETABLES_FLIPPED
        BNE when_flipped
      when_default:
        LDY #$24
        JSR SetPPUAddress
        JMP write
      when_flipped:
        LDY #$20
        JSR SetPPUAddress
        JMP write
    .endscope
  handle_nonzero: ;; Common case- We want to buffer bytes from 8 pixels left of the current nametable
    .scope nonzero_case
        TAX
        DEX
        LDA render_flags
        AND #RENDER_FLAG_NAMETABLES_FLIPPED
        BNE when_flipped
      when_default:
        LDY #$20
        JSR SetPPUAddress
        JMP write
      when_flipped:
        LDY #$24
        JSR SetPPUAddress
    .endscope
  write:
    LDA #PPUCTRL_INC32
    STA PPUCTRL
    Call_WritePPUBytes scroll_buffer_left_name, $1E ;; 30 bytes

    RTS
.endproc

.proc UpdateLeftScrollAttr
    LDA #$00
    STA scroll_buffer_status

    LDA cam_x
    .repeat 5
      LSR A
    .endrepeat
    BNE handle_nonzero
  handle_zero: ;; Special case- We want to buffer bytes from the right edge of the opposite attr_table
    .scope zero_case
        LDA #$C7
        STA PLO
        LDA render_flags
        AND #RENDER_FLAG_NAMETABLES_FLIPPED
        BNE when_flipped
      when_default:
        LDA #>$27C7
        STA PHI
        JMP write
      when_flipped:
        LDA #>$23C7
        STA PHI
        JMP write
    .endscope
  handle_nonzero: ;; Common case- We want to buffer bytes from 1 byte left of the current attr_table
    ;; AttrTable offset is at xxC0, perform the 1-byte-left subtraction here for effective address xxBF
    .scope nonzero_case
        LDA #$BF
        STA PLO
        LDA render_flags
        AND #RENDER_FLAG_NAMETABLES_FLIPPED
        BNE when_flipped
      when_default:
        LDA #>$23BF
        STA PHI
        JMP write
      when_flipped:
        LDA #>$27BF
        STA PHI
    .endscope
  write:
    LDA cam_x
    .repeat 5
      LSR A
    .endrepeat
    CLC
    ADC PLO
    STA PLO ;; Overflow is impossible from 23C0 + 7

    LDA #$00
    STA PPUCTRL

    LDX #$00
  loop:
    LDA PPUSTATUS
    LDA PHI
    STA PPUADDR
    LDA PLO
    STA PPUADDR
    LDA scroll_buffer_left_attr,X
    STA PPUDATA
    LDA PLO
    CLC
    ADC #$08
    STA PLO
    INX
    CPX #$08
    BNE loop

    RTS
.endproc

.proc UpdateTopScrollName
  RTS
.endproc

.proc UpdateTopScrollAttr
  RTS
.endproc

.proc UpdateBottomScrollName
  RTS
.endproc

.proc UpdateBottomScrollAttr
  RTS
.endproc


;; NOTE: The main thread might have gotten interrupted halfway between setting cam_x hi and cam_x lo, or while twos-complementing cam_dx, or other potentially dangerous unfinished operations.
;; We rely on the main thread setting the LOCKED render flag bit to 0 when it is safe to reference data. The NMI in turn has a responsibility to set the bit back to 1 when its done.
;; This means if the CPU cannot finish world code before render, we skip scrolling by cam_dx and skip updating cam_x.
.proc UpdateScroll
    LDA render_flags
    AND #RENDER_FLAG_SCROLL_LOCKED
    BEQ continue
    RTS
  continue:
    LDA render_flags
    ORA #RENDER_FLAG_SCROLL_LOCKED
    STA render_flags

    .scope scroll_x
        LDA cam_dx
        BEQ done ;; No scrolling needed
        BMI negative
      positive:
        LDA cam_dx
        AND #%00000111
        STA r0
        LDA cam_x
        AND #%00000111
        CLC
        ADC r0
        CMP #$08
        BCC @when_within_same_tile
      @when_new_tile:
        JSR UpdateRightScrollName
        LDA cam_dx
        AND #%00000111
        STA r0
        LDA cam_x
        AND #%00011111
        CLC
        ADC r0
        CMP #$20
        BCC @when_within_same_region
      @when_new_region:
        JSR UpdateRightScrollAttr
      @when_within_same_region:
      @when_within_same_tile:
      @update_cam:
        LDA cam_dx
        CLC
        ADC cam_x
        STA cam_x
        BCC done
        INC cam_x+1
        JMP swap_tables
      negative:
        STA_TWOS_COMP cam_dx

        LDA cam_dx
        AND #%00000111
        STA r0
        LDA cam_x
        AND #%00000111
        SEC
        SBC r0
        BPL @when_within_same_tile
      @when_new_tile:
        JSR UpdateLeftScrollName
        LDA cam_dx
        AND #%00000111
        STA r0
        LDA cam_x
        AND #%00011111
        SEC
        SBC r0
        BPL @when_within_same_region
        JSR UpdateLeftScrollAttr
      @when_within_same_region:
      @when_within_same_tile:
      @update_cam:
        LDA cam_x
        SEC
        SBC cam_dx
        STA cam_x
        BCS done
        DEC cam_x+1
      swap_tables:
        ;; Scrolled past the end- swap horizontal banks
        LDA render_flags
        EOR #RENDER_FLAG_NAMETABLES_FLIPPED
        STA render_flags
      done:
        LDA #$00
        STA cam_dx
    .endscope

    .scope scrolly
        LDA cam_dy
        BNE continue ;; scrolling needed
        JMP done ;; When cam_dy is 0, no scrolling needed
      continue:
        BMI negative
      positive:
        LDA cam_dy
        AND #%00000111
        STA r0
        LDA cam_y
        AND #%00000111
        CLC
        ADC r0
        CMP #$08
        BCC @when_within_same_tile
      @when_new_tile:
        JSR UpdateTopScrollName
        LDA cam_dy
        AND #%00000111
        STA r0
        LDA cam_y
        AND #%00011111
        CLC
        ADC r0
        CMP #$20
        BCC @when_within_same_region
      @when_new_region:
        JSR UpdateTopScrollAttr
      @when_within_same_region:
      @when_within_same_tile:
      @update_cam:
        LDA cam_dy
        CLC
        ADC cam_y
        STA cam_y
        BCC @update_scroll
        INC cam_y+1
      @update_scroll:
        ;; Unlike x, where the scroll register matches the camera x low byte perfectly,
        ;; Here the y scroll register is only 0-239.
        ;; Overflow must be capped to that range
        ;; NOTE: We assume cam_dy is also between 0-239, otherwise we have problems!
        LDA ppu_scroll_y
        CLC
        ADC #$10 ;; ppu_scroll now 16-255
        ADC cam_dy
        BCS update_scroll_done ;; When overflow occurs
        SEC
        SBC #$10 ;; Reduce range back from 16-255 to 0-239
        JMP update_scroll_done
      negative:
        STA_TWOS_COMP cam_dy

        LDA cam_dy
        AND #%00000111
        STA r0
        LDA cam_y
        AND #%00000111
        SEC
        SBC r0
        BPL @when_within_same_tile
      @when_new_tile:
        JSR UpdateBottomScrollName
        LDA cam_dy
        AND #%00000111
        STA r0
        LDA cam_y
        AND #%00011111
        SEC
        SBC r0
        BPL @when_within_same_region
        JSR UpdateBottomScrollAttr
      @when_within_same_region:
      @when_within_same_tile:
      @update_cam:
        LDA cam_y
        SEC
        SBC cam_dy
        STA cam_y
        BCS @update_scroll
        DEC cam_y+1
      @update_scroll:
        ;; Unlike x, where the scroll register matches the camera x low byte perfectly,
        ;; Here the y scroll register is only 0-239.
        ;; Underflow must be capped to that range
        ;; NOTE: We assume cam_dy is also between 0-239, otherwise we have problems!
        LDA ppu_scroll_y ;; range 0-239
        SEC
        SBC cam_dy
        BCS update_scroll_done ;; When no underflow occurs
        SEC
        SBC #$10 ;; Subtract 16 from the underflowed value to bring it under 239
      update_scroll_done:
        STA ppu_scroll_y
      done:
        LDA #$00
        STA cam_dy
    .endscope

    BIT PPUCTRL
    LDA cam_x
    STA PPUSCROLL
    LDA ppu_scroll_y
    STA PPUSCROLL

    RTS
.endproc
