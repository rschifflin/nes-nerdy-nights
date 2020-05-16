.macro UPDATE_SCROLL_BUFFER
  .scope ;; anonymous
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
    BNE when_nonzero
  when_zero: ;; Special case- We want to buffer bytes from the left edge of the current nametable
    LDA #$00
    LDX #>PPU_ADDR_NAMETABLE0
    LDY #>PPU_ADDR_NAMETABLE1
    JMP set_ppu_target_hi
  when_nonzero:
    TXA
    LDX #>PPU_ADDR_NAMETABLE1
    LDY #>PPU_ADDR_NAMETABLE0
  set_ppu_target_hi:
    STA PLO
    LDA render_flags
    AND #RENDER_FLAG_NAMETABLES_FLIPPED
    BNE when_nametables_flipped
  when_nametables_default:
    TXA
    JMP write
  when_nametables_flipped:
    TYA
  write:
    STA PHI
    LDX PPUSTATUS
    STA PPUADDR
    LDA PLO
    STA PPUADDR

    LDA #<scroll_buffer_right_name
    STA PLO
    LDA #>scroll_buffer_right_name
    STA PHI
    LDA #$1E
    STA r0
    JSR WritePPUNameColumn
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
    BNE when_nonzero
  when_zero: ;; Special case- We want to buffer bytes from the left edge of the current nametable
    LDA #$C0
    LDX #>PPU_ADDR_ATTRTABLE0
    LDY #>PPU_ADDR_ATTRTABLE1
    JMP set_ppu_target_hi
  when_nonzero:
    TXA
    CLC
    ADC #$C0
    LDX #>PPU_ADDR_ATTRTABLE1
    LDY #>PPU_ADDR_ATTRTABLE0
  set_ppu_target_hi:
    STA PLO
    LDA render_flags
    AND #RENDER_FLAG_NAMETABLES_FLIPPED
    BNE when_flipped
  when_default:
    TXA
    JMP write
  when_flipped:
    TYA
  write:
    STA PHI
    LDA #$00
    STA PPUCTRL

    LDX #$00
  loop:
    LDA PPUSTATUS
    LDA PHI
    STA PPUADDR
    LDA PLO
    STA PPUADDR

    LDA scroll_buffer_right_attr,X
    STA PPUDATA
    CPX #$07
    BEQ done
    INX

    LDA PLO
    CLC
    ADC #$08
    STA PLO
    BCC loop
    INC PHI
    JMP loop
  done:
    RTS
.endproc

.proc UpdateLeftScrollName
    LDA #$00
    STA scroll_buffer_status

    LDA cam_x
    .repeat 3
      LSR A
    .endrepeat
    TAX
    DEX
    BPL when_non_negative
  when_negative:
    LDA #$1F
    LDX #$24
    LDY #$20
    JMP set_ppu_target_hi
  when_non_negative:
    TXA
    LDX #$20
    LDY #$24
  set_ppu_target_hi:
    STA PLO
    LDA render_flags
    AND #RENDER_FLAG_NAMETABLES_FLIPPED
    BNE when_nametables_flipped
  when_nametables_default:
    TXA
    JMP write
  when_nametables_flipped:
    TYA
  write:
    STA PHI
    LDX PPUSTATUS
    STA PPUADDR
    LDA PLO
    STA PPUADDR

    LDA #<scroll_buffer_left_name
    STA PLO
    LDA #>scroll_buffer_left_name
    STA PHI
    LDA #$1E
    STA r0
    JSR WritePPUNameColumn

    RTS
.endproc

.proc UpdateLeftScrollAttr
    LDA #$00
    STA scroll_buffer_status

    LDA cam_x
    .repeat 5
      LSR A
    .endrepeat
    TAX
    DEX
    BPL when_non_negative
  when_negative:
    LDA #$C7
    LDX #$27
    LDY #$23
    JMP set_ppu_target_hi
  when_non_negative:
    TXA
    CLC
    ADC #$C0
    LDX #$23
    LDY #$27
  set_ppu_target_hi:
    STA PLO
    LDA render_flags
    AND #RENDER_FLAG_NAMETABLES_FLIPPED
    BNE when_nametables_flipped
  when_nametables_default:
    TXA
    JMP write
  when_nametables_flipped:
    TYA
  write:
    STA PHI
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
    CPX #$07
    BEQ done
    INX

    LDA PLO
    CLC
    ADC #$08
    STA PLO
    BCC loop
    INC PHI
    JMP loop
  done:
    RTS
