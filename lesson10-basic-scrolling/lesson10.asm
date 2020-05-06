.include "data/header.asm"
.include "data/constants.asm"

.segment "ZEROPAGE" ; premium real estate for global variables

;;;; Memory registers.
;; Interrupts should preserve these values to stay re-entrant
;; Like A,X and Y, may be clobbered by JSR.
ptr:           .res 2 ; Base pointer used for indirection
r0:            .res 1 ; Simple re-usable byte register
;;;;

;;;; Global system variables.
;; Should not be modified by general-purpose library code
chr_bank:      .res 1  ;; Keeps track of our CHR bank, up to 16 for 8kb banks or 32 for 4kb banks
prg_bank:      .res 1  ;; Keeps track of our PRG bank, up to 8 for 32kb banks or 16 for 16kb banks
p1_controller: .res 1  ;; Holds bitmask of controller state
p2_controller: .res 1  ;; Holds bitmask of controller state

scroll_x:      .res 1  ;; Holds horizontal scroll position
scroll_y:      .res 1  ;; Holds vertical scroll position
scroll_dx:     .res 1  ;; Holds horizontal scroll delta
scroll_dy:     .res 1  ;; Holds vertical scroll delta

sysflags:      .res 1 ;; For miscellaneous flags
                      ;; bit 0: whether or not the horizontal banks are swapped. 0 = normal order, 1 = swapped order
;;;;

;;;; ZP program variables
state:         .res 1
frame_counter: .res 1
current_frame: .res 1
;;;;

.segment "BSS" ; Rest of RAM, $0200-$07FF. First 255 bytes are sprite DMA. Rest are free to use

.segment "PRG1" ;; Fixed PRG ROM. Always present
.include "lib/nes.asm"  ;; System subroutines and macros. Should always remain banked in.
.include "lib/mmc1.asm" ;; Subroutines specific to the MMC1 memory mapper. Should always remain banked in.
.include "lib/draw.asm" ;; Subroutines for drawing used during NMI. Should always remain banked in.

RESET:
  SEI     ;; Disable IRQs
  CLD     ;; Disable decimal mode (NES 6502s dont have a decimal mode)

  ;; Disable audio frame counter interrupts
  LDX #%01000000
  STX APUFC

  ;;;; Set up stack
  ;; Stack begins at $0100, stack pointer is an offset which shrinks on push.
  ;; Effective address of empty stack is $01FF
  ;; Effective address of full stack is $0100
  ;; We write all 0s to the stack, then set the stack pointer to $FF
  LDA #$00
  TAX
clear_stack:
  STA $0100, x
  INX
  BNE clear_stack
  DEX ;; X -> $FF
  TXS ;; Set stack pointer to $FF
  ;;;;

  INX             ;; X -> $00
  STX PPUCTRL     ;; Write all 0s- disables NMI
  STX PPUMASK     ;; Write all 0s- disables rendering
  STX APUCTRL     ;; Write all 0s- disables audio interrupts

  ;; Wait for PPU to vblank. PPU hw is warming up
  JSR WaitVblank

  ;; Sets up the MMC1 mapper: 8kb char banks, 16kb prg banks at $8000, vertical mirroring
  JSR ConfigureMapper

  ;; Write 0s to RAM $0000 - $07FF, excluding stack area $0100-$01FF already handled
  ;; Write default values to the sprite DMA area
  JSR InitMemory

  ;; Wait for PPU to vblank. PPU hw finishing warming up
  JSR WaitVblank

  ;; name table 0 starts at PPU address $2000
  SET_PPU_ADDRESS $2000
  WRITE_PPU_BYTES name_table, $03C0 ;; Copy 960 bytes
  ;; attr table starts right after at PPU address $23C0
  WRITE_PPU_BYTES attr_table0, $0040 ;; Copy 64 bytes

  ;; name table 1 starts at PPU address $2400
  SET_PPU_ADDRESS $2400
  WRITE_PPU_BYTES name_table, $03C0 ;; Copy 960 bytes
  ;; attr table starts right after at PPU address $23C0
  WRITE_PPU_BYTES attr_table1, $0040 ;; Copy 64 bytes

  ;; palettes start at PPU address $3F00
  SET_PPU_ADDRESS $3F00
  WRITE_PPU_BYTES bg_palette_colors, $10     ;; Copy 16 bytes
  WRITE_PPU_BYTES sprite_palette_colors, $10 ;; Copy 16 bytes

  ;;;; Configure PPU
  ;; Enable vblank NMI, sprites from CHR0, bg from CHR1 via PPUCTRL
  ;; Enable sprites, enable background via PPUMASK
  ;; Set horizontal scroll and vertical scroll offsets to 0
  LDA #%10011000
  STA PPUCTRL
  LDA #%00011110
  STA PPUMASK
  LDA #$00
  STA PPUSCROLL
  STA PPUSCROLL
  ;;;;

