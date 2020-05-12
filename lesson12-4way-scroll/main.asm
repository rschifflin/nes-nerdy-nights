.include "data/header.asm"
.include "data/constants.asm"

.segment "ZEROPAGE" ; premium real estate for global variables

;;;; Memory registers.
;; Interrupts should preserve these values to stay re-entrant
;; Like A,X and Y, may be clobbered by JSR.
SP:            .res 1 ; Software stack pointer
PLO:           .res 1 ; pointer reg used for indirection
PHI:           .res 1 ; pointer reg used for indirection
;;
r0:            .res 1 ; Simple re-usable byte register
r1:            .res 1 ; Simple re-usable byte register
;;;;

;;;; Global system variables.
;; Should not be modified by general-purpose library code
chr_bank:      .res 1  ;; Keeps track of our CHR bank, up to 16 for 8kb banks or 32 for 4kb banks
prg_bank:      .res 1  ;; Keeps track of our PRG bank, up to 8 for 32kb banks or 16 for 16kb banks
p1_controller: .res 1  ;; Holds bitmask of controller state
p2_controller: .res 1  ;; Holds bitmask of controller state

cam_x:       .res 2  ;; Holds horizontal scroll position 16bit
cam_y:       .res 2  ;; Holds vertical scroll position 16bit
cam_dx:      .res 1  ;; Holds horizontal scroll delta, signed
cam_dy:      .res 1  ;; Holds vertical scroll delta, signed

;; Rendering variables
render_flags:      .res 1 ;; For miscellaneous flags
                      ;; bit 0: whether or not the nametables are swapped. 0 = normal order, 1 = swapped order
;;;;

;;;; ZP program variables
state:         .res 1
frame_counter: .res 1
current_frame: .res 1
;;;;

.segment "BSS" ; Rest of RAM, $0200-$07FF. First 255 bytes are sprite DMA. Rest are free to use
sprite_area:               .res 256

scroll_speed:              .res 1 ;; How much to scroll by when pressing left or right
scroll_buffer_status:      .res 1 ;; Indicates whether a buffer is ready (1) or not-ready (0). bit 3 = left attr, bit 2 = left name, bit 1 = right_attr, bit 0 = right_name
scroll_buffer_left_name:   .res 30
scroll_buffer_right_name:  .res 30
scroll_buffer_left_attr:   .res 8
scroll_buffer_right_attr:  .res 8

.segment "PRG1" ;; Fixed PRG ROM. Always present
.include "lib/core.asm"    ;; 6502 basic utilities. Should always remain banked in
.include "lib/nes.asm"    ;; System subroutines and macros. Should always remain banked in.
.include "lib/stack.asm"  ;; Subroutines for software stack. Should always remain banked in.
.include "lib/mmc1.asm"   ;; Subroutines specific to the MMC1 memory mapper. Should always remain banked in.
.include "lib/scroll.asm" ;; Subroutines for the scrolling engine. Used during NMI so should always remain banked in.

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
  ;; Write software stack pointer
  JSR InitMemory

  ;; Initialize name and attr buffers for rendering
  JSR FillLeftAttrBuffer
  JSR FillRightAttrBuffer
  JSR FillLeftNameBuffer
  JSR FillRightNameBuffer

  ;; Initialize speed to 1
  LDA #$01
  STA scroll_speed

  ;; Wait for PPU to vblank. PPU hw finishing warming up
  JSR WaitVblank

  ;; name table 0 starts at PPU address $2000
  SET_PPU_ADDRESS $2000
  Call_WritePPUBytes name_table_screen0, $03C0 ;; Copy 960 bytes
  ;; attr table starts right after at PPU address $23C0
  Call_WritePPUBytes attr_table_screen0, $0040 ;; Copy 64 bytes

  ;; name table 1 starts at PPU address $2400
  SET_PPU_ADDRESS $2400
  Call_WritePPUBytes name_table_screen1, $03C0 ;; Copy 960 bytes
  ;; attr table starts right after at PPU address $23C0
  Call_WritePPUBytes attr_table_screen1, $0040 ;; Copy 64 bytes

  ;; palettes start at PPU address $3F00
  SET_PPU_ADDRESS $3F00
  Call_WritePPUBytes bg_palette_colors, $10     ;; Copy 16 bytes
  Call_WritePPUBytes sprite_palette_colors, $10 ;; Copy 16 bytes

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

  ;; Advance program frame
  INC frame_counter

  ;; DMA copy sprite data. This data should be prepared in advance prior to the NMI
  PPU_DMA sprite_area
  JSR UpdateScroll

  ;; Clean up PPUCTRL
  LDA render_flags
  AND #RENDER_FLAG_NAMETABLES_FLIPPED
  ORA #%10011000
  STA PPUCTRL

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
  .addr NMI     ;; Non-maskable interrupt (ie VBLANK)
  .addr RESET   ;; Processor turns on or reset button is pressed
  .word 0       ;; Other interrupts. Ignore for now

