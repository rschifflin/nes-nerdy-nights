.include "../defs/nes.def"
.include "../defs/audio.def"
.include "../defs/notes_ntsc.def"
.segment "BSS"
.include "../mem/audio.bss.asm"

.include "harness.asm"
.include "../lib/audio.asm"

note_table:
  .include "../data/notes_ntsc.asm"

.scope streams
  stream0:
    .byte %00001010 ;; Channels Sq2 and Noise
    .byte %00000101 ;; Speed 5
    ;; Four note streams
    .addr stream0_ch0
    .addr stream0_ch1
    .addr stream0_ch2
    .addr stream0_ch3
    ;; Four volume streams
    .addr stream0_vol_ch
    .addr stream0_vol_ch
    .addr stream0_vol_ch
    .addr stream0_vol_ch
    ;; Instrument patterns, omit for now
    .addr stream0_instrument0
  stream0_ch0:
    .repeat 16
      .byte $AA
    .endrepeat
  stream0_ch1:
    .repeat 16
      .byte $BB
    .endrepeat
  stream0_ch2:
    .repeat 16
      .byte $CC
    .endrepeat
  stream0_ch3:
    .repeat 16
      .byte $DD
    .endrepeat
  stream0_vol_ch:
    .byte $FF ;; Hold default volume forever
  stream0_instrument0:
    .byte $0F ;; Sustain loop volume high
.endscope

.proc TestInit
    JMP test
  expected:
    ;; BGM track:
    .byte $00 ;; Channel mask
    .addr $0000 ;; no audio stream
    .addr audio_rom::bgm_decoder_table ;; ptr to decoders

    ;; SFX0 track:
    .byte $00 ;; Channel mask
    .addr $0000 ;; no audio stream
    .addr audio_rom::sfx0_decoder_table ;; ptr to decoders

    ;; SFX1 track:
    .byte $00 ;; Channel mask
    .addr $0000 ;; no audio stream
    .addr audio_rom::sfx1_decoder_table ;; ptr to decoders

    ;; Disable
    .byte $FF
  test:
    JSR Audio::Init

    LDX #$00
  loop:
    LDA expected,X
    STA TEST_EXPECTED,X
    LDA audio_ram::track_bgm,X
    STA TEST_ACTUAL,X
    INX
    CPX #$0F
    BNE loop

    LDA expected,X
    STA TEST_EXPECTED,X
    LDA audio_ram::disable
    STA TEST_ACTUAL,X
    INX

    SHOW
    RTS
.endproc

.proc TestPlayBGM
  JMP test

  expected:
    ;; BGM track
    .byte %00001010 ;; Channel mask
    .addr streams::stream0 ;; ptr to audio stream
    .addr audio_rom::bgm_decoder_table ;; ptr to decoders

    ;; Decoder 0
    .addr streams::stream0_ch0    ;; stream head
    .addr streams::stream0_vol_ch ;; volume head
    .addr streams::stream0_instrument0 ;; instrument
    .byte $30, $08, $00, $00 ;; Default silent registers
    .byte $50 ;; 6 ticks per tock, tick counter begins at 0
    .byte $01 ;; Length counter
    .byte $00 ;; Remaining counter
    .byte $0F ;; Instrument index + volume
    .byte $00 ;; Mute + Hold volume

    ;; Decoder 1
    .addr streams::stream0_ch1    ;; stream head
    .addr streams::stream0_vol_ch ;; volume head
    .addr streams::stream0_instrument0 ;; instrument
    .byte $30, $08, $00, $00 ;; Default silent registers
    .byte $50 ;; 6 ticks per tock, tick counter begins at 0
    .byte $01 ;; Length counter
    .byte $00 ;; Remaining counter
    .byte $0F ;; Instrument index + volume
    .byte $00 ;; Mute + Hold volume

    ;; Decoder 2
    .addr streams::stream0_ch2    ;; stream head
    .addr streams::stream0_vol_ch ;; volume head
    .addr streams::stream0_instrument0 ;; instrument
    .byte $80, $08, $00, $00 ;; Default silent registers
    .byte $50 ;; 6 ticks per tock, tick counter begins at 0
    .byte $01 ;; Length counter
    .byte $00 ;; Remaining counter
    .byte $0F ;; Instrument index + volume
    .byte $00 ;; Mute + Hold volume

    ;; Decoder 3
    .addr streams::stream0_ch3    ;; stream head
    .addr streams::stream0_vol_ch ;; volume head
    .addr streams::stream0_instrument0 ;; instrument
    .byte $30, $00, $00, $00 ;; Default silent registers
    .byte $50 ;; 6 ticks per tock, tick counter begins at 0
    .byte $01 ;; Length counter
    .byte $00 ;; Remaining counter
    .byte $0F ;; Instrument index + volume
    .byte $00 ;; Mute + Hold volume

  test:
    LDX #$00
  loop_expected:
    LDA expected,X
    STA TEST_EXPECTED,X
    INX
    CPX #(.SIZEOF(AUDIO::Track) + (4*.SIZEOF(AUDIO::Decoder)))
    BNE loop_expected

    JSR Audio::Init
    LDA #<streams::stream0
    PHA_SP
    LDA #>streams::stream0
    PHA_SP
    JSR Audio::PlayBGM
    PLN_SP 2

  .scope loop_actual
      LDX #$00
      LDY #$00
    bgm:
      LDA audio_ram::track_bgm, X
      STA TEST_ACTUAL, Y
      INY
      INX
      CPX #.SIZEOF(AUDIO::Track)
      BNE bgm

      LDX #$00
    decoders:
      LDA audio_ram::decoders, X
      STA TEST_ACTUAL, Y
      INY
      INX
      CPX #(4 * .SIZEOF(AUDIO::Decoder))
      BNE decoders
  .endscope

    SHOW
    RTS