;; Reset finished; wait for initial NMI which will mark the first frame
wait_nmi:
  LDA frame_counter
  BEQ wait_nmi
  JMP run
;;;;

;;;; NMI
;; Non-maskable interrupt, on the NES this signals start of VBLANK
;; PPU updates (DMA transfers for ex.) can ONLY be done during the VBLANK period so must be handled here
NMI:
  ;; Protect in-progress flags/registers from getting clobbered by NMI
  PUSH_IRQ

  ;; DMA copy sprite data. This data should be prepared in advance prior to the NMI
  PPU_DMA SPRITE_AREA

  ;; Perform drawing here, ie writes to the PPU nametables to set patterns and attributes
  ;; JSR DrawStart
  ;; JSR DrawTime
  ;; JSR DrawScore
  ;; JSR DrawWinner

  ;; Perform scrolling here (setting both h/v scroll offsets to 0)
  .scope scroll_x
      LDA scroll_dx
      CLC
      ADC scroll_x
      STA scroll_x
      BCC done

      ;; Scrolled past the end- swap horizontal banks
      LDA sysflags
      EOR #SYSFLAG_SCROLL_X_ORDER
      STA sysflags
    done:
      LDA #$00
      STA scroll_dx
  .endscope
  .scope scroll_y
      LDA #$00
      STA scroll_dy
  .endscope

  LDA $00
  STA PPUADDR
  STA PPUADDR
  LDA scroll_x
  STA PPUSCROLL
  LDA scroll_y
  STA PPUSCROLL

  LDA sysflags
  AND #SYSFLAG_SCROLL_X_ORDER
  ORA #%10011000
  STA PPUCTRL
  LDA #%00011110
  STA PPUMASK

  ;; Advance program frame
  INC frame_counter

  ;; Restore in-progress flags/registers
  POP_IRQ

  RTI

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

.segment "PRG0" ;; Default bank-swapped PRG ROM at $8000.
JMP RESET ;; Entry point on program start

.include "lib/game.asm"

run:
  ;; Handle per-frame logic
  ;; Loop if we've handled this frame already
  LDA frame_counter
  CMP current_frame
  BEQ run
  STA current_frame

  ;; Read controller input
  JSR UpdateController

  ;;;; Enter state machine
  ;; Ex:
  ;; LDA #STATE_1
  ;; AND state
  ;; BNE run_state_1
  ;;
  ;; LDA #STATE_2
  ;; AND state
  ;; BNE run_state_1
  ;; ...
  ;;;;

  .scope scroll
      LDA p1_controller
      AND #CONTROLLER_RIGHT
      BEQ done
      LDA #$01
      STA scroll_dx
    done:
  .endscope

  JMP run

.segment "CHR0" ; 8kb, always present
  .incbin "assets/mario.chr" ; test data to fill the chr bank

.segment "CHR1" ; 8kb bank-switched
  .incbin "assets/mario_flip.chr" ; test data to fill the chr bank
