  .include "constants.asm"
  .rsset $0000 ; Start generating variables at 0x00 IS IT SAFE??
ptr .rs 2 ; Base pointer used for indirection
r1 .rs 1 ; Simple re-usable byte register for subroutines
frame_counter .rs 1  ; Alloc 1 byte for the frame counter
current_frame .rs 1  ; Alloc 1 byte for the current frame
controller     .rs 1 ; Holds bitmask of controller state

  .rsset $0200
mario_sprite .rs 256 ; Holds 256 bytes, or 64 4-byte sprite structs, for DMA

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
  .include "lib.asm"

main:
;;;; INIT
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
  STA PPUCTRL    ; Store bitmask for PPUCTRL in memory-mapped region $2000

  LDA #%00011110 ; Enable sprites, enable background
  STA PPUMASK    ; Store bitmask for PPUMASK in memory-mapped region $2001

  LDA #$00
  STA PPUSCROLL ; Disable horizontal scrolling after NMI
  STA PPUSCROLL ; Disable vertical scrolling after NMI

  LDX #$00
sprite_load_loop:
  LDA sprite_data, x
  STA mario_sprite, x
  INX
  CPX #$10
  BNE sprite_load_loop
;;;;


;;;; RUN
  LDA #$00
  STA frame_counter
  STA current_frame
run:
  ;; Handle per-frame logic
  LDA frame_counter ;; Frame counter
  CMP current_frame ;; Current Frame
  BEQ run ;; Loop if we've handled this frame already
  STA current_frame ;; Mark current frame as handled
  JSR MoveMario
  JMP run
;;;;

NMI: ; Non-maskable interrupt, in our case signalling start of VBLANK
     ; PPU updates (DMA transfers for ex) can ONLY be done during the vblank period so must be signalled by NMI
  PUSH_STATE ; Protect in-progress flags/registers from getting clobbered by NMI
  INC frame_counter
  PPU_DMA mario_sprite ; DMA copy sprite data
  JSR UpdateController ; Read controller input
  POP_STATE ; Restore in-progress flags/registers
  RTI ; Return from interrupt

  .bank 1 ; inesprg bank 2 - 8kb
  .org $E000
palette:
  .include "palette.asm"

name_table:
  .include "name_table.asm"

attribute_table:
  .include "attr_table.asm"

sprites:
  .include "sprites.asm"
  ; remaining bank 1 code ...

  .org INTERRUPT_VECTOR_TABLE
  .dw NMI   ; Non-maskable interrupt (ie VBLANK)
  .dw RESET ; Processor turns on or reset button is pressed
  .dw 0     ; Other interrupts. Ignore for now

  .bank 2 ; ineschr bank 1 - 8kb
  .org $0000
  .incbin "mario.chr" ; test data to fill the chr bank