.segment "PRG0" ;; Default bank-swapped PRG ROM at $8000.
JMP RESET       ;; Entry point on program start

.include "lib/game.asm"

run:
  ;; Handle per-frame logic
  ;; Loop if we've handled this frame already
  LDA frame_counter
  CMP current_frame
  BEQ run
  STA current_frame

  .scope camera_buffers
    check_left_attr:
      LDA scroll_buffer_status
      AND #SCROLL_BUFFER_LEFT_ATTR_READY
      BNE check_right_attr
      JSR FillLeftAttrBuffer
      LDA scroll_buffer_status
      ORA #SCROLL_BUFFER_LEFT_ATTR_READY
      STA scroll_buffer_status

    check_right_attr:
      LDA scroll_buffer_status
      AND #SCROLL_BUFFER_RIGHT_ATTR_READY
      BNE check_left_name
      JSR FillRightAttrBuffer
      LDA scroll_buffer_status
      ORA #SCROLL_BUFFER_RIGHT_ATTR_READY
      STA scroll_buffer_status

    check_left_name:
      LDA scroll_buffer_status
      AND #SCROLL_BUFFER_LEFT_NAME_READY
      BNE check_right_name
      JSR FillLeftNameBuffer
      LDA scroll_buffer_status
      ORA #SCROLL_BUFFER_LEFT_NAME_READY
      STA scroll_buffer_status

    check_right_name:
      LDA scroll_buffer_status
      AND #SCROLL_BUFFER_RIGHT_NAME_READY
      BNE done
      JSR FillRightNameBuffer
      LDA scroll_buffer_status
      ORA #SCROLL_BUFFER_RIGHT_NAME_READY
      STA scroll_buffer_status
    done:
  .endscope

scroll_buffer_done:
  ;; Read controller input
  JSR UpdateController
  .scope scroll
      LDA p1_controller
      AND #CONTROLLER_RIGHT
      BEQ right_done

      LDA scroll_speed
      STA cam_dx
    right_done:
      LDA p1_controller
      AND #CONTROLLER_LEFT
      BEQ left_done

      LDA scroll_speed
      STA cam_dx
      STA_TWOS_COMP cam_dx
    left_done:
      LDA p1_controller
      AND #CONTROLLER_UP
      BEQ up_done

      LDA scroll_speed
      CLC
      ADC #01
      CMP #MAX_X_SCROLL_SPEED + 1
      BCC @scroll_speed_valid
      LDA #MAX_X_SCROLL_SPEED
    @scroll_speed_valid:
      STA scroll_speed
    up_done:
      LDA p1_controller
      AND #CONTROLLER_DOWN
      BEQ down_done

      LDA scroll_speed
      SEC
      SBC #01
      CMP #MIN_X_SCROLL_SPEED
      BCS @scroll_speed_valid
      LDA #MIN_X_SCROLL_SPEED
    @scroll_speed_valid:
      STA scroll_speed
    down_done:

  .endscope
  JSR CheckBounds
  LDA render_flags
  AND #RENDER_FLAG_SCROLL_UNLOCKED
  STA render_flags ;; Allows NMI to use cam_dx/cam_dy to scroll its registers
  JMP run

.segment "CHR0" ; 8kb, always present
  .incbin "assets/mario.chr" ; test data to fill the chr bank

.segment "CHR1" ; 8kb bank-switched
  .incbin "assets/mario_flip.chr" ; test data to fill the chr bank
