.include "defs/nes.asm"
.include "defs/game.asm"

.include "data/header.asm"

.segment "ZEROPAGE" ; premium real estate for global variables
.include "data/zp.asm"

.segment "BSS" ; Rest of RAM, $0200-$07FF. First 255 bytes are sprite DMA. Rest are free to use
.include "data/bss.asm"

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
  LDA #<attribute_table_header
  STA PLO
  LDA #>attribute_table_header
  STA PHI
  JSR LoadPageTable

  JSR FillLeftAttrBufferFromPage
  JSR FillRightAttrBufferFromPage
  JSR FillTopAttrBufferFromPage
  JSR FillBottomAttrBufferFromPage

  LDA #<name_table_header
  STA PLO
  LDA #>name_table_header
  STA PHI
  JSR LoadPageTable

  JSR FillLeftNameBufferFromPage
  JSR FillRightNameBufferFromPage
  JSR FillTopNameBufferFromPage
  JSR FillBottomNameBufferFromPage

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
    .scope scroll
        LDA p1_controller
        AND #CONTROLLER_A
        BEQ a_done

        LDA scroll_speed
        CLC
        ADC #01
        CMP #MAX_X_SCROLL_SPEED + 1
        BCC @scroll_speed_valid
        LDA #MAX_X_SCROLL_SPEED
      @scroll_speed_valid:
        STA scroll_speed
      a_done:

        LDA p1_controller
        AND #CONTROLLER_B
        BEQ b_done

        LDA scroll_speed
        SEC
        SBC #01
        CMP #MIN_X_SCROLL_SPEED
        BCS @scroll_speed_valid
        LDA #MIN_X_SCROLL_SPEED
      @scroll_speed_valid:
        STA scroll_speed
      b_done:

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

        ;; Note, Y is inverted so 'up' on the controller corresponds to decreasing Y
        LDA p1_controller
        AND #CONTROLLER_UP
        BEQ up_done

        LDA scroll_speed
        STA cam_dy
        STA_TWOS_COMP cam_dy
      up_done:

        ;; Note, Y is inverted so 'down' on the controller corresponds to increasing Y
        LDA p1_controller
        AND #CONTROLLER_DOWN
        BEQ down_done

        LDA scroll_speed
        STA cam_dy
      down_done:
    .endscope

    JSR CheckBounds

    .scope check_x_movement
      x_movement:
        LDA cam_dx
        BMI prepare_left
        BEQ done
      prepare_right:
        LDA scroll_buffer_status
        AND #SCROLL_BUFFER_RIGHT_ATTR_READY
        BNE @check_name

        LDA #<attribute_table_header
        STA PLO
        LDA #>attribute_table_header
        STA PHI
        JSR LoadPageTable

        JSR FillRightAttrBufferFromPage
        LDA scroll_buffer_status
        ORA #SCROLL_BUFFER_RIGHT_ATTR_READY
        STA scroll_buffer_status

      @check_name:
        LDA scroll_buffer_status
        AND #SCROLL_BUFFER_RIGHT_NAME_READY
        BNE done

        LDA #<name_table_header
        STA PLO
        LDA #>name_table_header
        STA PHI
        JSR LoadPageTable

        JSR FillRightNameBufferFromPage
        LDA scroll_buffer_status
        ORA #SCROLL_BUFFER_RIGHT_NAME_READY
        STA scroll_buffer_status
        JMP done

      prepare_left:
        LDA scroll_buffer_status
        AND #SCROLL_BUFFER_LEFT_ATTR_READY
        BNE @check_name

        LDA #<attribute_table_header
        STA PLO
        LDA #>attribute_table_header
        STA PHI
        JSR LoadPageTable

        JSR FillLeftAttrBufferFromPage
        LDA scroll_buffer_status
        ORA #SCROLL_BUFFER_LEFT_ATTR_READY
        STA scroll_buffer_status

      @check_name:
        LDA scroll_buffer_status
        AND #SCROLL_BUFFER_LEFT_NAME_READY
        BNE done

        LDA #<name_table_header
        STA PLO
        LDA #>name_table_header
        STA PHI
        JSR LoadPageTable

        JSR FillLeftNameBufferFromPage
        LDA scroll_buffer_status
        ORA #SCROLL_BUFFER_LEFT_NAME_READY
        STA scroll_buffer_status
      done:
    .endscope

    .scope check_y_movement
        LDA cam_dy
        BMI prepare_up
        BEQ done
      prepare_down:
        LDA scroll_buffer_status
        AND #SCROLL_BUFFER_BOTTOM_ATTR_READY
        BNE @check_name

        LDA #<attribute_table_header
        STA PLO
        LDA #>attribute_table_header
        STA PHI
        JSR LoadPageTable

        JSR FillBottomAttrBufferFromPage
        LDA scroll_buffer_status
        ORA #SCROLL_BUFFER_BOTTOM_ATTR_READY
        STA scroll_buffer_status

      @check_name:
        LDA scroll_buffer_status
        AND #SCROLL_BUFFER_BOTTOM_NAME_READY
        BNE done

        LDA #<name_table_header
        STA PLO
        LDA #>name_table_header
        STA PHI
        JSR LoadPageTable

        JSR FillBottomNameBufferFromPage
        LDA scroll_buffer_status
        ORA #SCROLL_BUFFER_BOTTOM_NAME_READY
        STA scroll_buffer_status
        JMP done

      prepare_up:
        LDA scroll_buffer_status
        AND #SCROLL_BUFFER_TOP_ATTR_READY
        BNE @check_name

        LDA #<attribute_table_header
        STA PLO
        LDA #>attribute_table_header
        STA PHI
        JSR LoadPageTable

        JSR FillTopAttrBufferFromPage
        LDA scroll_buffer_status
        ORA #SCROLL_BUFFER_TOP_ATTR_READY
        STA scroll_buffer_status

      @check_name:
        LDA scroll_buffer_status
        AND #SCROLL_BUFFER_TOP_NAME_READY
        BNE done

        LDA #<name_table_header
        STA PLO
        LDA #>name_table_header
        STA PHI
        JSR LoadPageTable

        JSR FillTopNameBufferFromPage
        LDA scroll_buffer_status
        ORA #SCROLL_BUFFER_TOP_NAME_READY
        STA scroll_buffer_status
      done:
    .endscope

    LDA render_flags
    AND #RENDER_FLAG_SCROLL_UNLOCKED
    STA render_flags ;; Allows NMI to use cam_dx/cam_dy and scroll buffers to scroll its registers
    JMP run