.endproc

.proc UpdateTopScrollName
    LDA #$00
    STA scroll_buffer_status

    ;; When advancing down, we always draw to the line of the scroll buffer
    ;; When retreating up, we always draw to the line above the scroll buffer
    LDA ppu_scroll_y
    .repeat 3
      LSR A
    .endrepeat
    ;; Write the line ABOVE ppu_scroll_y- if it underflows ensure it wraps to 29
    TAX
    DEX
    TXA
    BPL within_range ;; branch when no underflow
    LDA #$1D ;; Underflow to 29
  within_range:
    STA PLO
    LDA #$00
    STA PHI

    PHN_SP 2
    JSR _UpdateScrollNameRow
    .scope write
      first_write:
        LDY r0 ;; u_len
        LDX #$00
      @loop:
        LDA scroll_buffer_top_name, X
        STA PPUDATA
        INX
        DEY
        BNE @loop

      reset_addr:
        LDA PPUSTATUS
        PLA_SP ;; v-hi
        STA PPUADDR
        PLA_SP ;; v-lo
        STA PPUADDR

      second_write:
        LDY r1 ;; v_len
        LDX r0 ;; u_len
      @loop:
        LDA scroll_buffer_top_name, X
        STA PPUDATA
        INX
        DEY
        BNE @loop
    .endscope
    RTS
.endproc

.proc UpdateBottomScrollName
    LDA #$00
    STA scroll_buffer_status

    ;; When advancing down, we always draw to the line of the scroll buffer
    ;; When retreating up, we always draw to the line above the scroll buffer
    LDA ppu_scroll_y
    .repeat 3
      LSR A
    .endrepeat
    STA PLO
    LDA #$00
    STA PHI

    PHN_SP 2
    JSR _UpdateScrollNameRow
    .scope write
      first_write:
        LDY r0 ;; u_len
        LDX #$00
      @loop:
        LDA scroll_buffer_bottom_name, X
        STA PPUDATA
        INX
        DEY
        BNE @loop

      reset_addr:
        LDA PPUSTATUS
        PLA_SP ;; v-hi
        STA PPUADDR
        PLA_SP ;; v-lo. Stack now cleared again
        STA PPUADDR

      second_write:
        LDY r1 ;; v_len
        LDX r0 ;; u_len
      @loop:
        LDA scroll_buffer_bottom_name, X
        STA PPUDATA
        INX
        DEY
        BNE @loop
    .endscope
    RTS
.endproc

