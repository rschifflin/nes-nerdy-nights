  .include "constants.asm"
  .rsset $0000 ; Start generating variables at 0x00 IS IT SAFE??
ptr           .rs 2 ; Base pointer used for indirection
r1            .rs 1 ; Simple re-usable byte register for subroutines

state         .rs 1 ; Holds the game state
frame_counter .rs 1 ; Alloc 1 byte for the frame counter
current_frame .rs 1 ; Alloc 1 byte for the current frame
controller    .rs 1 ; Holds bitmask of controller state


  .rsset SPRITE_AREA ; For sprite DMA
ball          .rs 16 ; Holds 4 4-byte sprite structs
player_paddle .rs 64 ; Holds 16 4-byte sprite structs
ai_paddle     .rs 64 ; Holds 16 4-byte sprite structs

  .inesprg 1 ; 1x 16kb bank of PRG code
  .ineschr 1 ; 1x 8kb bank of CHR code
  .inesmap 0 ; mapper=0, NROM aka no bank swapping
  .inesmir 1 ; background mirroring (ignore for now)

  .bank 0 ; inesprg bank 1 - 8kb
  .org $C000

  .include "lib.asm"
  .include "lib_pong.asm"

RESET:
  SEI     ; Disable IRQs
  CLD     ; disable decimal mode

  ; Disable audio frame counter interrupts
  LDX #%01000000
  STX APUFC

  ; Set up stack pointer at 0xFF ie immediately following the zeropage
  ; This leaves zeropage region 0x00-0xFF
  LDX #$FF
  TXS

  INX       ; X goes from FF -> 00
  STX PPUCTRL ; Write all 0s- disables NMI
  STX PPUMASK ; Write all 0s- disables rendering
  STX APUCTRL ; Write all 0s- disables audio interrupts
  JSR WaitVblank ; Wait for PPU to vblank... why?

  LDX #$00 ; Not strictly necessary as X should still be 0, but dont want changes to the prev JSR to clobber x
init_clear_mem:
  LDA #$00
  STA $0000, x ;; 0x0000-0x00FF get set to 0. Note this also initializes all our variables in the zeropage to 0 (frame counter, game state, etc)
  STA $0100, x ;; 0x0100-0x01FF get set to 0
  STA $0300, x ;; etc
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x

  LDA #$FE
  STA $0200, x ;; 0x0200 - 0x2FF get set to $FE; note this is the DMA area
  INX
  BNE init_clear_mem

  LDX #$00 ; Not strictly necessary as X should still be 0, but dont want changes to the prev JSR to clobber x
init_fill_mem: ; This memory gets DMA'd by the PPU during the NMI handler so should be filled before we enable NMI
  LDA sprite_data, x
  STA SPRITE_AREA, x
  INX
  CPX #$90 ; 144 bytes
  BNE init_fill_mem

  JSR WaitVblank ; We performed many operations.. we should wait for vblank again

  SET_PPU_ADDRESS $2000 ; name table starts at PPU address $2000
  WRITE_PPU_BYTES name_table, $03C0 ; Copy 960 bytes

  SET_PPU_ADDRESS $23C0 ; attr table starts at PPU address $23C0
  WRITE_PPU_BYTES attribute_table, $0100 ; Copy 256 bytes

  SET_PPU_ADDRESS $3F00 ; palettes start at PPU address $3F00
  WRITE_PPU_BYTES bg_palette_colors, $10 ; Copy 16 bytes
  WRITE_PPU_BYTES sprite_palette_colors, $10 ; Copy 16 bytes

  LDA #%10011000 ; Enable vblank NMI, sprites from pattern table 1, bg from pattern table 1
  STA PPUCTRL    ; Store bitmask for PPUCTRL in memory-mapped region $2000

  LDA #%00011110 ; Enable sprites, enable background
  STA PPUMASK    ; Store bitmask for PPUMASK in memory-mapped region $2001

  LDA #$00
  STA PPUSCROLL ; Disable horizontal scrolling after NMI
  STA PPUSCROLL ; Disable vertical scrolling after NMI

wait_nmi:
  LDA frame_counter
  BEQ wait_nmi

run:
  ;; Handle per-frame logic
  LDA frame_counter ;; Frame counter
  CMP current_frame ;; Current Frame
  BEQ run ;; Loop if we've handled this frame already
  STA current_frame ;; Mark current frame as handled

  LDA #STATE_ACTION
  CMP state
  BEQ run_action

  LDA #STATE_TITLE
  CMP state
  BEQ run_title

run_action:
  JSR MoveAiPaddle
  JSR MovePlayerPaddle
  JSR MoveBall
  JMP run

run_title:
  LDA controller
  AND #CONTROLLER_P1_START
  BEQ run_title_done
  LDA #STATE_ACTION
  STA state
run_title_done:
  JMP run
;;;;

NMI: ; Non-maskable interrupt, in our case signalling start of VBLANK
     ; PPU updates (DMA transfers for ex) can ONLY be done during the vblank period so must be signalled by NMI
  PUSH_STATE ; Protect in-progress flags/registers from getting clobbered by NMI
  INC frame_counter
  PPU_DMA SPRITE_AREA ; DMA copy sprite data
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
