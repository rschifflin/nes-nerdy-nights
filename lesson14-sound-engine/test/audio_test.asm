.include "../defs/nes.def"
.include "../defs/audio.def"
.segment "BSS"
.include "../mem/audio.bss.asm"

.include "harness.asm"
.include "../lib/audio.asm"

.proc TestInit
    JMP test
  expected:
    ;; BGM track:
    .byte $00 ;; Channel mask
    .addr $0000 ;; no audio stream
    .addr audio::decoder_0 ;; ptr to decoder
    .addr audio::decoder_1 ;; ptr to decoder
    .addr audio::decoder_2 ;; ptr to decoder
    .addr audio::decoder_3 ;; ptr to decoder

    ;; SFX0 track:
    .byte $00 ;; Channel mask
    .addr $0000 ;; no audio stream
    .addr audio::decoder_4 ;; ptr to decoder
    .addr audio::decoder_5 ;; ptr to decoder
    .addr audio::decoder_6 ;; ptr to decoder
    .addr audio::decoder_7 ;; ptr to decoder

    ;; SFX1 track:
    .byte $00 ;; Channel mask
    .addr $0000 ;; no audio stream
    .addr audio::decoder_8 ;; ptr to decoder
    .addr audio::decoder_9 ;; ptr to decoder
    .addr audio::decoder_A ;; ptr to decoder
    .addr audio::decoder_B ;; ptr to decoder

    ;; Disable
    .byte $00
    ;; Force Write
    .byte $01

  test:
    JSR Audio::Init

    LDX #$00
  loop:
    LDA expected,X
    STA TEST_EXPECTED,X
    LDA audio::track_bgm,X
    STA TEST_ACTUAL,X
    INX
    CPX #$21
    BNE loop

    LDA expected,X
    STA TEST_EXPECTED,X
    LDA audio::disable
    STA TEST_ACTUAL,X
    INX
    LDA expected,X
    STA TEST_EXPECTED,X
    LDA audio::force_write
    STA TEST_ACTUAL,X
    INX

    SHOW
    RTS
.endproc

.proc TestPlayBGM
    JMP test
  audio_stream:
    .byte %00001010 ;; Channels Sq2 and Noise
    .byte $E0 ;; No idea
    ;; In the future:
    ;; .repeat n .byte instruments?
    ;; .repeat n .byte patterns?
    ;; .repeat n .byte frames?
    .addr stream_ch0
    .addr stream_ch1
    .addr stream_ch2
    .addr stream_ch3
  stream_ch0:
    .repeat 16
      .byte $AA
    .endrepeat
  stream_ch1:
    .repeat 16
      .byte $BB
    .endrepeat
  stream_ch2:
    .repeat 16
      .byte $CC
    .endrepeat
  stream_ch3:
    .repeat 16
      .byte $DD
    .endrepeat

  expected:
    ;; BGM track (11 bytes):
    .byte %00001010 ;; Channel mask
    .addr audio_stream ;; ptr to audio stream
    .addr audio::decoder_0 ;; ptr to decoder
    .addr audio::decoder_1 ;; ptr to decoder
    .addr audio::decoder_2 ;; ptr to decoder
    .addr audio::decoder_3 ;; ptr to decoder

    ;; Decoder 0 (6 bytes)
    .addr stream_ch0   ;; stream head
    .byte $30, $08, $00, $00 ;; Default silent registers
    .byte $E0 ;; Placeholder for speed/tempo
    ;; TODO: .byte length counter
    ;; TODO: .byte loop counter
    ;; TODO: .byte channel done?

    ;; Decoder 1 (6 bytes)
    .addr stream_ch1   ;; stream head
    .byte $30, $08, $00, $00 ;; Default silent registers
    .byte $E0 ;; Placeholder for speed/tempo
    ;; TODO: .byte length counter
    ;; TODO: .byte loop counter
    ;; TODO: .byte channel done?

    ;; Decoder 2 (6 bytes)
    .addr stream_ch2   ;; stream head
    .byte $80, $08, $00, $00 ;; Default silent registers (Note, this is a triangle ch)
    .byte $E0 ;; Placeholder for speed/tempo
    ;; TODO: .byte length counter
    ;; TODO: .byte loop counter
    ;; TODO: .byte channel done?

    ;; Decoder 3 (6 bytes)
    .addr stream_ch3   ;; stream head
    .byte $30, $08, $00, $00 ;; Default silent registers
    .byte $E0 ;; Placeholder for speed/tempo
    ;; TODO: .byte length counter
    ;; TODO: .byte loop counter
    ;; TODO: .byte channel done?

  test:
    LDX #$00
  loop_expected:
    LDA expected,X
    STA TEST_EXPECTED,X
    INX
    CPX #$23
    BNE loop_expected

    JSR Audio::Init
    LDA #<audio_stream
    PHA_SP
    LDA #>audio_stream
    PHA_SP
    JSR Audio::PlayBGM
    PLN_SP 2

  .scope loop_actual
      LDX #$00
      LDY #$00
    bgm:
      LDA audio::track_bgm, X
      STA TEST_ACTUAL, Y
      INY
      INX
      CPX #$0B
      BNE bgm

      LDX #$00
    decoders:
      LDA audio::decoders, X
      STA TEST_ACTUAL, Y
      INY
      INX
      CPX #$18
      BNE decoders
  .endscope

    SHOW
    RTS
