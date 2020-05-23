;; DEFs
.include "defs/core.def"
.include "defs/mmc1.def"
.include "defs/nes.def"
.include "defs/notes_ntsc.def"

;; iNES header bytes
.include "data/header.asm"

.segment "ZEROPAGE" ; premium real estate for global variables
.include "mem/core.zp.asm"
.include "mem/nes.zp.asm"

.segment "BSS" ; Rest of RAM, $0200-$07FF.
.include "mem/stack.bss.asm" ;; First 255 bytes are sw stack
.include "mem/nes.bss.asm" ;; Next 255 bytes are sprite DMA
.include "mem/audio.bss.asm" ;; Next bytes are for the audio service

;; $0400-$07FF are free
frame_counter:  .res 1 ;; Updated every NMI
current_frame:  .res 1 ;; Compared with frame counter
p1_controller_prev: .res 1 ;; Holds last frame's value of p1_controller
p2_controller_prev: .res 1 ;; Holds last frame's value of p2_controller
p1_controller_rising: .res 1 ;; Holds p1_controller fresh press
p2_controller_rising: .res 1 ;; Holds p2_controller fresh press

current_note_index: .res 1
current_note: .res 2
current_note_volume: .res 1
current_apu_flags: .res 1

prev_note: .res 2
prev_note_volume: .res 1

.segment "PRG1" ;; Fixed PRG ROM. Always present
  .include "lib/core.asm"   ;; 6502 basic utilities. Should always remain banked in
  .include "lib/stack.asm"  ;; Subroutines for software stack. Should always remain banked in.
  .include "lib/nes.asm"    ;; NES system subroutines and macros. Should always remain banked in.
  .include "lib/mmc1.asm"   ;; Subroutines specific to the MMC1 memory mapper. Should always remain banked in.
  .include "lib/audio.asm"  ;; Subroutines controlling the sound engine. Namespaced under Audio::. Should always remain banked in

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

  JSR Audio::Init

  ;; Initialize any initial state memory
  LDA #$FF
  STA prev_note
  STA prev_note+1

  LDA #$08
  STA current_note_volume
  LDA #%00000111
  STA current_apu_flags

  LDA #%00001000
  STA APU_SQ1_SWEEP ;; Allows low notes
  STA APU_SQ2_SWEEP ;; Allows low notes

  ;; Wait for PPU to vblank. PPU hw finishing warming up
  JSR WaitVblank

  ;; name table 0 starts at PPU address $2000
  SET_PPU_ADDRESS PPU_ADDR_NAMETABLE0
  Call_WritePPUBytes name_table_screen0, $03C0 ;; Copy 960 bytes
  ;; attr table starts right after at PPU address $23C0
  Call_WritePPUBytes attr_table_screen0, $0040 ;; Copy 64 bytes

  ;; name table 1 starts at PPU address $2400
  SET_PPU_ADDRESS PPU_ADDR_NAMETABLE1
  Call_WritePPUBytes name_table_screen1, $03C0 ;; Copy 960 bytes
  ;; attr table starts right after at PPU address $23C0
  Call_WritePPUBytes attr_table_screen1, $0040 ;; Copy 64 bytes

  ;; palettes start at PPU address $3F00
  SET_PPU_ADDRESS PPU_ADDR_PALETTE0
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

;; Reset finished; wait for initial NMI
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

    ;; DMA copy sprite data ...
    ;; Write name tables ...
    LDA PPUSTATUS
    LDA #>PPU_ADDR_NAMETABLE0
    CLC
    ADC #$01
    STA PPUADDR
    LDA #$CB
    STA PPUADDR
    Call_WritePPUBytes strings, $09

    ;; Write attr tables ...
    LDA PPUSTATUS
    LDA #<PPU_ADDR_ATTRTABLE2
    CLC
    ADC #$1A
    TAY
    LDA #>PPU_ADDR_ATTRTABLE2
    ADC #$00
    STA PPUADDR
    TYA
    STA PPUADDR
    Call_WritePPUBytes attr_table_screen2, 3
    ;; Write palettes ...

    ;; Reset PPU scroll
    ;; Must be done at the end, as it shares registers with other PPU operations that modify it
    LDA #$00
    STA PPUSCROLL
    STA PPUSCROLL

    ;; All rendering is done.
    ;; Use this remaining time to perform other realtime tasks
    ;; Audio is a real-time task: It must maintain a consistent BPM even in the face of cpu slowdown and skipped renders.
    ;; The NMI will occur no matter what, even if we choose to skip rendering due to cpu slowdown.
    ;; Thus, we always process audio events once per frame, and only in the NMI

    ;; Configure channel enables
    LDA current_apu_flags
    STA APUFLAGS

    ;; Set SQ1,SQ2
    LDA current_note_volume
    ORA #%10110000 ;; Apply 25% Duty, Manual Volume
    STA APU_SQ1_ENV

    LDA current_note_volume
    ORA #%11110000 ;; Apply 50% Duty, Manual Volume
    STA APU_SQ2_ENV

    ;; Set note
    LDA current_note
    LDX current_note+1

    CMP prev_note
    BNE play_note
    CPX prev_note+1
    BEQ skip_note
  play_note:
    STA APU_SQ1_NOTE_LO
    STA APU_SQ2_NOTE_LO
    STA APU_TRI_NOTE_LO

    STX APU_SQ1_NOTE_HI
    STX APU_SQ2_NOTE_HI
    STX APU_TRI_NOTE_HI
  skip_note:

    ;; Restore in-progress flags/registers
    POP_IRQ
    RTI

