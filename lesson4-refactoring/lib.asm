;;;; SUBROUTINES AND MACROS
PUSH_STATE .macro
  PHA ; Push A
  TXA ; X->A
  PHA ; Push X
  TYA ; Y->A
  PHA ; Push Y
  PHP ; Push flags
  .endm

POP_STATE .macro
  PLP ; Pull flags
  PLA ; Pull Y
  TAY ; A->Y
  PLA ; Pull X
  TAX ; A->X
  PLA ; Pull A
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
  STY r1
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

;; During the lo loop, Y keeps the index and counts up to the target stored in r1.
;; After r1 iterations, we finish
_write_ppu_bytes_loop_lo:
  CPY r1
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
  ;; signal controllers for reading
  LDA #$00
  STA CONTROLLER_STATUS
  LDA #$01
  STA CONTROLLER_STATUS
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
  STA r1
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
  LDX #$00
  AND #DIR_POSITIVE
  BEQ _move_sprite_16_negative
_move_sprite_16_positive:
  LDA [ptr], Y
  CLC
  ADC r1
  STA [ptr], Y
  INY
  INY
  INY
  INY
  INX
  CPX #$04
  BNE _move_sprite_16_positive
  RTS
_move_sprite_16_negative:
  LDA [ptr], Y
  SEC
  SBC r1
  STA [ptr], Y
  INY
  INY
  INY
  INY
  INX
  CPX #$04
  BNE _move_sprite_16_negative
  RTS

MoveMario:
  LDA #CONTROLLER_P1_UP
  AND controller
  BEQ _move_mario_up_done
  MOVE_SPRITE_16 mario_sprite, DIR_UP, #$02
_move_mario_up_done:
  LDA #CONTROLLER_P1_DOWN
  AND controller
  BEQ _move_mario_down_done
  MOVE_SPRITE_16 mario_sprite, DIR_DOWN, #$02
_move_mario_down_done:
  LDA #CONTROLLER_P1_LEFT
  AND controller
  BEQ _move_mario_left_done
  MOVE_SPRITE_16 mario_sprite, DIR_LEFT, #$02
_move_mario_left_done:
  LDA #CONTROLLER_P1_RIGHT
  AND controller
  BEQ _move_mario_done
  MOVE_SPRITE_16 mario_sprite, DIR_RIGHT, #$02
_move_mario_done:
  RTS
