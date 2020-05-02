;;;; SUBROUTINES AND MACROS
WaitVblank
  BIT PPUSTATUS   ; Test the interrupt bit (bit 7) of the PPUSTATUS port
  BPL WaitVblank ; Loop until the interrupt bit is set
  RTS

PUSH_IRQ .macro
  PHP ; Push flags - might not be necessary!
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
  .endm

POP_IRQ .macro
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
  PLP ; Pull flags
  .endm

SET_PPU_ADDRESS .macro
  LDA PPUSTATUS ; Prepare to change PPU Address
  LDA #HIGH(\1)
  STA PPUADDR ; write the high byte of the addr
  LDA #LOW(\1)
  STA PPUADDR ; write the low byte of the addr
  .endm

PPU_DMA .macro
  LDA #LOW(\1)
  STA OAMADDR ; Tell PPU the low byte of a memory region for DMA
  LDA #HIGH(\1)
  STA OAMDMA ; Tell PPU the high byte of a memory region for DMA, then begin DMA
  .endm

;; WRITE_PPU_BYTES Pointer, Count
;; Expects Pointer to be a 2-byte address to the start of bytes to write to the ppu
;; Expects Count to be an immediate # of bytes to copy
;; Ex: To load the ppu with 15 bytes from 0x04FE...
;;      LoadPPU #$04FE, #$0F
;; Ex: To load the ppu with 300 bytes from 0x4444...
;;      LoadPPU #$4444, #$012C
WRITE_PPU_BYTES .macro
  LDA #LOW(\1)
  STA ptr
  LDA #HIGH(\1)

  LDY #LOW(\2)
  LDX #HIGH(\2)
  JSR _load_ppu
  .endm
_load_ppu:
  STA ptr+1
  STY r0
  LDY #$00

;; We iterate using a 2-byte counter. Breaking the counter into Hi and Lo bytes, we iterate 256*Hi + Lo times.

;; X keeps the index of the hi loop and counts down
;; When X is 0, we've finished counting the hi byte and we enter the lo loop
;; When X is nonzero, we enter the hi inner loop
  CPX #$00
_write_ppu_bytes_loop_hi:
  BNE _write_ppu_bytes_loop_hi_inner
  LDY #$00
  JMP _write_ppu_bytes_loop_lo

;; Y keeps the index of the hi inner loop. The inner loop always iterates 256 times.
;; During this loop, the base pointer is not modified and Y is used to offset the base pointer.
;; After the 256th iteration, we decrement X, modify the base pointer by 256 to keep our place, and return to the outer loop
_write_ppu_bytes_loop_hi_inner:
  LDA [ptr],Y
  STA PPUDATA ; Write byte to ppu
  INY ;; may set the ZERO flag to break the hi inner loop
  BNE _write_ppu_bytes_loop_hi_inner
  INC ptr+1
  DEX ;; may set the ZERO flag to break the hi outer loop
  JMP _write_ppu_bytes_loop_hi

;; During the lo loop, Y keeps the index and counts up to the target stored in r0.
;; After r0 iterations, we finish
_write_ppu_bytes_loop_lo:
  CPY r0
  BEQ _write_ppu_bytes_done
  LDA [ptr],Y
  STA PPUDATA ; Write byte to ppu
  INY
  JMP _write_ppu_bytes_loop_lo
_write_ppu_bytes_done:
  RTS

;; UPDATE_CONTROLLER
;; Updates local memory controller var with read from controller port
;; Expects A to hold the bitmask to apply to the local var
UpdateController:
  ;; zero out in-mem controller
  LDA #$00
  STA controller
  LDA #$01
  STA CONTROLLER_STATUS ;; Instructs the controller to switch to parallel and fill with player inputs
  LDA #$00
  STA CONTROLLER_STATUS ;; Instructs the controller to switch to serial for reading outputs
  ;; Read controller 8 times; push bits to controller var
  LDX #$08
