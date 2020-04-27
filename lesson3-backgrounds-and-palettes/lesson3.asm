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
;      STX $2000 ; Write 0 to memory-mapped region 2000 to disable NMI
;      STX $2001 ; Write 00000000 bitmask to PPU memory mapped region 2001
;      STX $4010 ; Write 0 to memory-mapped region 4010 to disable DMC IRQs

;    vblankwait1:
;      BIT $2002
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
;      BIT $2002
;      BPL vblankwait2
;;; BACK TO THE REALM OF THE EXPLAINED...

LOAD_PPU .macro
    LDX #$00
  _loop_\@:
    LDA \1, x
    STA $2007
    INX
    CPX \2
    BNE _loop_\@
  .endm

load_name_table:
  LDA $2002 ; Change state to Choose Address MSB
  LDA #$20  ;...
  STA $2006 ; In Choose Address state, write the high byte of the name table addr
  LDA #$00  ;...
  STA $2006 ; In Choose Address state, write the low byte of the name table addr

  LOAD_PPU name_table_1, #$00
  LOAD_PPU name_table_2, #$00
  LOAD_PPU name_table_3, #$00
  LOAD_PPU name_table_4, #$C0

load_attr_table:
  LDA $2002 ; Change state to Choose Address MSB
  LDA #$23  ;...
  STA $2006 ; In Choose Address state, write the high byte of the attr table addr
  LDA #$C0  ;...
  STA $2006 ; In Choose Address state, write the low byte of the attr table addr
  LOAD_PPU attribute_table, #$00 ; The screen is only 30 tiles tall, but the attr table covers 4 vertical tiles per byte, so must overshoot by 2

load_palettes:
  LDA $2002 ; Change state to Choose Address MSB
  LDA #$3F  ;...
  STA $2006 ; In Choose Address state, write the high byte of the first palette addr
  LDA #$00  ;...
  STA $2006 ; In Choose Address state, write the low byte of the first palette addr
  LOAD_PPU bg_palette_colors, #$10
  LOAD_PPU sprite_palette_colors, #$10

  LDA #%10010000 ; Enable vblank, sprites from pattern table 0, bg from pattern table 1
  STA $2000      ; Store bitmask for PPUCTRL in memory-mapped region $2000

  LDA #%00011110 ; Enable sprites, enable background
  STA $2001      ; Store bitmask for PPUMASK in memory-mapped region $2001

  LDA #$00
  STA $2005 ; Disable scrolling after NMI
  STA $2005 ; continue disabling scrolling after NMI

  LDX #$00
sprite_load_loop:
  LDA sprite_data, x
  STA $0200, x
  INX
  CPX #$10
  BNE sprite_load_loop

  ;; Use 0404 for frame counter, 0405 for current frame
  LDA #$00
  STA $0404
  STA $0405
game_loop:

  ;; Handle per-frame logic like controller checking
  LDA $0404 ;; Frame counter
  CMP $0405 ;; Current Frame
  BEQ game_loop ;; Loop if we've handled this frame already
  STA $0405 ;; Mark current frame as handled

  ;; signal controllers for reading
  LDA #$00
  STA $4016
  LDA #$01
  STA $4016

  LDA $4016 ; Ignore A
  LDA $4016 ; Ignore B
  LDA $4016 ; Ignore Select
  LDA $4016 ; Ignore Start

  LDA $4016 ; Check UP
  AND #$01
  BEQ controller_p1_up_done ; skip if unpressed
  DEC $0200
  DEC $0204
  DEC $0208
  DEC $020C
controller_p1_up_done:
  LDA $4016 ; Check DOWN
  AND #$01
  BEQ controller_p1_down_done ; skip if unpressed
  INC $0200
  INC $0204
  INC $0208
  INC $020C
controller_p1_down_done:
  LDA $4016 ; Check LEFT
  AND #$01
  BEQ controller_p1_left_done ; skip if unpressed
  DEC $0203
  DEC $0207
  DEC $020B
  DEC $020F
controller_p1_left_done:
  LDA $4016 ; Check RIGHT
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
  INC $0404 ; Increment frame counter
  LDA #$00
  STA $2003 ; Tell PPU the low byte of a memory region for DMA
  LDA #$02
  STA $4014 ; Tell PPU the high byte of a memory region for DMA, then begin DMA
            ; This fills the PPU sprite memory with the data to blit the screen for the next draw
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