.endproc

.proc TestPlaySFX0
    JMP test
  expected:
    ;; SFX0 track
    .byte %00001010 ;; Channel mask
    .addr streams::stream0 ;; ptr to audio stream
    .addr audio_rom::sfx0_decoder_table ;; ptr to decoder

    ;; Decoder 4
    .addr streams::stream0_ch0    ;; stream head
    .addr streams::stream0_vol_ch ;; volume head
    .addr streams::stream0_instrument0 ;; instrument
    .byte $30, $08, $00, $00 ;; Default silent registers
    .byte $50 ;; 6 ticks per tock, tick counter begins at 0
    .byte $01 ;; Length counter
    .byte $00 ;; Remaining counter
    .byte $0F ;; Instrument index + volume
    .byte $00 ;; Mute + Hold volume

    ;; Decoder 5
    .addr streams::stream0_ch1    ;; stream head
    .addr streams::stream0_vol_ch ;; volume head
    .addr streams::stream0_instrument0 ;; instrument
    .byte $30, $08, $00, $00 ;; Default silent registers
    .byte $50 ;; 6 ticks per tock, tick counter begins at 0
    .byte $01 ;; Length counter
    .byte $00 ;; Remaining counter
    .byte $0F ;; Instrument index + volume
    .byte $00 ;; Mute + Hold volume

    ;; Decoder 6
    .addr streams::stream0_ch2    ;; stream head
    .addr streams::stream0_vol_ch ;; volume head
    .addr streams::stream0_instrument0 ;; instrument
    .byte $80, $08, $00, $00 ;; Default silent registers
    .byte $50 ;; 6 ticks per tock, tick counter begins at 0
    .byte $01 ;; Length counter
    .byte $00 ;; Remaining counter
    .byte $0F ;; Instrument index + volume
    .byte $00 ;; Mute + Hold volume

    ;; Decoder 7
    .addr streams::stream0_ch3    ;; stream head
    .addr streams::stream0_vol_ch ;; volume head
    .addr streams::stream0_instrument0 ;; instrument
    .byte $30, $08, $00, $00 ;; Default silent registers
    .byte $50 ;; 6 ticks per tock, tick counter begins at 0
    .byte $01 ;; Length counter
    .byte $00 ;; Remaining counter
    .byte $0F ;; Instrument index + volume
    .byte $00 ;; Mute + Hold volume
  test:
    LDX #$00
  loop_expected:
    LDA expected,X
    STA TEST_EXPECTED,X
    INX
    CPX #(.SIZEOF(AUDIO::Track) + (4*.SIZEOF(AUDIO::Decoder)))
    BNE loop_expected

    JSR Audio::Init
    LDA #<streams::stream0
    PHA_SP
    LDA #>streams::stream0
    PHA_SP
    JSR Audio::PlaySFX0
    PLN_SP 2

  .scope loop_actual
      LDX #$00
      LDY #$00
    sfx0:
      LDA audio_ram::track_sfx0, X
      STA TEST_ACTUAL, Y
      INY
      INX
      CPX #.SIZEOF(AUDIO::Track)
      BNE sfx0

      LDX #$00
    decoders:
      LDA audio_ram::decoder_4, X
      STA TEST_ACTUAL, Y
      INY
      INX
      CPX #(4*.SIZEOF(AUDIO::Decoder))
      BNE decoders
  .endscope

    SHOW
    RTS
.endproc

