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
load_palette:
  LDA $2002 ; Change state to Choose Palette MSB
  LDA #$3F  ;...
  STA $2006 ; In Choose Palette state, write the high byte of the first palette addr
  LDA #$00  ;...
  STA $2006 ; In Choose Palette state, write the low byte of the first palette addr

;; Macro FILL_PALETTE:
;; \1: address of palette data
;; writes 16 sequential bytes from palette data to $2007
FILL_PALETTE .macro
    LDX #$00
  _loop_\@:
    LDA \1, x
    STA $2007
    INX
    CPX #$10
    BNE _loop_\@
  .endm

fill_bg_palette:
  FILL_PALETTE bg_palette_colors
fill_sprite_palette:
  FILL_PALETTE sprite_palette_colors

  LDA #%10000000 ; Enable vblank
  STA $2000     ; Store bitmask for PPUCTRL in memory-mapped region $2000

  LDA #%10010000 ; Enable sprites
  STA $2001     ; Store bitmask for PPUMASK in memory-mapped region $2001

sprite_data:
;;    Y-pos   Pattern   Attributes    X-pos
  .db $80,    $32,      %00000001,    $80
  .db $80,    $33,      %00000001,    $88
  .db $88,    $34,      %00000001,    $80
  .db $88,    $35,      %00000001,    $88

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
  .db $0F,$31,$32,$33,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F  ;background palette data
sprite_palette_colors:
  .db $0F,$1C,$15,$14,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C  ;sprite palette data
  ; code ...

  .org $FFFA ; IRQ table entry
  .dw NMI ; Non-maskable interrupt (ie VBLANK), jump to address at label NMI
  .dw RESET ; Processor turns on or reset button is pressed, jump to address at label RESET
  .dw 0 ; External interrupt. Ignore for now

  .bank 2 ; ineschr bank 1 - 8kb
  .org $0000
  .incbin "mario.chr" ; test data to fill the chr bank