;;;; _UpdateScrollNameRow
;; 2-byte stack: 0 args, 2 return
;; DRY inner method for UpdateTopScrollName and UpdateBottomScrollName
;; Expects PLO,PHI to hold a 16-bit offset of the target row
;; Returns r0 = u_len, r1 = v_len
.proc _UpdateScrollNameRow
    ;; Stack frame
    v_ppu_lo = SW_STACK-1
    v_ppu_hi = SW_STACK
    ;;;;

    ;; We split the write across both horizontal nametables.
    ;; NameTable offset is 32 bytes per row, we need to multiply by 32 to get the nametable addr
    CLC
    .repeat 5
      ROL PLO ;; PLO holds the low byte of A*32
      ROL PHI ;; PHI holds the high byte of A*32
    .endrepeat
    LDA cam_x
    .repeat 3
      LSR A
    .endrepeat
    TAX

    LDA #$00 ;; Increment by 1 each write
    STA PPUCTRL

    LDA render_flags
    AND #RENDER_FLAG_NAMETABLES_FLIPPED
    BNE when_nametables_flipped
    ;; Imagine two nametables, u and v
    ;; We want to write our row spanning across u and v
    ;; The equation to write is:
    ;; Write u: u_ppu_lo = addr_u_lo + u_offset + row_offset_lo
    ;;          u_ppu_hi = addr_u_hi + row_offset_hi + prev_carry
    ;;          u_buffer = buffer_addr
    ;;          u_len = 32 - u_offset
    ;;
    ;; Write v: v_ppu_lo = addr_v_lo + row_offset_lo
    ;;          v_ppu_hi = addr_v_hi + row_offset_hi + prev_carry
    ;;          v_buffer = buffer_addr + u_len
    ;;          v_len = u_offset + 1
    ;;
    ;; We calculate those 4 values for v and push them
    ;; Then we calculate those 4 values for u and execute them
    ;; Then we pull those 4 values for v and execute them

    ;; PLO = row_offset_lo
    ;; PHI = row_offset_hi
    ;; X = coarse scroll x = u_offset
    .scope no_flip
        U_NAMETABLE = PPU_ADDR_NAMETABLE0
        V_NAMETABLE = PPU_ADDR_NAMETABLE1

        ;; Calculate the far name tables first, and push them for later
        LDY SP
        LDA PLO ;; addr_v_lo (0) + row_offset_lo
        STA v_ppu_lo,Y ;; v_ppu_lo
        LDA #>V_NAMETABLE
        CLC
        ADC PHI ;; addr_v_hi + row_offset_hi + carry (0)
        STA v_ppu_hi,Y

        ;; Calculate near nametables and prepare first write
        LDA PPUSTATUS ;; Reset addr latch
        TXA ;; coarse scroll-x
        CLC
        ADC PLO ;; addr_u_lo (0) + row_offset_lo + u_off
        TAY
        LDA #>U_NAMETABLE
        ADC PHI ;; addr_u_hi + row_offset_hi + prev_carry
        STA PPUADDR ;; u_ppu_hi
        TYA
        STA PPUADDR ;; u_ppu_lo
        JMP calculate_lengths
    .endscope
  when_nametables_flipped:
    .scope flip
        U_NAMETABLE = PPU_ADDR_NAMETABLE1
        V_NAMETABLE = PPU_ADDR_NAMETABLE0

        ;; Calculate the far name tables first, and push them for later
        LDY SP
        LDA PLO ;; addr_v_lo (0) + row_offset_lo
        STA v_ppu_lo,Y ;; v_ppu_lo
        LDA #>V_NAMETABLE
        CLC
        ADC PHI ;; addr_v_hi + row_offset_hi + carry (0)
        STA v_ppu_hi,Y ;; v_ppu_hi

        ;; Calculate near nametables and prepare first write
        LDA PPUSTATUS ;; Reset addr latch
        TXA ;; coarse scroll-x
        CLC
        ADC PLO ;; addr_u_lo (0) + row_offset_lo + u_off
        TAY
        LDA #>U_NAMETABLE
        ADC PHI ;; addr_u_hi + row_offset_hi + prev_carry
        STA PPUADDR ;; u_ppu_hi
        TYA
        STA PPUADDR ;; u_ppu_lo
    .endscope

  calculate_lengths:
    TXA ;; coarse scroll-x
    STA r0
    LDA #$20 ;; 32 bytes
    SEC
    SBC r0
    STA r0 ;; u_len

    TXA
    CLC
    ADC #$01
    STA r1 ;; v_len

    RTS
.endproc

.proc UpdateTopScrollAttr
  RTS
.endproc

;.proc UpdateBottomScrollName
;    LDA #$00
;    STA scroll_buffer_status
;
;    ;; When advancing down, we always draw to the line of the scroll buffer
;    ;; When retreating up, we always draw to the line above the scroll buffer
;    LDA ppu_scroll_y
;    .repeat 3
;      LSR A
;    .endrepeat
;  within_range:
;    ;; NameTable offset is 32 bytes per row so multiply by 32 per coarse scroll_y
;    STA r0
;    LDA #$00
;    STA r1
;    CLC
;    .repeat 5
;      ROL r0 ;; r0 holds the low byte of A*32
;      ROL r1 ;; r1 holds the high byte of A*32
;    .endrepeat
;
;    LDA #$00 ;; Increment by 1 each write
;    STA PPUCTRL
;
;    ;; set PPU address of 1-32 bytes, in the near nametable
;    LDA PPUSTATUS
;    LDA r1
;    CLC
;    ADC #>PPU_ADDR_NAMETABLE0
;    STA PPUADDR
;    LDA r0
;    STA PPUADDR
;    Call_WritePPUBytes scroll_buffer_bottom_name, $20
;
;    RTS
;  RTS
;.endproc

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
        JSR UpdateBottomScrollName ;; Positive Y means towards the bottom
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
        JSR UpdateTopScrollName ;; Decreasing Y means towards the top
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