.proc TestPlaySFX1
    JMP test
  expected:
    ;; SFX1 track (11 bytes):
    .byte %00001010 ;; Channel mask
    .addr streams::stream0 ;; ptr to audio stream
    .addr audio_rom::sfx1_decoder_table ;; ptr to decoder

    ;; Decoder 8
    .addr streams::stream0_ch0    ;; stream head
    .addr streams::stream0_vol_ch ;; volume head
    .addr streams::stream0_instrument0 ;; instrument
    .byte $30, $08, $00, $00 ;; Default silent registers
    .byte $50 ;; 6 ticks per tock, tick counter begins at 0
    .byte $01 ;; Length counter
    .byte $00 ;; Remaining counter
    .byte $0F ;; Instrument index + volume
    .byte $00 ;; Mute + Hold volume

    ;; Decoder 9
    .addr streams::stream0_ch1    ;; stream head
    .addr streams::stream0_vol_ch ;; volume head
    .addr streams::stream0_instrument0 ;; instrument
    .byte $30, $08, $00, $00 ;; Default silent registers
    .byte $50 ;; 6 ticks per tock, tick counter begins at 0
    .byte $01 ;; Length counter
    .byte $00 ;; Remaining counter
    .byte $0F ;; Instrument index + volume
    .byte $00 ;; Mute + Hold volume

    ;; Decoder A
    .addr streams::stream0_ch2    ;; stream head
    .addr streams::stream0_vol_ch ;; volume head
    .addr streams::stream0_instrument0 ;; instrument
    .byte $80, $08, $00, $00 ;; Default silent registers
    .byte $50 ;; 6 ticks per tock, tick counter begins at 0
    .byte $01 ;; Length counter
    .byte $00 ;; Remaining counter
    .byte $0F ;; Instrument index + volume
    .byte $00 ;; Mute + Hold volume

    ;; Decoder B
    .addr streams::stream0_ch3    ;; stream head
    .addr streams::stream0_vol_ch ;; volume head
    .addr streams::stream0_instrument0 ;; instrument
    .byte $30, $08, $00, $00 ;; Default silent registers
    .byte $50 ;; 6 ticks per tock, tick counter begins at 0
    .byte $01 ;; Length counter
    .byte $00 ;; Remaining counter
    .byte $0F ;; Instrument index + volume
    .byte $00 ;; Mute + Hold volume

  test:
    LDX #$00
  loop_expected:
    LDA expected,X
    STA TEST_EXPECTED,X
    INX
    CPX #(.SIZEOF(AUDIO::Track) + (4 * .SIZEOF(AUDIO::Decoder)))
    BNE loop_expected

    JSR Audio::Init
    LDA #<streams::stream0
    PHA_SP
    LDA #>streams::stream0
    PHA_SP
    JSR Audio::PlaySFX1
    PLN_SP 2

  .scope loop_actual
      LDX #$00
      LDY #$00
    sfx1:
      LDA audio_ram::track_sfx1, X
      STA TEST_ACTUAL, Y
      INY
      INX
      CPX #.SIZEOF(AUDIO::Track)
      BNE sfx1

      LDX #$00
    decoders:
      LDA audio_ram::decoder_8, X
      STA TEST_ACTUAL, Y
      INY
      INX
      CPX #(4 * .SIZEOF(AUDIO::Decoder))
      BNE decoders
  .endscope

    SHOW
    RTS
.endproc

.proc Test0TrackForChannel
    LDA #%00001111 ;; All channels active
    STA audio_ram::track_bgm + AUDIO::Track::channels_active
    STA audio_ram::track_sfx0 + AUDIO::Track::channels_active
    STA audio_ram::track_sfx1 + AUDIO::Track::channels_active

    LDX #$00
  expected:
    LDA #<audio_ram::track_sfx1
    STA TEST_EXPECTED,X
    LDA #>audio_ram::track_sfx1
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
    STA audio_ram::track_sfx1 + AUDIO::Track::channels_active

    LDA #%00000110 ;; Middle prio has TRI and SQ2 active
    STA audio_ram::track_sfx0 + AUDIO::Track::channels_active

    LDA #%00000011 ;; Lowest prio has SQ2 and SQ1 active
    STA audio_ram::track_bgm + AUDIO::Track::channels_active

    ;; Expect BGM (lowest prio) to map to sq0
    LDA #<audio_ram::track_bgm
    STA TEST_EXPECTED
    LDA #>audio_ram::track_bgm
    STA TEST_EXPECTED+1

    ;; Expect sfx0 (middle prio) to map to sq1
    LDA #<audio_ram::track_sfx0
    STA TEST_EXPECTED+2
    LDA #>audio_ram::track_sfx0
    STA TEST_EXPECTED+3

    ;; Expect sfx1 (highest prio) to map to tri and noise
    LDA #<audio_ram::track_sfx1
    STA TEST_EXPECTED+4
    STA TEST_EXPECTED+6
    LDA #>audio_ram::track_sfx1
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
    STA audio_ram::track_bgm + AUDIO::Track::channels_active
    STA audio_ram::track_sfx0 + AUDIO::Track::channels_active
    STA audio_ram::track_sfx1 + AUDIO::Track::channels_active

    LDX #$00
  expected:
    LDA #<audio_ram::track_sfx1
    STA TEST_EXPECTED,X
    LDA #>audio_ram::track_sfx1
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
    LDA #<(audio_ram::decoder_0 + AUDIO::Decoder::registers)
    STA TEST_EXPECTED
    LDA #>(audio_ram::decoder_0 + AUDIO::Decoder::registers)
    STA TEST_EXPECTED+1

    JSR Audio::Init
    LDA #AUDIO::CHANNEL_SQ1
    STA r0
    LDA #<audio_ram::track_bgm
    STA PLO
    LDA #>audio_ram::track_bgm
    STA PHI
    JSR Audio::PrepareChannelBuffer

    LDA audio_ram::buffer_ch_addr_list
    STA TEST_ACTUAL
    LDA audio_ram::buffer_ch_addr_list+1
    STA TEST_ACTUAL+1

    SHOW
    RTS
