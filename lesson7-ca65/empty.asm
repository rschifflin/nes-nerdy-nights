.segment "ZEROPAGE" ; premium real estate for global variables
ptr:           .res 2 ; Base pointer used for indirection
r0:            .res 1; Simple re-usable byte register for subroutines

ret0:          .res 1 ; Used for temp space for swapping return values after RTS
ret1:          .res 1 ; RetN are protected by interrupt request handlers
ret2:          .res 1 ; These values will be overwritten on any JSR
ret3:          .res 1 ; So swap them back and store them on the stack if needed

state:         .res 1 ; Holds the game state
frame_counter: .res 1 ; Alloc 1 byte for the frame counter
current_frame: .res 1 ; Alloc 1 byte for the current frame
controller:    .res 1 ; Holds bitmask of controller state

p1_score:      .res 2 ; Kept as decimal digits
p2_score:      .res 2 ; Kept as decimal digits
time:          .res 4 ; Kept as 4 decimal digits

.segment "BSS" ; Rest of RAM. First 255 bytes are stack. Next 255 are sprite DMA. Rest are free to use
ball:          .res 16 ; Holds 4 4-byte sprite structs
player_paddle: .res 64 ; Holds 16 4-byte sprite structs
ai_paddle:     .res 64 ; Holds 16 4-byte sprite structs

.segment "iNes" ; Defines a header segment for emulators. When using a real cart, we would strip these bytes and just use the zeropage as the start
  .byte $4e, $45, $53, $1a ; ines filetype magic bytes
  .byte $01 ; # of 16kb PRG segments
  .byte $01 ; # of 8kb CHR segments
  .byte $01 ; # Nametable mirroring in the PPU
  .byte $00 ; # Mapper=0, NROM aka no bank swapping
  .byte $00 ; # Mapper=0, NROM aka no bank swapping
  .byte $00 ; # Mapper=0, NROM aka no bank swapping

.segment "CODE"

;; PPU (Video)
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
OAMDATA   = $2004
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014

;; APU (Audio)
APUCTRL   = $4010
APUFC     = $4017

;; Controller
CONTROLLER_STATUS    = $4016
CONTROLLER_P1        = $4016
CONTROLLER_P2        = $4017
CONTROLLER_P1_A      = %10000000
CONTROLLER_P1_B      = %01000000
CONTROLLER_P1_SELECT = %00100000
CONTROLLER_P1_START  = %00010000
CONTROLLER_P1_UP     = %00001000
CONTROLLER_P1_DOWN   = %00000100
CONTROLLER_P1_LEFT   = %00000010
CONTROLLER_P1_RIGHT  = %00000001

;; HW Memory locations
SPRITE_AREA = $0200
INTERRUPT_VECTOR_TABLE = $FFFA

.macro PUSH_IRQ
  PHP ; Push A
  PHA ; Push A
  TXA ; X->A
  PHA ; Push X
  TYA ; Y->A
  PHA ; Push Y
  LDA ptr
  PHA ; Push ptr lo register
  LDA ptr+1
  PHA ; Push ptr hi register
  LDA r0
  PHA ; Push r0
.endmacro

.macro POP_IRQ
  PLA ; Pull r0
  STA r0
  PLA ; Pull ptrHi
  STA ptr+1
  PLA ; Pull ptrLo
  STA ptr
  PLA ; Pull Y
  TAY ; A->Y
  PLA ; Pull X
  TAX ; A->X
  PLA ; Pull A
  PLP
.endmacro

WaitVblank:
  BIT PPUSTATUS   ; Test the interrupt bit (bit 7) of the PPUSTATUS port
  BPL WaitVblank ; Loop until the interrupt bit is set
  RTS

.macro SET_PPU_ADDRESS arg_ptr
  LDA PPUSTATUS ; Prepare to change PPU Address
  LDA #>arg_ptr
  STA PPUADDR ; write the high byte of the addr
  LDA #<arg_ptr
  STA PPUADDR ; write the low byte of the addr
.endmacro

.macro PPU_DMA arg_ptr
  LDA #<arg_ptr
  STA OAMADDR ; Tell PPU the low byte of a memory region for DMA
  LDA #>arg_ptr
  STA OAMDMA ; Tell PPU the high byte of a memory region for DMA, then begin DMA