.endproc

.proc TestPlaySFX0
    JMP test
  audio_stream:
    .byte %00000100 ;; Just channel Tri
    .byte $FA ;; A placeholder speed/tempo
    ;; In the future:
    ;; .repeat n .byte instruments?
    ;; .repeat n .byte patterns?
    ;; .repeat n .byte frames?
    .addr stream_ch0
    .addr stream_ch1
    .addr stream_ch2
    .addr stream_ch3
  stream_ch0:
    .repeat 16
      .byte $AA
    .endrepeat
  stream_ch1:
    .repeat 16
      .byte $BB
    .endrepeat
  stream_ch2:
    .repeat 16
      .byte $CC
    .endrepeat
  stream_ch3:
    .repeat 16
      .byte $DD
    .endrepeat

  expected:
    ;; SFX0 track (11 bytes):
    .byte %00000100 ;; Channel mask
    .addr audio_stream ;; ptr to audio stream
    .addr audio::decoder_4 ;; ptr to decoder
    .addr audio::decoder_5 ;; ptr to decoder
    .addr audio::decoder_6 ;; ptr to decoder
    .addr audio::decoder_7 ;; ptr to decoder

    ;; Decoder 4 (6 bytes)
    .addr stream_ch0   ;; stream head
    .byte $30, $08, $00, $00 ;; Default silent registers
    .byte $FA ;; Placeholder for speed/tempo
    ;; TODO: .byte length counter
    ;; TODO: .byte loop counter
    ;; TODO: .byte channel done?

    ;; Decoder 5 (6 bytes)
    .addr stream_ch1   ;; stream head
    .byte $30, $08, $00, $00 ;; Default silent registers
    .byte $FA ;; Placeholder for speed/tempo
    ;; TODO: .byte length counter
    ;; TODO: .byte loop counter
    ;; TODO: .byte channel done?

    ;; Decoder 6 (6 bytes)
    .addr stream_ch2   ;; stream head
    .byte $80, $08, $00, $00 ;; Default silent registers (Note, this is a triangle ch)
    .byte $FA ;; Placeholder for speed/tempo
    ;; TODO: .byte length counter
    ;; TODO: .byte loop counter
    ;; TODO: .byte channel done?

    ;; Decoder 7 (6 bytes)
    .addr stream_ch3   ;; stream head
    .byte $30, $08, $00, $00 ;; Default silent registers
    .byte $FA ;; Placeholder for speed/tempo
    ;; TODO: .byte length counter
    ;; TODO: .byte loop counter
    ;; TODO: .byte channel done?

  test:
    LDX #$00
  loop_expected:
    LDA expected,X
    STA TEST_EXPECTED,X
    INX
    CPX #$23
    BNE loop_expected

    JSR Audio::Init
    LDA #<audio_stream
    PHA_SP
    LDA #>audio_stream
    PHA_SP
    JSR Audio::PlaySFX0
    PLN_SP 2

  .scope loop_actual
      LDX #$00
      LDY #$00
    sfx0:
      LDA audio::track_sfx0, X
      STA TEST_ACTUAL, Y
      INY
      INX
      CPX #$0B
      BNE sfx0

      LDX #$00
    decoders:
      LDA audio::decoder_4, X
      STA TEST_ACTUAL, Y
      INY
      INX
      CPX #$18
      BNE decoders
  .endscope

    SHOW
    RTS
