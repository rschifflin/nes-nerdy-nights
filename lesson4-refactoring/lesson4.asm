  .include "constants.asm"
  .rsset $0000 ; Start generating variables at address $00
ptr .rs 1 ; Base pointer used for indirection
ptrHi .rs 1 ; Base pointer used for indirection
r1 .rs 1 ; Simple re-usable byte register for subroutines
r2 .rs 1 ; Simple re-usable byte register for subroutines

  .inesprg 1 ; 1x 16kb bank of PRG code
  .ineschr 1 ; 1x 8kb bank of CHR code
  .inesmap 0 ; mapper=0, NROM aka no bank swapping
  .inesmir 1 ; background mirroring (ignore for now)

  .bank 0 ; inesprg bank 1 - 8kb
  .org $C000

RESET:
  SEI     ; Disable IRQs
  CLD     ; disable decimal mode
;;; UNEXPLAINED MAGIC...
;      LDX #$40  ; X <- 0x40
;      STX $4017 ; X -> $4017
;      LDX #$FF  ; X <- 0xFF
;      TXS       ; Set up stack ?
;      INX       ; X++ (From 0xFF to 0x00)
;      STX PPUCTRL ; Write 0 to memory-mapped region 2000 to disable NMI
;      STX PPUMASK ; Write 00000000 bitmask to PPU memory mapped region 2001
;      STX $4010 ; Write 0 to memory-mapped region 4010 to disable DMC IRQs

;    vblankwait1:
;      BIT PPUSTATUS
;      BPL vblankwait1

;    clrmem:
;      LDA #$00
;      STA $0000, x
;      STA $0100, x
;      STA $0200, x
;      STA $0400, x
;      STA $0500, x
;      STA $0600, x
;      STA $0700, x
;      LDA #$FE
;      STA $0300, x
;      INX
;      BNE clrmem

;    vblankwait2:
;      BIT PPUSTATUS
;      BPL vblankwait2
;;; BACK TO THE REALM OF THE EXPLAINED...

  JMP main; Keep the area of PRG between here and main for subroutines

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
  STA ptrHi
  STY r1
  LDY #$00

;; We iterate using a 2-byte counter. Breaking the counter into Hi and Lo bytes, we iterate 256*Hi + Lo times.

;; X keeps the index of the hi loop and counts down
;; When X is 0, we've finished counting the hi byte and we enter the lo loop
;; When X is nonzero, we enter the hi inner loop
_write_ppu_bytes_loop_hi:
  CPX #$00
  BNE _write_ppu_bytes_loop_hi_inner
  LDY #$00
  JMP _write_ppu_bytes_loop_lo

;; Y keeps the index of the hi inner loop. The inner loop always iterates 256 times.
;; During this loop, the base pointer is not modified and Y is used to offset the base pointer.
;; After the 256th iteration, we decrement X, modify the base pointer by 256 to keep our place, and return to the outer loop
_write_ppu_bytes_loop_hi_inner:
  LDA [ptr],Y
  STA PPUDATA ; Write byte to ppu
  INY
  CPY #$00
  BNE _write_ppu_bytes_loop_hi_inner
  INC ptrHi
  DEX
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

;;;; MAIN

main:
load_name_table:
  SET_PPU_ADDRESS $2000 ; name table starts at $2000
  WRITE_PPU_BYTES name_table, $03C0 ; Copy 960 bytes

load_attr_table:
  SET_PPU_ADDRESS $23C0 ; attr table starts at $23C0
  WRITE_PPU_BYTES attribute_table, $0100 ; Copy 256 bytes

load_palettes:
  SET_PPU_ADDRESS $3F00 ; palettes start at $3F00
  WRITE_PPU_BYTES bg_palette_colors, $10 ; Copy 16 bytes
  WRITE_PPU_BYTES sprite_palette_colors, $10 ; Copy 16 bytes

  LDA #%10010000 ; Enable vblank, sprites from pattern table 0, bg from pattern table 1
  STA PPUCTRL      ; Store bitmask for PPUCTRL in memory-mapped region $2000

  LDA #%00011110 ; Enable sprites, enable background
  STA PPUMASK    ; Store bitmask for PPUMASK in memory-mapped region $2001

  LDA #$00
  STA PPUSCROLL ; Disable horizontal scrolling after NMI
  STA PPUSCROLL ; Disable vertical scrolling after NMI

  LDX #$00