.endmacro

.macro WRITE_PPU_BYTES arg_ptr, arg_len
  LDA #<arg_ptr
  STA ptr
  LDA #>arg_ptr

  LDY #<arg_len
  LDX #>arg_len
  JSR LoadPPU
.endmacro

.proc LoadPPU
    STA ptr+1
    STY r0
    LDY #$00

  ;; We iterate using a 2-byte counter. Breaking the counter into Hi and Lo bytes, we iterate 256*Hi + Lo times.

  ;; X keeps the index of the hi loop and counts down
  ;; When X is 0, we've finished counting the hi byte and we enter the lo loop
  ;; When X is nonzero, we enter the hi inner loop
    CPX #$00
  loop_hi_outer:
    BNE loop_hi_inner
    LDY #$00
    JMP loop_lo

  ;; Y keeps the index of the hi inner loop. The inner loop always iterates 256 times.
  ;; During this loop, the base pointer is not modified and Y is used to offset the base pointer.
  ;; After the 256th iteration, we decrement X, modify the base pointer by 256 to keep our place, and return to the outer loop
  loop_hi_inner:
    LDA (ptr),Y
    STA PPUDATA ; Write byte to ppu
    INY ;; may set the ZERO flag to break the hi inner loop
    BNE loop_hi_inner
    INC ptr+1
    DEX ;; may set the ZERO flag to break the hi outer loop
    JMP loop_hi_outer

  ;; During the lo loop, Y keeps the index and counts up to the target stored in r0.
  ;; After r0 iterations, we finish
  loop_lo:
    CPY r0
    BEQ done
    LDA (ptr),Y
    STA PPUDATA ; Write byte to ppu
    INY
    JMP loop_lo
  done:
    RTS
.endproc

.proc DrawScore
    SET_PPU_ADDRESS $2042 ; modify name table at p1 score position
    WRITE_PPU_BYTES p1_score, $02

    SET_PPU_ADDRESS $205C ; modify name table at p2 score position
    WRITE_PPU_BYTES p2_score, $02
    RTS
.endproc

.proc DrawTime
    SET_PPU_ADDRESS $202D ; modify name table at time position
    WRITE_PPU_BYTES time, $04
    RTS
.endproc

.proc DrawStart
    SET_PPU_ADDRESS $238A ; modify name table at press_start position
    WRITE_PPU_BYTES strings_press_start, $0B
    RTS
.endproc

.proc AdcDec
  STX r0
  ADC r0
  CMP #$0A
  BCC done ; done if result < 10
  ;; Handle overflow
  SEC ;; Prepare to sub
  SBC #$0A
  SEC ;; Indicate overflow
done:
  RTS
.endproc


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

run:
  ;; Handle per-frame logic
  LDA frame_counter ;; Frame counter
  CMP current_frame ;; Current Frame
  BEQ run ;; Loop if we've handled this frame already
  STA current_frame ;; Mark current frame as handled

run_action:
  LDA current_frame
  AND #%00011111 ;; Tick every frame
  BNE @done
  CLC
  LDX #$01 ; addend
  LDY #$04 ; counter
@loop:
  LDA time-1,Y
  JSR AdcDec
  STA time-1,Y
  LDX #$00 ; addend
  DEY
  BNE @loop
@done:
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

  LDA #$00
  STA PPUSCROLL ; Disable horizontal scrolling after NMI always
  STA PPUSCROLL ; Disable vertical scrolling after NMI always
  POP_IRQ; Restore in-progress flags/registers
  RTI ; Return from interrupt

palette:
  .include "palette.asm"

name_table:
  .include "name_table.asm"

attribute_table:
  .include "attr_table.asm"

sprites:
  .include "sprites.asm"

strings:
  .include "strings.asm"
  ; remaining bank 1 code ...

.segment "IVT"
  .addr NMI   ; Non-maskable interrupt (ie VBLANK)
  .addr RESET ; Processor turns on or reset button is pressed
  .word 0 ; Other interrupts. Ignore for now

.segment "CHR1" ; ineschr bank 1 - 8kb, starts at $0000 on the chr rom
  .incbin "mario.chr" ; test data to fill the chr bank