.segment "IVT"
  .addr NMI     ;; Non-maskable interrupt (ie VBLANK)
  .addr RESET   ;; Processor turns on or reset button is pressed
  .word 0       ;; Other interrupts. Ignore for now

.segment "PRG0" ;; Default bank-swapped PRG ROM at $8000.
JMP RESET       ;; Entry point on program start

palette:
  .include "data/palette.asm"

name_table:
  .include "data/name_table.asm"

name_table_header:
  .byte 4 ;; 4 pages wide
  .byte 3 ;; 2 pages high
  .byte 32 ;; 32 bytes wide per page
  .byte 30 ;; 30 bytes high per page
  .word 960 ;; 960 bytes total per page
  .word 3840 ;; 3840 bytes total per row
  .addr name_table

attribute_table:
  .include "data/attr_table.asm"

attribute_table_header:
  .byte 4 ;; 4 pages wide
  .byte 3 ;; 2 pages high
  .byte 8 ;; 8 bytes wide per page
  .byte 8 ;; 8 bytes high per page
  .word 64 ;; 64 bytes total per page
  .word 256 ;; 256 bytes total per row
  .addr attribute_table

sprites:
  .include "data/sprites.asm"

strings:
  .include "data/strings.asm"

.segment "CHR0" ; 8kb, always present
  .incbin "assets/mario.chr" ; test data to fill the chr bank

.segment "CHR1" ; 8kb bank-switched
  .incbin "assets/mario_flip.chr" ; test data to fill the chr bank
