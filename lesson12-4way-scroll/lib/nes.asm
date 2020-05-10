;;;; SUBROUTINES AND MACROS
.proc WaitVblank
  BIT PPUSTATUS  ;; Test the interrupt bit (bit 7) of the PPUSTATUS port
  BPL WaitVblank ;;Loop until the interrupt bit is set
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
;; 4-byte stack frame: 4 args, 0 locals, 0 return
;; Writes a given number of bytes from a given byte buffer address to the PPU
;; Arg0: LenLo
;; Arg1: LenHi
;; PLO in AddressLo
;; PHI in AddressHi
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
  PLN_SP $02
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
