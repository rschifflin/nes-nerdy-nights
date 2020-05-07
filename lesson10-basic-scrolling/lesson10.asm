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

cam_x:       .res 2  ;; Holds horizontal scroll position 16bit
cam_y:       .res 2  ;; Holds vertical scroll position 16bit
cam_dx:      .res 1  ;; Holds horizontal scroll delta, signed
cam_dy:      .res 1  ;; Holds vertical scroll delta, signed

sysflags:      .res 1 ;; For miscellaneous flags
                      ;; bit 0: whether or not the horizontal banks are swapped. 0 = normal order, 1 = swapped order
;;;;

;;;; ZP program variables
state:         .res 1
frame_counter: .res 1
current_frame: .res 1
;;;;

.segment "BSS" ; Rest of RAM, $0200-$07FF. First 255 bytes are sprite DMA. Rest are free to use
sprite_area:            .res 256
scroll_buffer_x_left:   .res 30
scroll_buffer_x_right:  .res 30

.segment "PRG1" ;; Fixed PRG ROM. Always present
.include "lib/nes.asm"  ;; System subroutines and macros. Should always remain banked in.
.include "lib/mmc1.asm" ;; Subroutines specific to the MMC1 memory mapper. Should always remain banked in.
.include "lib/scroll.asm" ;; Subroutines for the scrolling engine. Used during NMI so should always remain banked in.
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
  WRITE_PPU_BYTES name_table_screen0, $03C0 ;; Copy 960 bytes
  ;; attr table starts right after at PPU address $23C0
  WRITE_PPU_BYTES attr_table0, $0040 ;; Copy 64 bytes

  ;; name table 1 starts at PPU address $2400
  SET_PPU_ADDRESS $2400
  WRITE_PPU_BYTES name_table_screen0, $03C0 ;; Copy 960 bytes
  ;; attr table starts right after at PPU address $23C0
  WRITE_PPU_BYTES attr_table0, $0040 ;; Copy 64 bytes

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

  ;; Advance program frame
  INC frame_counter

  ;; DMA copy sprite data. This data should be prepared in advance prior to the NMI
  PPU_DMA sprite_area
  JSR UpdateScroll

  ;; Clean up PPUCTRL
  LDA sysflags
  AND #SYSFLAG_SCROLL_X_ORDER
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

  ;; Compare cam_x % 8 for tile-alignment. If we're tile-aligned, we need to fetch fresh buffers
  .scope camera_buffers
      LDA cam_x
      AND #%00000111
      BEQ skip_scroll
      JMP start_scroll
    skip_scroll:
      JMP done
    start_scroll:
      .scope scroll_right_buffer
        fetch:
          LDA cam_x
          PHA
          LDA cam_x+1
          PHA

          INC cam_x+1 ;; The rightmost buffer origin is 256 pixels right of camera, so add 1 to the high byte
          ;; We convert the world coordinates of the camera's origin tile to its memory address
          ;; This means turning pixels into a byte offset from some base tile0 in memory

          ;; Each page of 960 bytes of memory spans 32 tiles on the x-axis
          ;; CamHi is a scalar of 32 tiles on the x-axis
          ;; Each page of 960 bytes of memory begins with the 32 toprow tiles
          ;; CamLo represents the offset in pixels to the desired toprow tile. Divide by 8 to get the offset in tiles
          ;; So the effective byte address is
          ;; Base + (960 * CamHi) + (CamLo >> 3)
          LDA #<name_table
          STA ptr
          LDA #>name_table
          STA ptr+1

          LDX cam_x+1
          BEQ offset_cam_lo
        offset_cam_hi: ;; Mulitply CamHi*960 and add to the base address
          LDA #$C0
          CLC
          ADC ptr
          STA ptr
          LDA #$03
          ADC ptr+1
          STA ptr+1
          DEX
          BNE offset_cam_hi
        offset_cam_lo: ;; Add the tile bits of CamLo to the address
          .repeat 3
            LSR cam_x
          .endrepeat
          LDA cam_x
          CLC
          ADC ptr
          STA ptr
          BCC target_stored
          INC ptr+1
        target_stored:
          LDX #$00
        write:
          LDY #$00
        write_8:
          LDA (ptr), Y
          STA scroll_buffer_x_right, X
          INX
          CPX #$1E ;; Write 30 bytes per column
          BEQ write_done
          TYA
          CLC
          ADC #$20 ;; Next column cell is 32 bytes away
          TAY
          BNE write_8
          INC ptr+1
          BNE write ;; Bump offset by 256 every 8 writes
        write_done:
          PLA
          STA cam_x+1
          PLA
          STA cam_x
      .endscope
      .scope scroll_left_buffer
          LDA cam_x
          PHA
          LDA cam_x+1
          PHA

          LDA cam_x
          SEC
          SBC #$08 ;; The leftmost buffer origin is 8 pixels left of camera, so sub 8
          STA cam_x
          BCS no_borrow
          DEC cam_x+1
        no_borrow:
          ;; We convert the world coordinates of the camera's origin tile to its memory address
          ;; This means turning pixels into a byte offset from some base tile0 in memory

          ;; Each page of 960 bytes of memory spans 32 tiles on the x-axis
          ;; CamHi is a scalar of 32 tiles on the x-axis
          ;; Each page of 960 bytes of memory begins with the 32 toprow tiles
          ;; CamLo represents the offset in pixels to the desired toprow tile. Divide by 8 to get the offset in tiles
          ;; So the effective byte address is
          ;; Base + (960 * CamHi) + (CamLo >> 3)
          LDA #<name_table
          STA ptr
          LDA #>name_table
          STA ptr+1

          LDX cam_x+1
          BEQ offset_cam_lo
        offset_cam_hi: ;; Mulitply CamHi*960 and add to the base address
          LDA #$C0
          CLC
          ADC ptr
          STA ptr
          LDA #$03
          ADC ptr+1
          STA ptr+1
          DEX
          BNE offset_cam_hi
        offset_cam_lo: ;; Add the tile bits of CamLo to the address
          .repeat 3
            LSR cam_x
          .endrepeat
          LDA cam_x
          CLC
          ADC ptr
          STA ptr
          BCC target_stored
          INC ptr+1
        target_stored:
          LDX #$00
        write:
          LDY #$00
        write_8:
          LDA (ptr), Y
          STA scroll_buffer_x_left, X
          INX
          CPX #$1E ;; Write 30 bytes per column
          BEQ write_done
          TYA
          CLC
          ADC #$20 ;; Next column cell is 32 bytes away
          TAY
          BNE write_8
          INC ptr+1
          BNE write ;; Bump offset by 256 every 8 writes
        write_done:
          PLA
          STA cam_x+1
          PLA
          STA cam_x
      .endscope
      done:
  .endscope