.endproc

.proc Test1PrepareChannelBuffer
    JMP test
  call_args:
    .byte AUDIO::CHANNEL_SQ1
    .addr audio_ram::track_bgm
    .byte AUDIO::CHANNEL_SQ2
    .addr audio_ram::track_sfx0
    .byte AUDIO::CHANNEL_TRI
    .addr audio_ram::track_bgm
    .byte AUDIO::CHANNEL_NOISE
    .addr audio_ram::track_sfx1

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
        STA audio_ram::decoder_0 + AUDIO::Decoder::registers, Y
        INX
        INY
        CPY #$04
        BNE sq1

        LDY #$00
      sq2:
        TXA
        STA audio_ram::decoder_5 + AUDIO::Decoder::registers, Y
        INX
        INY
        CPY #$04
        BNE sq2

        LDY #$00
      tri:
        TXA
        STA audio_ram::decoder_2 + AUDIO::Decoder::registers, Y
        INX
        INY
        CPY #$04
        BNE tri

        LDY #$00
      noise:
        TXA
        STA audio_ram::decoder_B + AUDIO::Decoder::registers, Y
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

    LDA audio_ram::buffer_ch_addr_list,X
    STA PLO
    LDA audio_ram::buffer_ch_addr_list+1,X
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

    LDA audio_ram::buffer_ch_addr_list
    STA TEST_ACTUAL
    LDA audio_ram::buffer_ch_addr_list+1,X
    STA TEST_ACTUAL+1

    SHOW
    RTS
.endproc

.proc TestDecodeStreamTick
  JMP test
  audio_stream:
    .byte %00001111 ;; All channels
    .byte %00000101 ;; Speed 5 aka 24 ticks per beat, 150bpm
    ;; TODO: Combine as in decoders

    .addr stream_ch0
    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore

    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore

    .addr stream_instrument
  stream_ch0:
    .byte $0D ;; Bb octave 1
    .byte $17 ;; G# octave 1
    .byte $1B ;; C octave 2
  stream_ignore:
    .byte $80
  stream_instrument:
    .byte $0F

  test:
    LDA #<audio_stream
    PHA_SP
    LDA #>audio_stream
    PHA_SP
    LDA #AUDIO::CHANNEL_SQ1_INDEX
    PHA_SP
    LDA #<audio_ram::decoder_0
    PHA_SP
    LDA #>audio_ram::decoder_0
    PHA_SP
    JSR Audio::InitializeDecoder

    LDA #$00 ;; Prepare return value, ignored for this test
    PHA_SP
    ;; Initial tick always succeeds
    JSR Audio::DecodeStream

    LDA #<NOTE_B_FLAT_1
    STA TEST_EXPECTED
    LDA #>NOTE_B_FLAT_1
    STA TEST_EXPECTED+1

    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::note_lo
    STA TEST_ACTUAL
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::note_hi
    STA TEST_ACTUAL+1

    SHOW
    INC_TEST_NO

    ;; At speed 5, 6 ticks is needed to advance
    .repeat 5
      JSR Audio::DecodeStream
    .endrepeat
    ;; Should not be enough to advance the stream from note $A0 $A1 to note $B0 $B1

    SHOW
    INC_TEST_NO

    ;; 6 is just enough
    JSR Audio::DecodeStream
    PLN_SP 6

    LDA #<NOTE_G_SHARP_1
    STA TEST_EXPECTED
    LDA #>NOTE_G_SHARP_1
    STA TEST_EXPECTED+1

    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::note_lo
    STA TEST_ACTUAL
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::note_hi
    STA TEST_ACTUAL+1

    SHOW

    RTS
.endproc