run:
    ;; Handle per-frame logic
    ;; Loop if we've handled this frame already
    LDA frame_counter
    CMP current_frame
    BEQ run
    STA current_frame

    LDA p1_controller
    STA p1_controller_prev

    LDA p2_controller
    STA p2_controller_prev

    JSR UpdateController

    LDA p1_controller_prev
    EOR #$FF
    AND p1_controller
    STA p1_controller_rising

    LDA p2_controller_prev
    EOR #$FF
    AND p2_controller
    STA p2_controller_rising

    ;; Read controller input
    ;; Left<->Right changes note
    .scope controller_input
        LDA p1_controller_rising
        AND #CONTROLLER_LEFT
        BEQ no_left
        DEC current_note_index
        BPL @no_wrap
        LDA #$5F
        STA current_note_index
      @no_wrap:
        JMP done
      no_left:

        LDA p1_controller_rising
        AND #CONTROLLER_RIGHT
        BEQ no_right
        LDA current_note_index
        CLC
        ADC #$01
        CMP #$60
        BCC @no_wrap
        LDA #$00
      @no_wrap:
        STA current_note_index
        JMP done
      no_right:

        LDA p1_controller_rising
        AND #CONTROLLER_UP
        BEQ no_up
        LDA current_note_volume
        CLC
        ADC #$01
        CMP #$10
        BCS @at_ceil
        STA current_note_volume
      @at_ceil:
        JMP done
      no_up:

        LDA p1_controller_rising
        AND #CONTROLLER_DOWN
        BEQ no_down
        LDA current_note_volume
        SEC
        SBC #$01
        BMI @at_floor
        STA current_note_volume
      @at_floor:
        JMP done
      no_down:

        LDA p1_controller_rising
        AND #CONTROLLER_A
        BEQ no_a
        LDA current_apu_flags
        AND #%00000001 ;; Isolate the sq1 bit
        EOR #%00000001 ;; Toggle 0->1, 1->0
        STA r0
        LDA current_apu_flags
        AND #%11111110 ;; Erase the sq1 bit
        ORA r0         ;; Apply the sq1 bit
        STA current_apu_flags
        JMP done
      no_a:

        LDA p1_controller_rising
        AND #CONTROLLER_B
        BEQ no_b
        LDA current_apu_flags
        AND #%00000010 ;; Isolate the sq2 bit
        EOR #%00000010 ;; Toggle 0->1, 1->0
        STA r0
        LDA current_apu_flags
        AND #%11111101 ;; Erase the sq2 bit
        ORA r0         ;; Apply the sq2 bit
        STA current_apu_flags
        JMP done
      no_b:

        LDA p1_controller_rising
        AND #CONTROLLER_SELECT
        BEQ no_select
        LDA current_apu_flags
        AND #%00000100 ;; Isolate the tri bit
        EOR #%00000100 ;; Toggle 0->1, 1->0
        STA r0
        LDA current_apu_flags
        AND #%11111011 ;; Erase the tri bit
        ORA r0         ;; Apply the tri bit
        STA current_apu_flags
        JMP done
      no_select:

      done:
    .endscope

    ;; Update game state

    ;; Update current note
    LDA current_note
    STA prev_note
    LDA current_note+1
    STA prev_note+1

    LDA current_note_index
    ASL A
    TAX

    LDA notes,X
    STA current_note
    LDA notes+1,X
    STA current_note+1

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

attribute_table:
  .include "data/attr_table.asm"

sprites:
  .include "data/sprites.asm"

strings:
  .include "data/strings.asm"

notes:
  .include "data/notes_ntsc.asm"

.segment "CHR0" ; 8kb, always present
  .incbin "assets/mario.chr" ; test data to fill the chr bank

.segment "CHR1" ; 8kb bank-switched
  .incbin "assets/mario.chr" ; test data to fill the chr bank
