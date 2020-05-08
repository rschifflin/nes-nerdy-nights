.macro UPDATE_SCROLL_BUFFER
.scope
  LDA #PPUCTRL_INC32
  STA PPUCTRL

.endscope
.endmacro

.proc UpdateScroll
  .scope write_scroll_x_right_buffer
      LDA cam_x
      .repeat 3
        LSR A
      .endrepeat
      TAX
      LDA sysflags
      AND #SYSFLAG_SCROLL_X_ORDER
      BNE when_flipped
    when_default:
      LDY #$24
      JSR SetPPUAddress
      JMP write
    when_flipped:
      LDY #$20
      JSR SetPPUAddress
    write:
      LDA #PPUCTRL_INC32
      STA PPUCTRL
      Call_WritePPUBytes scroll_buffer_x_right, $1E ;; 30 bytes
  .endscope
  .scope write_scroll_x_left_buffer
      LDA cam_x
      .repeat 3
        LSR A
      .endrepeat
      BNE handle_nonzero
    handle_zero: ;; Special case- We want to buffer bytes from 8 pixels off the right edge of the opposite nametable
      .scope zero_case
          LDX #$1F
          LDA sysflags
          AND #SYSFLAG_SCROLL_X_ORDER
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
          LDA sysflags
          AND #SYSFLAG_SCROLL_X_ORDER
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
      Call_WritePPUBytes scroll_buffer_x_left, $1E ;; 30 bytes
    done:
  .endscope

  .scope scroll_x
      LDA cam_dx
      BMI negative
    positive:
      CLC
      ADC cam_x
      STA cam_x
      BCC done
      INC cam_x+1
      JMP swap_tables
    negative:
      STA_TWOS_COMP cam_dx
      LDA cam_x
      SEC
      SBC cam_dx
      STA cam_x
      BCS done
      DEC cam_x+1
    swap_tables:
      ;; Scrolled past the end- swap horizontal banks
      LDA sysflags
      EOR #SYSFLAG_SCROLL_X_ORDER
      STA sysflags
    done:
      LDA #$00
      STA cam_dx
  .endscope

  LDA #$00
  STA cam_dy

  BIT PPUCTRL
  LDA cam_x
  STA PPUSCROLL
  LDA cam_y
  STA PPUSCROLL

  RTS
.endproc