.proc TestDecodeStreamStop
  JMP test
  audio_stream:
    .byte %00001111 ;; All channels
    .byte %00000101 ;; Speed 5 aka 24 ticks per beat, 150bpm
    ;; .repeat n .byte envelopes?
    ;; .repeat n .byte frames?

    .addr stream_ch0
    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore

    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore

    .addr stream_instrument
  stream_ch0:
    .byte $0D ;; Bb octave 1
    .byte $17 ;; G# octave 1
    .byte $1B ;; C octave 2
    .byte AUDIO::OP_CODES::STOP
    .byte $1B ;; notes past stop; should never be played
    .byte $17 ;; notes past stop; should never be played
    .byte $0D ;; notes past stop; should never be played
  stream_ignore:
    .byte $FF
  stream_instrument:
    .byte $0F

  test:
    LDA #<audio_stream
    PHA_SP
    LDA #>audio_stream
    PHA_SP
    LDA #AUDIO::CHANNEL_SQ1_INDEX
    PHA_SP
    LDA #<audio_ram::decoder_0
    PHA_SP
    LDA #>audio_ram::decoder_0
    PHA_SP
    JSR Audio::InitializeDecoder

    LDA #$00 ;; Prepare return value
    PHA_SP
    ;; Initial tick always succeeds
    JSR Audio::DecodeStream
    .repeat 17
      JSR Audio::DecodeStream
    .endrepeat
    ;; Should not be enough to advance the stream to the finish
    LDA #$00 ;; Indicates not finished
    STA TEST_EXPECTED
    PLA_SP ;; Pull return val
    STA TEST_ACTUAL

    SHOW
    INC_TEST_NO

    ;; One more should finish the stream
    LDA #%01111111 ;; Clean high bit for the return val
    PHA_SP
    JSR Audio::DecodeStream
    LDA #$FF ;; High bit set indicates stream finished
    STA TEST_EXPECTED
    PLA_SP ;; Pull return val
    STA TEST_ACTUAL

    SHOW
    INC_TEST_NO

    ;; Every future decode step now just loops forever on finish
    LDA #$00 ;; Clean return val
    PHA_SP
    .repeat 10
      JSR Audio::DecodeStream
    .endrepeat
    PLA_SP

    LDA #%00110011 ;; Clean high bit for the return val
    PHA_SP
    JSR Audio::DecodeStream
    LDA #%10110011 ;; Expect high bit now set after decode step
    STA TEST_EXPECTED
    PLA_SP ;; Pull return val
    STA TEST_ACTUAL

    SHOW

    PLN_SP 5
    RTS
.endproc

.proc TestDecodeStreamSilence
  JMP test
  audio_stream:
    .byte %00000001 ;; Sq1 channel
    .byte %00000101 ;; Speed 5 aka 24 ticks per beat, 150bpm
    ;; .repeat n .byte envelopes?
    ;; .repeat n .byte frames?

    .addr stream_ch0
    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore

    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore

    .addr stream_instrument
  stream_ch0:
    .byte $0D ;; Bb octave 1
    .byte AUDIO::OP_CODES::SILENCE
    .byte $1B ;; C octave 2
  stream_ignore:
    .byte AUDIO::VOLUME_HOLD_FOREVER
  stream_instrument:
    .byte $0F

  test:
    LDA #<audio_stream
    PHA_SP
    LDA #>audio_stream
    PHA_SP
    LDA #AUDIO::CHANNEL_SQ1_INDEX
    PHA_SP
    LDA #<audio_ram::decoder_0
    PHA_SP
    LDA #>audio_ram::decoder_0
    PHA_SP
    JSR Audio::InitializeDecoder

    LDA #$00 ;; Prepare return value, ignore for this test
    PHA_SP
    ;; Initial tick always succeeds
    JSR Audio::DecodeStream
    .repeat 5
      JSR Audio::DecodeStream
    .endrepeat

    ;; Should not be enough to advance the stream to silence
    LDA #%00111111 ;; Expect volume to stay high
    STA TEST_EXPECTED
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::env
    STA TEST_ACTUAL

    SHOW
    INC_TEST_NO

    ;; One more should read the silence note and quiet the stream
    JSR Audio::DecodeStream
    LDA #%00110000 ;; Expect volume to be muted
    STA TEST_EXPECTED
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::env
    STA TEST_ACTUAL

    SHOW
    INC_TEST_NO

    ;; Next note unmutes again
    .repeat 6
      JSR Audio::DecodeStream
    .endrepeat
    LDA #%00111111 ;; Expect volume to be high again
    STA TEST_EXPECTED
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::env
    STA TEST_ACTUAL

    SHOW

    PLN_SP 6
    RTS
.endproc

