.include "data/header.asm"
.include "data/constants.asm"

.segment "ZEROPAGE" ; premium real estate for global variables
ptr:           .res 2 ; Base pointer used for indirection
r0:            .res 1 ; Simple re-usable byte register for subroutines

state:         .res 1 ; Holds the game state
frame_counter: .res 1 ; Alloc 1 byte for the frame counter
current_frame: .res 1 ; Alloc 1 byte for the current frame
p1_controller: .res 1 ; Holds bitmask of controller state
p2_controller: .res 1 ; Holds bitmask of controller state

p1_score:      .res 2 ; Kept as decimal digits
p2_score:      .res 2 ; Kept as decimal digits
time:          .res 4 ; Kept as 4 decimal digits

bank:          .res 0 ; Keeps track of our CHR bank, 0 or 1

.segment "BSS" ; Rest of RAM. First 255 bytes are stack. Next 255 are sprite DMA. Rest are free to use
ball:          .res 16 ; Holds 4 4-byte sprite structs
p1_paddle:     .res 64 ; Holds 16 4-byte sprite structs
p2_paddle:     .res 64 ; Holds 16 4-byte sprite structs

.segment "PRG1" ;; Fixed PRG ROM. Always present
.include "lib/nes.asm"
.include "lib/mmc1.asm"
.include "lib/draw.asm"

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

  ; Clear the memory map shift register
  JSR ConfigureMapper

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
  STA SPRITE_AREA, x ;; 0x0200 - 0x2FF get set to $FE; note this is the DMA area
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
                        ; attr table starts at PPU address $23C0
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
  JMP run

;;;;

NMI: ; Non-maskable interrupt, in our case signalling start of VBLANK
     ; PPU updates (DMA transfers for ex) can ONLY be done during the vblank period so must be signalled by NMI
  PUSH_IRQ; Protect in-progress flags/registers from getting clobbered by NMI
  INC frame_counter
  PPU_DMA SPRITE_AREA ; DMA copy sprite data
  JSR DrawStart
  JSR DrawTime
  JSR DrawScore
  JSR DrawWinner

  LDA #$00
  STA PPUSCROLL ; Disable horizontal scrolling after NMI always
  STA PPUSCROLL ; Disable vertical scrolling after NMI always
  POP_IRQ; Restore in-progress flags/registers
  RTI ; Return from interrupt

palette:
  .include "data/palette.asm"

name_table:
  .include "data/name_table.asm"

attribute_table:
  .include "data/attr_table.asm"

sprites:
  .include "data/sprites.asm"

strings:
  .include "data/strings.asm"

.segment "IVT"
  .addr NMI   ; Non-maskable interrupt (ie VBLANK)
  .addr RESET ; Processor turns on or reset button is pressed
  .word 0 ; Other interrupts. Ignore for now

.segment "PRG0" ;; Bank-swapped PRG ROM. This can be swapped out
.include "lib/pong.asm"

JMP RESET
run:
  ;; Handle per-frame logic
  LDA frame_counter ;; Frame counter
  CMP current_frame ;; Current Frame
  BEQ run ;; Loop if we've handled this frame already
  STA current_frame ;; Mark current frame as handled
  JSR UpdateController ; Read controller input

  LDA #STATE_ACTION
  AND state
  BNE run_action

  LDA #STATE_P1_WIN
  ORA #STATE_P2_WIN
  AND state
  BNE run_win
  JMP run_title

run_action:
.scope run_action
    LDA current_frame
    AND #%00011111 ;; Tick every frame
    BNE done
    INCREMENT_TIME
  done:
    MOVE_PADDLE p1_paddle, p1_controller
    MOVE_PADDLE p2_paddle, p2_controller
    JSR MoveBall
    JMP run
.endscope

run_title:
.scope run_title
    LDA p1_controller
    AND #CONTROLLER_START
    BEQ done
    LDA #STATE_ACTION
    STA state
  done:
    JMP run
.endscope

run_win:
.scope run_win
    LDA p1_controller
    AND #CONTROLLER_START
    BEQ done
    LDA #$00
    STA p1_score
    STA p1_score+1
    STA p2_score
    STA p2_score+1
    STA time
    STA time+1
    STA time+2
    STA time+3

    ;; Resets state, preserving flags
    LDA state
    AND #STATE_MASK_FLAGS
    ORA #STATE_ACTION
    STA state
  done:
    JMP run
.endscope

.segment "CHR0" ; 8kb
  .incbin "assets/mario.chr" ; test data to fill the chr bank

.segment "CHR1" ; 8kb bank-switched
  .incbin "assets/mario_flip.chr" ; test data to fill the chr bank
