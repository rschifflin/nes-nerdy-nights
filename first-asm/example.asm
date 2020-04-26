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

  ;; PPU driver treats READ and WRITES as stateful signals
  ;; Magic words: $3F00 (first palette addr), $3F10 (second palette addr)
  ;; States:
  ;;  Choose Palette MSB State = CPM
  ;;  Choose Palette LSB State = CPL
  ;;  Input Ready Byte N = IR<N>
  ;; OP     | ADDR  | FROM  | EFFECT          | TO
  ;;-------------------------------------------------------------------------
  ;; READ   | $2002 | <Any> | Prepare Set Ops | CPM
  ;; WRITE  | $2006 | CPM   | Set palette MSB | CPL
  ;;                | CPL   | Set palette LSB | IR1
  ;; WRITE  | $2007 | IR1   | Set Color 1     | IR2
  ;;                | IR<N> | Set Color N     | IR<N+1>
  ;;                | IR16  | Set Color 16    | End State
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

;; Sprite Data format is specified in 4-byte structs:
;;   byte0: Y-pos from top of screen, #$00 - #$EF (0-239)
;;   byte1: Tile index from pattern table, #$00 - #$FF (0-255)
;;   byte2: Attribute bitmask
;;      7 6 5 4 3 2 1 0
;;     |x| | | | | | | | Flip sprite vertically
;;     | |x| | | | | | | Flip sprite horizontally
;;     | | |x| | | | | | Priority: 0 = In front of bg, 1 = behind bg
;;     | | | |x| | | | | unknown
;;     | | | | |x| | | | unknown
;;     | | | | | |x| | | unknown
;;     | | | | | | |x|x| 2-bit palette index to choose which 4-color palette
;;   byte3: X-pos from left of screen, #$00 - #$F9 (0-249)

;; PPUCTRL bitmask (Memory mapped to $2000)
;;    7 6 5 4 3 2 1 0
;;   |x| | | | | | | | Enable vblank NMI: 0 = false, 1 = true
;;   | |x| | | | | | | unknown
;;   | | |x| | | | | | Sprite size: 0 = 8x8, 1 = 8x16
;;   | | | |x| | | | | BG pattern table addr: 0 = $0000, 1 = $1000
;;   | | | | |x| | | | Sprite pattern table addr: 0 = $0000, 1 = $1000
;;   | | | | | |x| | | VRAM address increment per CPU access: 0 = inc1, 1 = inc32
;;   | | | | | | |x|x| 2-bit base nametable address

  LDA #$80
  STA $0200        ; place in center ($80) of y-axis
  STA $0203        ; place in center ($80) of x-axis
  LDA #$00
  STA $0201        ; sprite pattern 0
  LDA #$01
  STA $0202        ; In front of bg, no flip, colorset 1

  LDA #%10000000 ; Enable vblank
  STA $2000     ; Store bitmask for PPUCTRL in memory-mapped region $2000
  LDA #%10010000 ; Intensify color, Enable sprites
  STA $2001     ; Store bitmask for PPUMASK in memory-mapped region $2001

  LDX #$00
  LDY #$00
  STX $0203
loop:
  ;; Count x from 0 to 255. For each full x-cycle, count y from 0 to 15. For each full y-cycle, scroll the sprite
  ;; End result: Scroll the sprite every 256 * 16 = 2^8*2^4 = 2^12 = 4096 iterations
  INX ; Count from 0 to 255...
  CPX #$00 ; Every 256 frames...
  BNE loop
  INY ; Count from 0 to 15...
  CPY #$10
  BNE loop ; Every 16 frames
  LDY #$00 ; Reset the 0-16 counter (the 0-255 counter rolls over naturally)
  INC $0203 ; Scroll sprite0's x-pos by 1
  JMP loop

NMI: ; Non-maskable interrupt, in our case VBLANK
     ; PPU updates (DMA transfers for ex) can ONLY be done during the vblank period so must be signalled by NMI
  INC $0200 ; Scroll sprite0's y-pos by 1 every frame

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
