;;;; SUBROUTINES AND MACROS
.proc WaitVblank
  BIT PPUSTATUS  ;; Test the interrupt bit (bit 7) of the PPUSTATUS port
  BPL WaitVblank ;; branch when bit is low, aka loop until the interrupt bit is set
  RTS
.endproc

;;;; InitMemory
;; Clears all non-stack RAM values
;; Sets the initial PPU sprite DMA data for first render
.proc InitMemory
    LDA #$00
    TAX
  clear:
    STA $0000, x
    STA $0300, x
    STA $0400, x
    STA $0500, x
    STA $0600, x
    STA $0700, x
    INX
    BNE clear
  fill_sprites:
    LDA sprite_data, x
    STA sprite_area, x
    INX
    CPX #$10 ;; 16 bytes of sprite values
    BNE fill_sprites
    LDA #$FE
  fill_invisible: ;; fill rest with an invisible sprite
    STA sprite_area, x
    INX
    BNE fill_invisible
    RTS
.endproc
;;;;

;;;;WritePPUAttrColumn
;; 4-byte stack: 4 args, 0 return
;; Expects P to hold address of buffer to read from
;; Expects r0 to hold length of buffer to read from
;; Sets PPUADDR to ppuTargetLo/Hi
;; NOTE: If we mirror horizontally, this method can write
;; a logical column through both vertical attribute tables.
;; If we mirror vertically, this method writes into
;; the mirrored attribute table, causing a wrap effect.
.proc WritePPUAttrColumn
    ;; Arguments
    ppuTargetLo  = SW_STACK-3
    ppuTargetHi  = SW_STACK-2
    scrollX      = SW_STACK-1
    scrollY      = SW_STACK-0
    bufferLen    = r0
    srcLo        = PLO
    srcHi        = PHI

    ;; Locals
    columnLen    = r1

    LDX SP
    ;; Transform scroll pixel values into coarse scroll region values, range [0,7]
    .repeat 5
      LSR scrollX,X
      LSR scrollY,X
    .endrepeat

    LDA ppuTargetLo,X
    CLC
    ADC scrollX,X
    STA ppuTargetLo,X ;; Offset target to the correct column
    BCC @no_carry
    INC ppuTargetHi,X
  @no_carry:
    LDA #$08 ;; Max rows in an attr column
    SEC
    SBC scrollY,X ;; Minus offset rows aka coarse scroll y
    STA columnLen ;; r1 now holds # of rows remaining for this table after we offset
                  ;; NOTE: Guaranteed to be > 0 since coarse scroll_y has range [0,7]

    ;; Multiply scrolly regions by 8 to create row byte offset.
    CLC
    LDA scrollY,X
    .repeat 2
      ROL A
    .endrepeat
    ADC ppuTargetLo,X
    STA scrollX,X ;; repurpose scrollX as targetLoWithOffset
    LDA ppuTargetHi,X
    ADC #$00 ;; Add carry if needed
    STA scrollY,X ;; repurpose scrollY as targetHiWithOffset

    LDA #$00 ;; inc by 1 each write. Ignore all other settings
    STA PPUCTRL

    ;; Fall into the Write proc as a tail call
    ;;;; Write
    ;; Expects P=src, r0=buffer_len, r1=column_len
    .proc Write
        ;; Arguments
        ppuTargetLo           = SW_STACK-3
        ppuTargetHi           = SW_STACK-2
        ppuTargetLoWithOffset = SW_STACK-1
        ppuTargetHiWithOffset = SW_STACK-0
        bufferLen             = r0
        columnLen             = r1
        srcLo                 = PLO
        srcHi                 = PHI

        ;; Guard clause against empty buffers
        LDA bufferLen
        BNE continue
        RTS
      continue:

        ;; Count down and write until buffer len is empty or attr table limit is hit
        LDX SP
        LDY #$00
      loop:
        ;; Set PPU addr
        LDA PPUSTATUS
        LDA ppuTargetHiWithOffset,X
        STA PPUADDR
        LDA ppuTargetLoWithOffset,X
        STA PPUADDR

        ;; Write attr byte
        LDA (PLO),Y
        STA PPUDATA

        ;; Prepare next PPU Addr
        LDA ppuTargetLoWithOffset,X
        CLC
        ADC #$08
        STA ppuTargetLoWithOffset,X
        BCC @no_carry
        INC ppuTargetHiWithOffset,X
      @no_carry:
        INY
        DEC bufferLen
        BNE when_nonempty
        RTS ;; len is empty, job is done
      when_nonempty:
        DEC columnLen ;; Y-scroll never exceeds 239, thus columnLen is always nonzero to start
        BNE loop ;; Loop while there's still space in this attr table column to write
        ;; Else, out of attr table space with data still to be written.

        LDA #$08 ;; Fresh 8 bytes of attr table space for the column
        STA columnLen

        ;; Advance down the buffer Y bytes for the next call
        TYA
        CLC
        ADC PLO
        STA PLO
        BCC @no_carry
        INC PHI
      @no_carry:

        ;; Swap nametables
        LDA ppuTargetHi,X
        CMP #>PPU_ADDR_ATTRTABLE2
        BCS when_far_attr_table
      when_near_attr_table:
        CLC
        ADC #$08
        JMP swap_done
      when_far_attr_table:
        SEC
        SBC #$08
      swap_done:
        STA ppuTargetHi,X

        ;; Reset offsets to top of column
        STA ppuTargetHiWithOffset,X
        LDA ppuTargetLo,X
        STA ppuTargetLoWithOffset,X
        ;; Tail call
        JMP Write
    .endproc