.endproc

.proc TestPlaySFX1
    JMP test
  audio_stream:
    .byte %00001111 ;; All channels
    .byte $14 ;; A placeholder speed/tempo
    ;; In the future:
    ;; .repeat n .byte instruments?
    ;; .repeat n .byte patterns?
    ;; .repeat n .byte frames?
    .addr stream_ch0
    .addr stream_ch1
    .addr stream_ch2
    .addr stream_ch3
  stream_ch0:
    .repeat 16
      .byte $AA
    .endrepeat
  stream_ch1:
    .repeat 16
      .byte $BB
    .endrepeat
  stream_ch2:
    .repeat 16
      .byte $CC
    .endrepeat
  stream_ch3:
    .repeat 16
      .byte $DD
    .endrepeat

  expected:
    ;; SFX1 track (11 bytes):
    .byte %00001111 ;; Channel mask
    .addr audio_stream ;; ptr to audio stream
    .addr audio::decoder_8 ;; ptr to decoder
    .addr audio::decoder_9 ;; ptr to decoder
    .addr audio::decoder_A ;; ptr to decoder
    .addr audio::decoder_B ;; ptr to decoder

    ;; Decoder 8 (6 bytes)
    .addr stream_ch0   ;; stream head
    .byte $30, $08, $00, $00 ;; Default silent registers
    .byte $14 ;; Placeholder for speed/tempo
    ;; TODO: .byte length counter
    ;; TODO: .byte loop counter
    ;; TODO: .byte channel done?

    ;; Decoder 9 (6 bytes)
    .addr stream_ch1   ;; stream head
    .byte $30, $08, $00, $00 ;; Default silent registers
    .byte $14 ;; Placeholder for speed/tempo
    ;; TODO: .byte length counter
    ;; TODO: .byte loop counter
    ;; TODO: .byte channel done?

    ;; Decoder A (6 bytes)
    .addr stream_ch2   ;; stream head
    .byte $80, $08, $00, $00 ;; Default silent registers (Note, this is a triangle ch)
    .byte $14 ;; Placeholder for speed/tempo
    ;; TODO: .byte length counter
    ;; TODO: .byte loop counter
    ;; TODO: .byte channel done?

    ;; Decoder B (6 bytes)
    .addr stream_ch3   ;; stream head
    .byte $30, $08, $00, $00 ;; Default silent registers
    .byte $14 ;; Placeholder for speed/tempo
    ;; TODO: .byte length counter
    ;; TODO: .byte loop counter
    ;; TODO: .byte channel done?

  test:
    LDX #$00
  loop_expected:
    LDA expected,X
    STA TEST_EXPECTED,X
    INX
    CPX #$23
    BNE loop_expected

    JSR Audio::Init
    LDA #<audio_stream
    PHA_SP
    LDA #>audio_stream
    PHA_SP
    JSR Audio::PlaySFX1
    PLN_SP 2

  .scope loop_actual
      LDX #$00
      LDY #$00
    sfx1:
      LDA audio::track_sfx1, X
      STA TEST_ACTUAL, Y
      INY
      INX
      CPX #$0B
      BNE sfx1

      LDX #$00
    decoders:
      LDA audio::decoder_8, X
      STA TEST_ACTUAL, Y
      INY
      INX
      CPX #$18
      BNE decoders
  .endscope

    SHOW
    RTS
.endproc

