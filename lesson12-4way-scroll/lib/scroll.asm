.macro UPDATE_SCROLL_BUFFER
.scope
  LDA #PPUCTRL_INC32
  STA PPUCTRL

.endscope
.endmacro

.proc UpdateRightScroll
  LDA cam_x
  AND #%00000111
  BEQ update_name
  RTS
update_name:
  .scope write_scroll_right_name
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
      Call_WritePPUBytes scroll_buffer_right_name, $1E ;; 30 bytes
  .endscope

  LDA cam_x
  AND #%00011111
  BEQ update_attr
  RTS
update_attr:
  .scope write_scroll_right_attr
      LDA sysflags
      AND #SYSFLAG_SCROLL_X_ORDER
      BNE when_flipped
    when_default:
      LDA #<$27C0
      STA PLO
      LDA #>$27C0
      STA PHI
      JMP write
    when_flipped:
      LDA #<$23C0
      STA PLO
      LDA #>$23C0
      STA PHI
    write:
      LDA cam_x
      .repeat 5
        LSR A
      .endrepeat
      CLC
      ADC PLO
      STA PLO
      LDA #$00
      ADC PHI
      STA PHI
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
  .endscope

  RTS
.endproc

.proc UpdateLeftScroll
  LDA cam_x
  AND #%00000111
  BEQ update_name
  RTS
update_name:
  .scope write_scroll_left_name
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
      Call_WritePPUBytes scroll_buffer_left_name, $1E ;; 30 bytes
    done:
  .endscope

  LDA cam_x
  AND #%00011111
  BEQ update_attr
  RTS
update_attr:
  .scope write_scroll_left_attr
      LDA cam_x
      .repeat 5
        LSR A
      .endrepeat
      BNE handle_nonzero
    handle_zero: ;; Special case- We want to buffer bytes from 8 pixels off the right edge of the opposite nametable
      .scope zero_case
          LDA #$C7
          STA PLO
          LDA sysflags
          AND #SYSFLAG_SCROLL_X_ORDER
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
    handle_nonzero: ;; Common case- We want to buffer bytes from 8 pixels left of the current nametable
      .scope nonzero_case
          LDA #$BF
          STA PLO
          LDA sysflags
          AND #SYSFLAG_SCROLL_X_ORDER
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
      SEC
      SBC #$08
      .repeat 5
        LSR A
      .endrepeat
      CLC
      ADC PLO
      STA PLO
      LDA #$00
      ADC PHI
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
      LDA PLO
      CLC
      ADC #$08
      STA PLO
      INX
      CPX #$08
      BNE loop
    done:
  .endscope
  RTS
.endproc

.proc UpdateScroll
  .scope scroll_x
      LDA cam_dx
      BEQ done
      BMI negative
    positive:
      JSR UpdateRightScroll

      LDA cam_dx
      CLC
      ADC cam_x
      STA cam_x
      BCC done
      INC cam_x+1
      JMP swap_tables
    negative:
      ;;JSR UpdateLeftScroll

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