.endproc


;;;; SetPPUAddress
;; X holds the low byte
;; Y holds the high byte
.proc SetPPUAddress
  LDA PPUSTATUS ; Prepare to change PPU Address
  TYA
  STA PPUADDR ; write the high byte of the addr
  TXA
  STA PPUADDR ; write the low byte of the addr
  RTS
.endproc

.macro SET_PPU_ADDRESS arg_ptr
  LDX #<arg_ptr
  LDY #>arg_ptr
  JSR SetPPUAddress
.endmacro
;;;;

.macro PPU_DMA ptr_arg
  LDA #<ptr_arg
  STA OAMADDR ; Tell PPU the low byte of a memory region for DMA
  LDA #>ptr_arg
  STA OAMDMA ; Tell PPU the high byte of a memory region for DMA, then begin DMA
.endmacro


;;;; WritePPUNameColumn
;; Expects P to hold a pointer to a nametable column buffer
;; Expects r0 to hold buffer len
.proc WritePPUNameColumn
    LDA #PPUCTRL_INC32
    STA PPUCTRL

    LDY #$00
    LDX r0
    loop:
      LDA (PLO),Y
      STA PPUDATA
      INY
      DEX
      BNE loop
    RTS
.endproc

;;;; WritePPUBytes
;; 2-byte stack frame: 2 args, 0 locals, 0 return
;; Expects P to hold the address to write to
;; Writes a given number of bytes from a given byte buffer address to the PPU
;; Arg0: LenLo
;; Arg1: LenHi
.proc WritePpuBytes
    len = SW_STACK-1
    LDX SP
  loop_hi:
    LDA len+1,X
    BEQ loop_lo
    TAX
    LDY #$00
  @loop:
    LDA (PLO),Y
    STA PPUDATA ; Write byte to ppu
    INY
    BNE @loop
    INC PHI
    DEX
    BNE @loop
  loop_lo:
    LDX SP
    LDA len,X
    BEQ done
    TAX
    LDY #$00
  @loop:
    LDA (PLO),Y
    STA PPUDATA ; Write byte to ppu
    INY
    DEX
    BNE @loop
  done:
    RTS
.endproc

.macro Call_WritePPUBytes arg_ptr, arg_len
  LDA #<arg_ptr
  STA PLO
  LDA #>arg_ptr
  STA PHI
  LDA #<arg_len
  PHA_SP
  LDA #>arg_len
  PHA_SP
  JSR WritePpuBytes
  PLN_SP 2
.endmacro
;;;;

;;;; UpdateController
;; 0-byte stack frame: 0 args, 0 locals, 0 return
;; Updates local memory controller var with reads from controller port
.proc UpdateController
    ;; zero out in-mem controller
    LDA #$00
    STA p1_controller
    STA p2_controller
    LDA #$01
    STA CONTROLLER_STATUS ;; Instructs the controller to switch to parallel and fill with player inputs
    LDA #$00
    STA CONTROLLER_STATUS ;; Instructs the controller to switch to serial for reading outputs
    ;; Read controller 8 times; push bits to controller var
    LDX #$08
  loop:
    LDA CONTROLLER_P1
    LSR A ;; Shift right, overshifted bit is stored in carry
    ROL p1_controller ;; Shift left, bit from carry is brought in
    LDA CONTROLLER_P2
    LSR A ;; Shift right, overshifted bit is stored in carry
    ROL p2_controller ;; Shift left, bit from carry is brought in
    DEX
    BNE loop
    RTS
.endproc
;;;;