.proc Test0TrackForChannel
    LDA #%00001111 ;; All channels active
    STA audio::track_bgm + AUDIO::Track::channels_active
    STA audio::track_sfx0 + AUDIO::Track::channels_active
    STA audio::track_sfx1 + AUDIO::Track::channels_active

    LDX #$00
  expected:
    LDA #<audio::track_sfx1
    STA TEST_EXPECTED,X
    LDA #>audio::track_sfx1
    STA TEST_EXPECTED+1,X
    INX
    INX
    CPX #$08
    BNE expected

    LDX #$00
    LDY #AUDIO::CHANNEL_SQ1
  loop:
    TYA
    PHA
    TXA
    PHA

    STY r0
    JSR Audio::TrackForChannel

    PLA
    TAX
    LDA PLO
    STA TEST_ACTUAL,X
    LDA PHI
    STA TEST_ACTUAL+1,X

    PLA
    CMP #AUDIO::CHANNEL_NOISE
    BEQ end_loop ;; stop after noise
    ASL A ;; Iterate through all audio channel bitflags
    TAY
    INX
    INX
    JMP loop
  end_loop:
    SHOW
    RTS
.endproc

.proc Test1TrackForChannel
    LDA #%00001100 ;; Highest prio has NOISE and TRI active
    STA audio::track_sfx1 + AUDIO::Track::channels_active

    LDA #%00000110 ;; Middle prio has TRI and SQ2 active
    STA audio::track_sfx0 + AUDIO::Track::channels_active

    LDA #%00000011 ;; Lowest prio has SQ2 and SQ1 active
    STA audio::track_bgm + AUDIO::Track::channels_active

    ;; Expect BGM (lowest prio) to map to sq0
    LDA #<audio::track_bgm
    STA TEST_EXPECTED
    LDA #>audio::track_bgm
    STA TEST_EXPECTED+1

    ;; Expect sfx0 (middle prio) to map to sq1
    LDA #<audio::track_sfx0
    STA TEST_EXPECTED+2
    LDA #>audio::track_sfx0
    STA TEST_EXPECTED+3

    ;; Expect sfx1 (highest prio) to map to tri and noise
    LDA #<audio::track_sfx1
    STA TEST_EXPECTED+4
    STA TEST_EXPECTED+6
    LDA #>audio::track_sfx1
    STA TEST_EXPECTED+5
    STA TEST_EXPECTED+7

    LDX #$00
    LDY #AUDIO::CHANNEL_SQ1
  loop:
    TYA
    PHA
    TXA
    PHA

    STY r0
    JSR Audio::TrackForChannel

    PLA
    TAX
    LDA PLO
    STA TEST_ACTUAL,X
    LDA PHI
    STA TEST_ACTUAL+1,X

    PLA
    CMP #AUDIO::CHANNEL_NOISE
    BEQ end_loop ;; stop after noise
    ASL A ;; Iterate through all audio channel bitflags
    TAY
    INX
    INX
    JMP loop
  end_loop:
    SHOW
    RTS
.endproc

.proc Test2TrackForChannel
    LDA #%00001101 ;; All channels missing sq2
    STA audio::track_bgm + AUDIO::Track::channels_active
    STA audio::track_sfx0 + AUDIO::Track::channels_active
    STA audio::track_sfx1 + AUDIO::Track::channels_active

    LDX #$00
  expected:
    LDA #<audio::track_sfx1
    STA TEST_EXPECTED,X
    LDA #>audio::track_sfx1
    STA TEST_EXPECTED+1,X
    INX
    INX
    CPX #$08
    BNE expected
    LDA #$00 ;; Sq2 should be null
    STA TEST_EXPECTED+2
    STA TEST_EXPECTED+3

    LDX #$00
    LDY #AUDIO::CHANNEL_SQ1
  loop:
    TYA
    PHA
    TXA
    PHA

    STY r0
    JSR Audio::TrackForChannel

    PLA
    TAX
    LDA PLO
    STA TEST_ACTUAL,X
    LDA PHI
    STA TEST_ACTUAL+1,X

    PLA
    CMP #AUDIO::CHANNEL_NOISE
    BEQ end_loop ;; stop after noise
    ASL A ;; Iterate through all audio channel bitflags
    TAY
    INX
    INX
    JMP loop
  end_loop:
    SHOW
    RTS
.endproc

