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

;;;;WritePPUNameColumn
;; 3-byte stack: 3 args, 0 return
;; Expects P to hold address of buffer to read from
;; Expects r0 to hold length of buffer to read from
;; PPUTargetLo is generated from the given offsets
;; Sets PPUCTRL to INC32 and PPUADDR to ppuTargetLo/Hi
;; NOTE: If we mirror horizontally, this method can write
;; a logical column through both vertical name tables.
;; If we mirror vertically, this method writes into
;; the mirrored nametable, causing a wrap effect.
.proc WritePPUNameColumn
    ;; Stack frame
    ppuTargetHi  = SW_STACK-2
    scrollX      = SW_STACK-1
    scrollY      = SW_STACK-0
    bufferLen    = r0
    columnLen    = r1

    LDX SP
    .repeat 3
      LSR scrollX,X
      LSR scrollY,X
    .endrepeat
    ;; Transforms scroll pixel values into coarse scroll tile values

    LDA #$1E ;; Max rows in a name column
    SEC
    SBC scrollY,X ;; Minus offset rows aka coarse scroll y
    STA columnLen ;; r1 now holds # of rows remaining for this page after we offset
                  ;; NOTE: Guaranteed to be > 0 since scroll_y is <= 239

    LDA #PPUCTRL_INC32
    STA PPUCTRL

    LDX SP
    ;; Set PPUADDR based on given Hi and coarse scroll offsets
    LDA scrollY,X
    BEQ target_skip ;; If no scroll-y, no calculation needed
    LDA scrollX,X
    LDY ppuTargetHi,X
  target_loop:
    CLC
    ADC #$20 ;; Add 32 columns of bytes for each row offset
    BCC @no_carry
    INY ;; Bump ppu target hi on carry
  @no_carry:
    DEC scrollY,X
    BNE target_loop
    JMP target_done
  target_skip:
    LDA scrollX,X
    LDY ppuTargetHi,X
  target_done:
    LDX PPUSTATUS ;; Prepare to change PPU Address
    STY PPUADDR   ;; PPU high = targetHi from calculated above
    STA PPUADDR   ;; PPU low =  targetLo from calculated above
    ;; Fall into the Write proc as a tail call

    ;;;; Write
    ;; Expects P=src, r0=buffer_len, r1=column_len
    .proc Write
        ;; Stack frame
        ppuTargetHi        = SW_STACK-2
        ppuTargetLo        = SW_STACK-1
        _unused            = SW_STACK-0
        bufferLen          = r0
        columnLen          = r1

        ;; Guard clause against empty buffers
        LDA bufferLen
        BNE continue
        RTS
      continue:

        ;; Count down and write until buffer len is empty or name table limit is hit
        LDX SP
        LDY #$00
      loop:
        LDA (PLO),Y
        STA PPUDATA
        INY
        DEC bufferLen
        BNE when_nonempty
        RTS ;; len is empty, job is done
      when_nonempty:
        DEC columnLen ;; Y-scroll never exceeds 239, thus columnLen is always nonzero to start
        BNE loop ;; Loop while there's still space in this nametable column to write
        ;; Else, out of nametable space with data still to be written.

        LDA #$1E ;; Fresh 30 bytes of nametable space for the column
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
        CMP #>PPU_ADDR_NAMETABLE2
        BCS when_far_name_table
      when_near_name_table:
        CLC
        ADC #$08
        JMP swap_done
      when_far_name_table:
        SEC
        SBC #$08
      swap_done:
        STA ppuTargetHi,X

        ;; Change PPUADDR
        LDY PPUSTATUS ;; Prepare to change PPU Address
        STA PPUADDR   ;; Set PPU High
        LDA ppuTargetLo,X
        STA PPUADDR   ;; Set PPU Low

        ;; Tail call recursion
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

;; TODO: UPDATE REMAINING LIBRARY CODE WITH NEW CALLING CONVENTION

;;;; MOVE_SPRITE_16 Pointer, Direction, Amount
;; Moves the 16px by 16px sprite struct pointed to by Pointer in Direction by Amount
.macro MOVE_SPRITE_16 arg_ptr, arg_direction, arg_amount
  LDA #<arg_ptr
  STA PLO
  LDA #>arg_ptr
  STA PHI
  LDA #arg_amount
  STA r0
  LDA #arg_direction ; Direction
  JSR MoveSprite16
.endmacro
.proc MoveSprite16
    TAX
    AND #DIR_VERTICAL
    BEQ prepare_hor
  prepare_vert:
    LDY #$00
    JMP prepare_done
  prepare_hor:
    LDY #$03
  prepare_done:
    TXA
    LDX #$04
    AND #DIR_POSITIVE
    BEQ when_negative
  when_positive:
    LDA (PLO), Y
    CLC
    ADC r0
    STA (PLO), Y
    INY
    INY
    INY
    INY
    DEX
    BNE when_positive
    RTS
  when_negative:
    LDA (PLO), Y
    SEC
    SBC r0
    STA (PLO), Y
    INY
    INY
    INY
    INY
    DEX
    BNE when_negative
    RTS
.endproc

;; FLIPH_SPRITE_16 Pointer
;; Flips a 16px by 16px sprite struct pointed to by Pointer horizontally
.macro FLIPH_SPRITE_16 arg_ptr
  LDA #<arg_ptr
  STA ptr
  LDA #>arg_ptr
  STA ptr+1
  JSR FlipHSprite16
.endmacro
.proc FlipHSprite16
    LDY #$01
    LDA (PLO), Y
    STA r0
    LDY #$05
    LDA (PLO), Y
    LDY #$01
    STA (PLO), Y
    LDA r0
    LDY #$05
    STA (PLO), Y

    LDY #$09
    LDA (PLO), Y
    STA r0
    LDY #$0D
    LDA (PLO), Y
    LDY #$09
    STA (PLO), Y
    LDA r0
    LDY #$0D
    STA (PLO), Y

    LDY #$02
    LDX #$04
  loop:
    LDA (PLO), Y
    EOR #SPRITE_FLIP_HORIZONTAL
    STA (PLO), Y
    INY
    INY
    INY
    INY
    DEX
    BNE loop
    RTS
.endproc