sprite_load_loop:
  LDA sprite_data, x
  STA $0200, x
  INX
  CPX #$10
  BNE sprite_load_loop

frame_counter .rs 1 ; Alloc 1 byte for the frame counter
current_frame .rs 1 ; Alloc 1 byte for the current frame
  LDA #$00
  STA frame_counter
  STA current_frame
game_loop:

  ;; Handle per-frame logic
  LDA frame_counter ;; Frame counter
  CMP current_frame ;; Current Frame
  BEQ game_loop ;; Loop if we've handled this frame already
  STA current_frame ;; Mark current frame as handled

  ;; signal controllers for reading
  LDA #$00
  STA CONTROLLER_STATUS
  LDA #$01
  STA CONTROLLER_STATUS

  LDA CONTROLLER_P1 ; Ignore A
  LDA CONTROLLER_P1 ; Ignore B
  LDA CONTROLLER_P1 ; Ignore Select
  LDA CONTROLLER_P1 ; Ignore Start

  LDA CONTROLLER_P1 ; Check UP
  AND #$01
  BEQ controller_p1_up_done ; skip if unpressed
  DEC $0200
  DEC $0204
  DEC $0208
  DEC $020C
controller_p1_up_done:
  LDA CONTROLLER_P1 ; Check DOWN
  AND #$01
  BEQ controller_p1_down_done ; skip if unpressed
  INC $0200
  INC $0204
  INC $0208
  INC $020C
controller_p1_down_done:
  LDA CONTROLLER_P1 ; Check LEFT
  AND #$01
  BEQ controller_p1_left_done ; skip if unpressed
  DEC $0203
  DEC $0207
  DEC $020B
  DEC $020F
controller_p1_left_done:
  LDA CONTROLLER_P1 ; Check RIGHT
  AND #$01
  BEQ controller_p1_right_done ; skip if unpressed
  INC $0203
  INC $0207
  INC $020B
  INC $020F
controller_p1_right_done:
  JMP game_loop

NMI: ; Non-maskable interrupt, in our case VBLANK
     ; PPU updates (DMA transfers for ex) can ONLY be done during the vblank period so must be signalled by NMI
  PUSH_STATE

  INC frame_counter ; Increment frame counter
  LDA #$00
  STA OAMADDR ; Tell PPU the low byte of a memory region for DMA
  LDA #$02
  STA OAMDMA ; Tell PPU the high byte of a memory region for DMA, then begin DMA
            ; This fills the PPU sprite memory with the data to blit the screen for the next draw

  POP_STATE
  RTI ; Return from interrupt

  .bank 1 ; inesprg bank 2 - 8kb
  .org $E000
bg_palette_colors:
  .db $22,$29,$1A,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F   ;;background palette

sprite_palette_colors:
  .db $22,$1C,$15,$14,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $22,$02,$38,$3C   ;;sprite palette

name_table:
  .include "name_table.asm"

attribute_table:
  .include "attr_table.asm"

sprite_data:
;;    Y-pos   Pattern   Attributes  X-pos
  .db $80,    $32,      $00,        $80
  .db $80,    $33,      $00,        $88
  .db $88,    $34,      $00,        $80
  .db $88,    $35,      $00,        $88

  ; code ...

  .org $FFFA ; IRQ table entry
  .dw NMI ; Non-maskable interrupt (ie VBLANK), jump to address at label NMI
  .dw RESET ; Processor turns on or reset button is pressed, jump to address at label RESET
  .dw 0 ; External interrupt. Ignore for now

  .bank 2 ; ineschr bank 1 - 8kb
  .org $0000
  .incbin "mario.chr" ; test data to fill the chr bank