scroll_buffer_done:
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
      BEQ right_done

      LDA cam_x+1
      CMP #>MAX_X_SCROLL
      BCC @apply      ;; A < MAX_X_SCROLL
      BNE right_done  ;; A > MAX_X_SCROLL
      ;; Else A == MAX_X_SCROLL, check lo byte
      LDA cam_x
      CMP #<MAX_X_SCROLL
      BCS right_done  ;; A >= MAX_X_SCROLL
      ;; Else A < MAX_X_SCROLL, apply
    @apply:
      LDA #$01
      STA cam_dx
    right_done:
      LDA p1_controller
      AND #CONTROLLER_LEFT
      BEQ left_done

      LDA cam_x+1
      CMP #>MIN_X_SCROLL
      BCC left_done ;; A < MIN_X_SCROLL
      BNE @apply    ;; A > MINX_X_SCROLL
      ;; Else A == MIN_X_SCROLL, check lo byte
      LDA cam_x
      CMP #<MIN_X_SCROLL
      BCC left_done ;; A < MIN_X_SCROLL
      BEQ left_done ;; A = MIN_X_SCROLL
      ;; Else A > MIN_X_SCROLL, apply
    @apply:
      LDA #$FF ;; Negative 1
      STA cam_dx
    left_done:
  .endscope
  JMP run

.segment "CHR0" ; 8kb, always present
  .incbin "assets/mario.chr" ; test data to fill the chr bank

.segment "CHR1" ; 8kb bank-switched
  .incbin "assets/mario_flip.chr" ; test data to fill the chr bank