.proc Test0PrepareChannelBuffer
    LDA #<(audio::decoder_0 + AUDIO::Decoder::registers)
    STA TEST_EXPECTED
    LDA #>(audio::decoder_0 + AUDIO::Decoder::registers)
    STA TEST_EXPECTED+1

    JSR Audio::Init
    LDA #AUDIO::CHANNEL_SQ1
    STA r0
    LDA #<audio::track_bgm
    STA PLO
    LDA #>audio::track_bgm
    STA PHI
    JSR Audio::PrepareChannelBuffer

    LDA audio::buffer_ch_addr_list
    STA TEST_ACTUAL
    LDA audio::buffer_ch_addr_list+1,X
    STA TEST_ACTUAL+1

    SHOW
    RTS
.endproc

.proc Test1PrepareChannelBuffer
    JMP test
  call_args:
    .byte AUDIO::CHANNEL_SQ1
    .addr audio::track_bgm
    .byte AUDIO::CHANNEL_SQ2
    .addr audio::track_sfx0
    .byte AUDIO::CHANNEL_TRI
    .addr audio::track_bgm
    .byte AUDIO::CHANNEL_NOISE
    .addr audio::track_sfx1

  test:
    ;; Expect the channel buffer order to be:
    ;; sq1 -> BGM track, register values 0-3
    ;; sq2 -> SFX0 track, register values 4-7
    ;; tri -> BGM track, register values 8-11
    ;; noise -> SFX1 track, register values 12-15
    .scope let
        LDX #$00 ;; Register value counter
        LDY #$00
      sq1:
        TXA
        STA audio::decoder_0 + AUDIO::Decoder::registers, Y
        INX
        INY
        CPY #$04
        BNE sq1

        LDY #$00
      sq2:
        TXA
        STA audio::decoder_5 + AUDIO::Decoder::registers, Y
        INX
        INY
        CPY #$04
        BNE sq2

        LDY #$00
      tri:
        TXA
        STA audio::decoder_2 + AUDIO::Decoder::registers, Y
        INX
        INY
        CPY #$04
        BNE tri

        LDY #$00
      noise:
        TXA
        STA audio::decoder_B + AUDIO::Decoder::registers, Y
        INX
        INY
        CPY #$04
        BNE noise
    .endscope

    LDX #$00
  expected:
    TXA
    STA TEST_EXPECTED,X
    INX
    CPX $10
    BNE expected

    JSR Audio::Init
    LDX #$00
  test_loop:
    LDA call_args,X
    STA r0
    INX
    LDA call_args,X
    STA PLO
    INX
    LDA call_args,X
    STA PHI
    INX
    TXA
    PHA
    JSR Audio::PrepareChannelBuffer
    PLA
    TAX
    CPX #$0C
    BNE test_loop

    LDX #$00
  actual:
    TXA
    PHA
    ASL A
    TAX

    LDA audio::buffer_ch_addr_list,X
    STA PLO
    LDA audio::buffer_ch_addr_list+1,X
    STA PHI

    TXA
    ASL A
    TAX

    LDY #$00
    LDA (PLO),Y
    STA TEST_ACTUAL,X
    INY
    LDA (PLO),Y
    STA TEST_ACTUAL+1,X
    INY
    LDA (PLO),Y
    STA TEST_ACTUAL+2,X
    INY
    LDA (PLO),Y
    STA TEST_ACTUAL+3,X
    INY

    PLA
    TAX
    INX
    CPX #$04
    BNE actual

    SHOW
    RTS
.endproc

.proc Test2PrepareChannelBuffer
    LDA #$00
    STA TEST_EXPECTED
    STA TEST_EXPECTED+1

    JSR Audio::Init
    LDA #AUDIO::CHANNEL_SQ1
    STA r0
    LDA #$00
    STA PLO
    LDA #$00
    STA PHI
    JSR Audio::PrepareChannelBuffer

    LDA audio::buffer_ch_addr_list
    STA TEST_ACTUAL
    LDA audio::buffer_ch_addr_list+1,X
    STA TEST_ACTUAL+1

    SHOW
    RTS
.endproc


.proc RunTests
    TEST TestInit
    TEST TestPlayBGM
    TEST TestPlaySFX0
    TEST TestPlaySFX1
    TEST Test0TrackForChannel
    TEST Test1TrackForChannel
    TEST Test2TrackForChannel
    TEST Test0PrepareChannelBuffer
    TEST Test1PrepareChannelBuffer
    TEST Test2PrepareChannelBuffer
    RTS
.endproc