.proc TestDecodeStreamLength
  JMP test
  audio_stream:
    .byte %00000001 ;; Sq1 channel
    .byte %00000101 ;; Speed 5 aka 24 ticks per beat, 150bpm
    ;; .repeat n .byte envelopes?
    ;; .repeat n .byte frames?

    .addr stream_ch0
    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore

    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore

    .addr stream_instrument
  stream_ch0:
    .byte $0D ;; Bb octave 1
    .byte AUDIO::OP_CODES::LENGTH, $04 ;; Length 4
    .byte $3f ;; C octave 5
    .byte $0D ;; Bb octave 1
  stream_ignore:
    .byte AUDIO::VOLUME_HOLD_FOREVER
  stream_instrument:
    .byte $0F

  test:
    LDA #<audio_stream
    PHA_SP
    LDA #>audio_stream
    PHA_SP
    LDA #AUDIO::CHANNEL_SQ1_INDEX
    PHA_SP
    LDA #<audio_ram::decoder_0
    PHA_SP
    LDA #>audio_ram::decoder_0
    PHA_SP
    JSR Audio::InitializeDecoder
    LDA #$00 ;; Prepare return value, ignore for this test
    PHA_SP

    ;; Initial tick always succeeds
    JSR Audio::DecodeStream
    .repeat 6
     JSR Audio::DecodeStream
   .endrepeat

    LDA #$04
    STA TEST_EXPECTED ;; New length
    LDA #<NOTE_C_5
    STA TEST_EXPECTED+1 ;; Next note_lo
    LDA #>NOTE_C_5
    STA TEST_EXPECTED+2 ;; Next note_hi

    LDA #$03
    STA TEST_EXPECTED+3 ;; New remaining, since we played 1 frame of next note

    LDA #<(stream_ch0+4) ;; Shouldve read initial note, length op, length val, new note for +4
    STA TEST_EXPECTED+4 ;; New stream head lo
    LDA #>(stream_ch0+4) ;; Shouldve read initial note, length op, length val, new note for +4
    STA TEST_EXPECTED+5 ;; New stream head hi

    LDA audio_ram::decoder_0 + AUDIO::Decoder::length
    STA TEST_ACTUAL
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::note_lo
    STA TEST_ACTUAL+1
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::note_hi
    STA TEST_ACTUAL+2
    LDA audio_ram::decoder_0 + AUDIO::Decoder::remaining
    STA TEST_ACTUAL+3
    LDA audio_ram::decoder_0 + AUDIO::Decoder::stream_head
    STA TEST_ACTUAL+4
    LDA audio_ram::decoder_0 + AUDIO::Decoder::stream_head + 1
    STA TEST_ACTUAL+5

    SHOW
    INC_TEST_NO

    .repeat 6
      JSR Audio::DecodeStream
    .endrepeat

    LDA #$02
    STA TEST_EXPECTED+3 ;; New remaining, since we played 2 frames of next note

    LDA audio_ram::decoder_0 + AUDIO::Decoder::remaining
    STA TEST_ACTUAL+3

    SHOW
    INC_TEST_NO

    .repeat 18
      JSR Audio::DecodeStream
    .endrepeat

    LDA #<NOTE_B_FLAT_1
    STA TEST_EXPECTED+1 ;; new note_lo
    LDA #>NOTE_B_FLAT_1
    STA TEST_EXPECTED+2 ;; new note_hi
    LDA #$03
    STA TEST_EXPECTED+3 ;; New remaining, since we played 3 frames of new note
    LDA #<(stream_ch0+5) ;; Shouldve read initial note, length op, length val, newer note for +5
    STA TEST_EXPECTED+4 ;; New stream head lo
    LDA #>(stream_ch0+4) ;; Shouldve read initial note, length op, length val, newer note for +5
    STA TEST_EXPECTED+5 ;; New stream head hi

    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::note_lo
    STA TEST_ACTUAL+1 ;; new note_lo
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::note_hi
    STA TEST_ACTUAL+2 ;; new note_hi
    LDA audio_ram::decoder_0 + AUDIO::Decoder::remaining
    STA TEST_ACTUAL+3
    LDA audio_ram::decoder_0 + AUDIO::Decoder::stream_head
    STA TEST_ACTUAL+4
    LDA audio_ram::decoder_0 + AUDIO::Decoder::stream_head + 1
    STA TEST_ACTUAL+5

    SHOW

    PLN_SP 6
    RTS
.endproc

