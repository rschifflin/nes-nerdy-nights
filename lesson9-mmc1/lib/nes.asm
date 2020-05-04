;;;; SUBROUTINES AND MACROS
.macro PUSH_IRQ
  PHA ; Push A
  TXA ; X->A
  PHA ; Push X
  TYA ; Y->A
  PHA ; Push Y
  LDA ptr
  PHA ; Push ptr lo register
  LDA ptr+1
  PHA ; Push ptr hi register
  LDA r0
  PHA ; Push r0
.endmacro

.macro POP_IRQ
  PLA ; Pull r0
  STA r0
  PLA ; Pull ptrHi
  STA ptr+1
  PLA ; Pull ptrLo
  STA ptr
  PLA ; Pull Y
  TAY ; A->Y
  PLA ; Pull X
  TAX ; A->X
  PLA ; Pull A
.endmacro

.proc BankSwitchMM1
  .repeat 4
    STA PRG_ROM
    LSR A
  .endrepeat
  STA PRG_ROM
  RTS
.endproc

.proc WaitVblank
  BIT PPUSTATUS   ; Test the interrupt bit (bit 7) of the PPUSTATUS port
  BPL WaitVblank ; Loop until the interrupt bit is set
  RTS
.endproc

.macro SET_PPU_ADDRESS arg_ptr
  LDX #<arg_ptr
  LDY #>arg_ptr
  JSR SetPPUAddress
.endmacro

;; X holds the low byte, Y holds the high byte
.proc SetPPUAddress
  LDA PPUSTATUS ; Prepare to change PPU Address
  TYA
  STA PPUADDR ; write the high byte of the addr
  TXA
  STA PPUADDR ; write the low byte of the addr
  RTS
.endproc

.macro PPU_DMA ptr_arg
  LDA #<ptr_arg
  STA OAMADDR ; Tell PPU the low byte of a memory region for DMA
  LDA #>ptr_arg
  STA OAMDMA ; Tell PPU the high byte of a memory region for DMA, then begin DMA
.endmacro

;; WRITE_PPU_BYTES Pointer, Count
;; Expects Pointer to be a 2-byte address to the start of bytes to write to the ppu
;; Expects Count to be an immediate # of bytes to copy
;; Ex: To load the ppu with 15 bytes from 0x04FE...
;;      WRITE_PPU_BYTES #$04FE, #$0F
;; Ex: To load the ppu with 300 bytes from 0x4444...
;;      WRITE_PPU_BYTES #$4444, #$012C
.macro WRITE_PPU_BYTES arg_ptr, arg_len
  LDA #<arg_ptr
  STA ptr

  LDA #>arg_ptr
  LDX #>arg_len
  LDY #<arg_len
  JSR WritePpuBytes
.endmacro

.proc WritePpuBytes
    STA ptr+1
    STY r0
    LDY #$00
    ;; We iterate using a 2-byte counter. Breaking the counter into Hi and Lo bytes, we iterate 256*Hi + Lo times.

    ;; X keeps the index of the hi loop and counts down
    ;; When X is 0, we've finished counting the hi byte and we enter the lo loop
    ;; When X is nonzero, we enter the hi inner loop
    CPX #$00
  loop_hi_outer:
    BNE loop_hi_inner
    LDY #$00
    JMP loop_lo

    ;; Y keeps the index of the hi inner loop. The inner loop always iterates 256 times.
    ;; During this loop, the base pointer is not modified and Y is used to offset the base pointer.
    ;; After the 256th iteration, we decrement X, modify the base pointer by 256 to keep our place, and return to the outer loop
  loop_hi_inner:
    LDA (ptr),Y
    STA PPUDATA ; Write byte to ppu
    INY ;; may set the ZERO flag to break the hi inner loop
    BNE loop_hi_inner
    INC ptr+1
    DEX ;; may set the ZERO flag to break the hi outer loop
    JMP loop_hi_outer

    ;; During the lo loop, Y keeps the index and counts up to the target stored in r0.
    ;; After r0 iterations, we finish
  loop_lo:
    CPY r0
    BEQ done
    LDA (ptr),Y
    STA PPUDATA ; Write byte to ppu
    INY
    JMP loop_lo
  done:
    RTS
.endproc

.macro UPDATE_CONTROLLER bitmask
  LDA bitmask
  JSR UpdateController
.endmacro

;; UpdateController
;; Updates local memory controller var with read from controller port
;; Expects A to hold the bitmask to apply to the local var
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

;; MOVE_SPRITE_16 Pointer, Direction, Amount
;; Moves the 16px by 16px sprite struct pointed to by Pointer in Direction by Amount
.macro MOVE_SPRITE_16 arg_ptr, arg_direction, arg_amount
  LDA #<arg_ptr
  STA ptr
  LDA #>arg_ptr
  STA ptr+1
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
    LDA (ptr), Y
    CLC
    ADC r0
    STA (ptr), Y
    INY
    INY
    INY
    INY
    DEX
    BNE when_positive
    RTS
  when_negative:
    LDA (ptr), Y
    SEC
    SBC r0
    STA (ptr), Y
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
    LDA (ptr), Y
    STA r0
    LDY #$05
    LDA (ptr), Y
    LDY #$01
    STA (ptr), Y
    LDA r0
    LDY #$05
    STA (ptr), Y

    LDY #$09
    LDA (ptr), Y
    STA r0
    LDY #$0D
    LDA (ptr), Y
    LDY #$09
    STA (ptr), Y
    LDA r0
    LDY #$0D
    STA (ptr), Y

    LDY #$02
    LDX #$04
  loop:
    LDA (ptr), Y
    EOR #SPRITE_FLIP_HORIZONTAL
    STA (ptr), Y
    INY
    INY
    INY
    INY
    DEX
    BNE loop
    RTS
.endproc

;; AdcDec
;; Acts like ADC but only operates on two decimal bytes guaranteed to be between 0-9.
;; Result is a decimal byte 0-9, with the carry bit indicating overflow
;;; <--
;; A = Augend in decimal
;; X = Addend in decimal
;;; ->
;; A = Sum
;; Sets Carry bit on oveflow
.proc AdcDec
    STX r0
    ADC r0
    CMP #$0A
    BCC done ; done if result < 10
    ;; Handle overflow
    SEC ;; Prepare to sub
    SBC #$0A
    SEC ;; Indicate overflow
  done:
    RTS
.endproc