_update_controller_loop:
  LDA CONTROLLER_P1
  LSR A ;; Shift right, overshifted bit is stored in carry
  ROL controller ;; Shift left, bit from carry is brought in
  DEX
  BNE _update_controller_loop
  RTS

;; MOVE_SPRITE_16 Pointer, Direction, Amount
;; Moves the 16px by 16px sprite struct pointed to by Pointer in Direction by Amount
MOVE_SPRITE_16 .macro
  LDA #LOW(\1)
  STA ptr
  LDA #HIGH(\1)
  STA ptr+1
  LDA \3 ; Amount
  STA r0
  LDA #\2 ; Direction
  JSR _move_sprite_16
  .endm
_move_sprite_16:
  TAX
  AND #DIR_VERTICAL
  BEQ _move_sprite_16_prepare_hor
_move_sprite_16_prepare_vert:
  LDY #$00
  JMP _move_sprite_16_prepare_done
_move_sprite_16_prepare_hor:
  LDY #$03
_move_sprite_16_prepare_done:
  TXA
  LDX #$04
  AND #DIR_POSITIVE
  BEQ _move_sprite_16_negative
_move_sprite_16_positive:
  LDA [ptr], Y
  CLC
  ADC r0
  STA [ptr], Y
  INY
  INY
  INY
  INY
  DEX
  BNE _move_sprite_16_positive
  RTS
_move_sprite_16_negative:
  LDA [ptr], Y
  SEC
  SBC r0
  STA [ptr], Y
  INY
  INY
  INY
  INY
  DEX
  BNE _move_sprite_16_negative
  RTS

;; FLIPH_SPRITE_16 Pointer
;; Flips a 16px by 16px sprite struct pointed to by Pointer horizontally
FLIPH_SPRITE_16 .macro
  LDA #LOW(\1)
  STA ptr
  LDA #HIGH(\1)
  STA ptr+1
  JSR _fliph_sprite_16
  .endm
_fliph_sprite_16:
  ;EOR #SPRITE_FLIP_HORIZONTAL
  LDY #$01
  LDA [ptr], Y
  STA r0
  LDY #$05
  LDA [ptr], Y
  LDY #$01
  STA [ptr], Y
  LDA r0
  LDY #$05
  STA [ptr], Y

  LDY #$09
  LDA [ptr], Y
  STA r0
  LDY #$0D
  LDA [ptr], Y
  LDY #$09
  STA [ptr], Y
  LDA r0
  LDY #$0D
  STA [ptr], Y

  LDY #$02
  LDX #$04
fliph_sprite_16_loop:
  LDA [ptr], Y
  EOR #SPRITE_FLIP_HORIZONTAL
  STA [ptr], Y
  INY
  INY
  INY
  INY
  DEX
  BNE fliph_sprite_16_loop
  RTS


ADD_DEC_TO_DEC .macro
  LDY \2 ; Load decimal digit size
  BEQ _add_decimal_byte_done_\@ ; Cant add to 0 bytes
  PHA
  LDA #HIGH(\1)
  PHA
  LDA #LOW(\1)
  PHA
  LDA \3 ; Binary byte to add
  PHA
  JMP AddToDecimal
_add_decimal_byte_done_\@:
  RTS
  .endm

;; AdcDec
;; Acts like ADC but only operates on two decimal bytes guaranteed to be between 0-9.
;; Result is a decimal byte 0-9, with the carry bit indicating overflow
;;; <--
;; A = Augend in decimal
;; X = Addend in decimal
;;; ->
;; A = Sum
;; Sets Carry bit on oveflow
AdcDec:
  STX r0
  ADC r0
  CMP #$0A
  BCC _adc_dec_done ; done if result < 10
  ;; Handle overflow
  SEC ;; Prepare to sub
  SBC #$0A
  SEC ;; Indicate overflow
_adc_dec_done:
  RTS