.proc TestDecodeStreamLoop
  JMP test
  audio_stream:
    .byte %00001111 ;; All channels
    .byte %00000101 ;; Speed 5 aka 24 ticks per beat, 150bpm

    .addr stream_ch0
    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore

    .addr stream_volume
    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore

    .addr stream_instrument
  stream_ch0:
    .byte $0D ;; Bb octave 1
    .byte $3f ;; C octave 5
    .byte $17 ;; G# octave 1
    .byte AUDIO::OP_CODES::LOOP
  stream_volume:
    .byte $0A
    .byte $0B
    .byte AUDIO::VOLUME_HOLD_FOREVER
  stream_ignore:
    .byte AUDIO::VOLUME_HOLD_FOREVER
  stream_instrument:
    .byte $0F

  test:
    LDA #<audio_stream
    PHA_SP
    LDA #>audio_stream
    PHA_SP
    LDA #AUDIO::CHANNEL_SQ1_INDEX
    PHA_SP
    LDA #<audio_ram::decoder_0
    PHA_SP
    LDA #>audio_ram::decoder_0
    PHA_SP
    JSR Audio::InitializeDecoder
    LDA #$00 ;; Prepare return value, ignore for this test
    PHA_SP

    ;; Initial tick always succeeds
    JSR Audio::DecodeStream

    .repeat 18
      JSR Audio::DecodeStream
    .endrepeat

    LDA #<NOTE_B_FLAT_1
    STA TEST_EXPECTED ;; Next note_lo
    LDA #>NOTE_B_FLAT_1
    STA TEST_EXPECTED+1 ;; Next note_hi

    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::note_lo
    STA TEST_ACTUAL
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::note_hi
    STA TEST_ACTUAL+1

    SHOW
    INC_TEST_NO

    .repeat 186 ;; cycle 31 times, % 3 = 1, so advance 1 note
      JSR Audio::DecodeStream
    .endrepeat

    LDA #<NOTE_C_5
    STA TEST_EXPECTED ;; Next note_lo
    LDA #>NOTE_C_5
    STA TEST_EXPECTED+1 ;; Next note_hi

    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::note_lo
    STA TEST_ACTUAL
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::note_hi
    STA TEST_ACTUAL+1

    SHOW
    INC_TEST_NO

    .repeat 12 ;; cycle 2 more times to wrap to the start
      JSR Audio::DecodeStream
    .endrepeat

    LDA #<NOTE_B_FLAT_1
    STA TEST_EXPECTED ;; Next note_lo
    LDA #>NOTE_B_FLAT_1
    STA TEST_EXPECTED+1 ;; Next note_hi
    LDA #$0A
    STA TEST_EXPECTED+2 ;; Current volume should be reset

    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::note_lo
    STA TEST_ACTUAL
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::note_hi
    STA TEST_ACTUAL+1

    LDA audio_ram::decoder_0 + AUDIO::Decoder::instr_x_volume
    AND #%00001111
    STA TEST_ACTUAL+2

    SHOW

    PLN_SP 6
    RTS
.endproc

.proc TestDecodeStreamVolume
  JMP test
  audio_stream:
    .byte %00001111 ;; All channels
    .byte %00000101 ;; Speed 5 aka 24 ticks per beat, 150bpm

    .addr stream_ch0
    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore

    .addr stream_vol0
    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore

    .addr stream_instrument
  stream_ch0:
    .byte AUDIO::OP_CODES::LENGTH, $FF ;; Hold for 256 beats
    .byte $0D ;; Bb octave 1
  stream_vol0:
    .byte $0A ;; Volume 10
    .byte $0F ;; Volume 15
    .byte $83 ;; Hold same volume for 3 more frames
    .byte $04 ;; Volume 4
    .byte AUDIO::VOLUME_HOLD_FOREVER
    .byte $07 ;; Volume 7
  stream_ignore:
    .byte AUDIO::VOLUME_HOLD_FOREVER
  stream_instrument:
    .byte $0F

  test:
    LDA #<audio_stream
    PHA_SP
    LDA #>audio_stream
    PHA_SP
    LDA #AUDIO::CHANNEL_SQ1_INDEX
    PHA_SP
    LDA #<audio_ram::decoder_0
    PHA_SP
    LDA #>audio_ram::decoder_0
    PHA_SP
    JSR Audio::InitializeDecoder
    LDA #$00 ;; Prepare return value, ignore for this test
    PHA_SP

    ;; Initial tick always succeeds
    JSR Audio::DecodeStream

    LDA #$0A
    STA TEST_EXPECTED ;; Initial volume 0A
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::env
    AND #%00001111
    STA TEST_ACTUAL

    SHOW
    INC_TEST_NO

   .repeat 6
     JSR Audio::DecodeStream
   .endrepeat

    LDA #$0F
    STA TEST_EXPECTED ;; New volume 0F
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::env
    AND #%00001111
    STA TEST_ACTUAL

    SHOW
    INC_TEST_NO

    .repeat 18
      JSR Audio::DecodeStream
    .endrepeat

    ;; Still holding the same volume. Initial value frame, plus 3 hold frames
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::env
    AND #%00001111
    STA TEST_ACTUAL

    SHOW
    INC_TEST_NO

    .repeat 6
      JSR Audio::DecodeStream
    .endrepeat

    LDA #$04
    STA TEST_EXPECTED ;; New volume 04
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::env
    AND #%00001111
    STA TEST_ACTUAL

    SHOW
    INC_TEST_NO

    .repeat 30
      JSR Audio::DecodeStream
    .endrepeat

    ;; We hold volume 4 forever
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::env
    AND #%00001111
    STA TEST_ACTUAL

    SHOW

    PLN_SP 6
    RTS
.endproc

.proc TestDecodeStreamInstrumentPattern1
  JMP test
  audio_stream:
    .byte %00001111 ;; All channels
    .byte %00000101 ;; Speed 5 aka 24 ticks per beat, 150bpm

    .addr stream_ch0
    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore

    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore

    .addr stream_instrument
  stream_ch0:
    .byte AUDIO::OP_CODES::LENGTH, $FF ;; Hold future notes for 256 beats
    .byte $0D ;; Bb octave 1
  stream_ignore:
    .byte AUDIO::VOLUME_HOLD_FOREVER
  stream_instrument:
    .byte $1A
    .byte $2A
    .byte $3A
    .byte $4E
    .byte $59
    .byte $63
    .byte $72
    .byte $71

  test:
    LDA #<audio_stream
    PHA_SP
    LDA #>audio_stream
    PHA_SP
    LDA #AUDIO::CHANNEL_SQ1_INDEX
    PHA_SP
    LDA #<audio_ram::decoder_0
    PHA_SP
    LDA #>audio_ram::decoder_0
    PHA_SP
    JSR Audio::InitializeDecoder
    LDA #$00 ;; Prepare return value, ignore for this test
    PHA_SP

    ;; Initial tick always succeeds
    JSR Audio::DecodeStream

    LDA #$0A
    STA TEST_EXPECTED ;; Initial volume 0A
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::env
    AND #%00001111
    STA TEST_ACTUAL

    SHOW
    INC_TEST_NO

    ;; Advance 3 bytes in the pattern
   .repeat 18
     JSR Audio::DecodeStream
   .endrepeat

    LDA #$0E
    STA TEST_EXPECTED ;; New volume 0E
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::env
    AND #%00001111
    STA TEST_ACTUAL

    SHOW
    INC_TEST_NO

    ;; Advance 5 more bytes in the pattern
    .repeat 30
      JSR Audio::DecodeStream
    .endrepeat

    LDA #$01
    STA TEST_EXPECTED ;; New volume 01
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::env
    AND #%00001111
    STA TEST_ACTUAL

    SHOW
    INC_TEST_NO

    ;; Pattern says to loop on the final byte
    .repeat 18
      JSR Audio::DecodeStream
    .endrepeat

    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::env
    AND #%00001111
    STA TEST_ACTUAL


    SHOW

    PLN_SP 6
    RTS
.endproc

.proc TestDecodeStreamInstrument
  JMP test
  audio_stream:
    .byte %00001111 ;; All channels
    .byte %00000101 ;; Speed 5 aka 24 ticks per beat, 150bpm

    .addr stream_ch0
    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore
    ;;;;
    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore
    .addr stream_ignore
    ;;;;
    .addr stream_instrument0
    .addr stream_instrument1
  stream_ch0:
    .byte $0D ;; Bb octave 1
    .byte AUDIO::OP_CODES::LENGTH, $02
    .byte AUDIO::OP_CODES::INSTRUMENT, $00 ;; instrument 1
    .byte $0D ;; Bb octave 1
    .byte AUDIO::OP_CODES::INSTRUMENT, $01 ;; instrument 1
    .byte $0D ;; Bb octave 1
    .byte $0D ;; Bb octave 1
    .byte AUDIO::OP_CODES::LOOP

  stream_ignore:
    .byte AUDIO::VOLUME_HOLD_FOREVER
  stream_instrument0:
    .byte $1A
    .byte $2B
    .byte $3C
    .byte $0D
  stream_instrument1:
    .byte $13
    .byte $24
    .byte $35
    .byte $06

  test:
    LDA #<audio_stream
    PHA_SP
    LDA #>audio_stream
    PHA_SP
    LDA #AUDIO::CHANNEL_SQ1_INDEX
    PHA_SP
    LDA #<audio_ram::decoder_0
    PHA_SP
    LDA #>audio_ram::decoder_0
    PHA_SP
    JSR Audio::InitializeDecoder
    LDA #$00 ;; Prepare return value, ignore for this test
    PHA_SP

    ;; Initial tick always succeeds
    JSR Audio::DecodeStream
    .repeat 18
      JSR Audio::DecodeStream
    .endrepeat

    LDA #$03
    STA TEST_EXPECTED ;; Instrument 1 volume

    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::env
    AND #%00001111
    STA TEST_ACTUAL

    SHOW
    INC_TEST_NO

    ;; Play another note without setting the instrument;
    ;; Should still reset the pattern index
    .repeat 12
      JSR Audio::DecodeStream
    .endrepeat

    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::env
    AND #%00001111
    STA TEST_ACTUAL

    SHOW
    INC_TEST_NO

    ;; Audio loops
    ;; Should reset the instrument to 0 and pattern to 0
    .repeat 12
      JSR Audio::DecodeStream
    .endrepeat

    LDA #$0A
    STA TEST_EXPECTED ;; Instrument 0 volume
    LDA audio_ram::decoder_0 + AUDIO::Decoder::registers + AUDIO::Registers::env
    AND #%00001111
    STA TEST_ACTUAL

    SHOW

    PLN_SP 6
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
    TEST TestDecodeStreamTick
    TEST TestDecodeStreamStop
    TEST TestDecodeStreamSilence
    TEST TestDecodeStreamLength
    TEST TestDecodeStreamLoop
    TEST TestDecodeStreamVolume
    TEST TestDecodeStreamInstrumentPattern1
    TEST TestDecodeStreamInstrument
    RTS
.endproc
