;; Sound engine rom locations
.scope audio_rom
  track_prio_list:
    .addr audio_ram::track_bgm ;; Lowest priority
    .addr audio_ram::track_sfx0
    .addr audio_ram::track_sfx1 ;; Highest priority
  decoder_table:
  bgm_decoder_table:
    .addr audio_ram::decoder_0
    .addr audio_ram::decoder_1
    .addr audio_ram::decoder_2
    .addr audio_ram::decoder_3
  sfx0_decoder_table:
    .addr audio_ram::decoder_4
    .addr audio_ram::decoder_5
    .addr audio_ram::decoder_6
    .addr audio_ram::decoder_7
  sfx1_decoder_table:
    .addr audio_ram::decoder_8
    .addr audio_ram::decoder_9
    .addr audio_ram::decoder_A
    .addr audio_ram::decoder_B
  channel_silence_list:
    .byte APU_ENV_SILENCE
    .byte APU_ENV_SILENCE
    .byte APU_TRI_SILENCE
    .byte APU_ENV_SILENCE
  channel_volume_mask_list:
    .byte %00001111
    .byte %00001111
    .byte %01111111
    .byte %00001111
  channel_bitflag_list:
    .byte AUDIO::CHANNEL_SQ1
    .byte AUDIO::CHANNEL_SQ2
    .byte AUDIO::CHANNEL_TRI
    .byte AUDIO::CHANNEL_NOISE

.endscope

;; Sound engine API
.scope Audio
  .proc Init
      ;; Initialize audio engine
      ;; All channels initially disabled
      LDA #$00
      STA audio_ram::apu_flags_buffer

      ;; Set write cache to initial write values
      ;; SQ1 has normal env and special case sweep
      LDX #$00
      LDA #APU_ENV_SILENCE
      STA audio_ram::buffer_ch_cache_list,X
      STA AUDIO::APU_REGISTER_LIST,X
      INX
      LDA #%00001000 ;; needed to hear low notes
      STA audio_ram::buffer_ch_cache_list,X
      STA AUDIO::APU_REGISTER_LIST,X
      INX
      LDA #%00000000
      STA audio_ram::buffer_ch_cache_list,X
      STA AUDIO::APU_REGISTER_LIST,X
      INX
      STA audio_ram::buffer_ch_cache_list,X
      STA AUDIO::APU_REGISTER_LIST,X
      INX

      ;; SQ2 has normal env and special case sweep
      LDA #APU_ENV_SILENCE
      STA audio_ram::buffer_ch_cache_list,X
      STA AUDIO::APU_REGISTER_LIST,X
      INX
      LDA #%00001000 ;; needed to hear low notes
      STA audio_ram::buffer_ch_cache_list,X
      STA AUDIO::APU_REGISTER_LIST,X
      INX
      LDA #%00000000
      STA audio_ram::buffer_ch_cache_list,X
      STA AUDIO::APU_REGISTER_LIST,X
      INX
      STA audio_ram::buffer_ch_cache_list,X
      STA AUDIO::APU_REGISTER_LIST,X
      INX

      ;; TRI has tri env and no sweep
      LDA #APU_TRI_SILENCE
      STA audio_ram::buffer_ch_cache_list,X
      STA AUDIO::APU_REGISTER_LIST,X
      INX
      LDA #%00000000
      STA audio_ram::buffer_ch_cache_list,X
      STA AUDIO::APU_REGISTER_LIST,X
      INX
      STA audio_ram::buffer_ch_cache_list,X
      STA AUDIO::APU_REGISTER_LIST,X
      INX
      STA audio_ram::buffer_ch_cache_list,X
      STA AUDIO::APU_REGISTER_LIST,X
      INX

      ;; NOISE has normal env but no sweep
      LDA #APU_ENV_SILENCE
      STA audio_ram::buffer_ch_cache_list,X
      STA AUDIO::APU_REGISTER_LIST,X
      INX
      LDA #%00000000
      STA audio_ram::buffer_ch_cache_list,X
      STA AUDIO::APU_REGISTER_LIST,X
      INX
      STA audio_ram::buffer_ch_cache_list,X
      STA AUDIO::APU_REGISTER_LIST,X
      INX
      STA audio_ram::buffer_ch_cache_list,X
      STA AUDIO::APU_REGISTER_LIST,X

      ;; Set decoders for tracks
      LDA #<audio_rom::bgm_decoder_table
      STA audio_ram::track_bgm + AUDIO::Track::decoders
      LDA #>audio_rom::bgm_decoder_table
      STA audio_ram::track_bgm + AUDIO::Track::decoders+1

      LDA #<audio_rom::sfx0_decoder_table
      STA audio_ram::track_sfx0 + AUDIO::Track::decoders
      LDA #>audio_rom::sfx0_decoder_table
      STA audio_ram::track_sfx0 + AUDIO::Track::decoders+1

      LDA #<audio_rom::sfx1_decoder_table
      STA audio_ram::track_sfx1 + AUDIO::Track::decoders
      LDA #>audio_rom::sfx1_decoder_table
      STA audio_ram::track_sfx1 + AUDIO::Track::decoders+1

      ;; Initially disabled
      LDA #$FF
      STA audio_ram::disable
      RTS
  .endproc

  .proc Enable
      LDA #$00
      STA audio_ram::disable
      RTS
  .endproc

  ;;;; PlayBGM
  ;; 2-byte stack: 2 args, 0 return
  ;; Initializes the BGM track to a given encoded audio stream
  .proc PlayBGM
      ;; stack frame
      audio_addr_lo = SW_STACK-2
      audio_addr_hi = SW_STACK-1

      ;; Plays an encoded audio stream on the BGM track
      ;; A holds audio byte
      LDA #<audio_ram::track_bgm
      PHA_SP
      LDA #>audio_ram::track_bgm
      PHA_SP
      JSR PlayTrack
      PLN_SP 2
      RTS
  .endproc

  ;;;; PlaySFX0
  ;; 2-byte stack: 2 args, 0 return
  ;; Initializes the SFX0 track (lo prio) to a given encoded audio stream
  .proc PlaySFX0
      ;; stack frame
      audio_addr_lo = SW_STACK-2
      audio_addr_hi = SW_STACK-1

      ;; Plays an encoded audio stream on the sfx0 (lo prio) track
      LDA #<audio_ram::track_sfx0
      PHA_SP
      LDA #>audio_ram::track_sfx0
      PHA_SP
      JSR PlayTrack
      PLN_SP 2

      RTS
  .endproc

  ;;;; PlaySFX1
  ;; 2-byte stack: 2 args, 0 return
  ;; Initializes the SFX1 track (hi prio) to a given encoded audio stream
  .proc PlaySFX1
      ;; stack frame
      audio_addr_lo = SW_STACK-2
      audio_addr_hi = SW_STACK-1

      LDA #<audio_ram::track_sfx1
      PHA_SP
      LDA #>audio_ram::track_sfx1
      PHA_SP
      JSR PlayTrack
      PLN_SP 2

      RTS
  .endproc

  ;;;; PlayTrack
  ;; 4-byte stack: 4 args, 0 return
  ;; Plays the given audio stream on the given track
  .proc PlayTrack
      ;; stack frame
      audio_addr_lo = SW_STACK-4
      audio_addr_hi = SW_STACK-3
      track_addr_lo = SW_STACK-2
      track_addr_hi = SW_STACK-1

      LDX SP
      LDA track_addr_lo,X
      STA PLO
      LDA track_addr_hi,X
      STA PHI

      ;; store audio header
      LDA audio_addr_lo,x
      LDY #AUDIO::Track::audio_header
      STA (PLO),Y
      STA r0

      LDA audio_addr_hi,x
      INY
      STA (PLO),Y
      STA r1

      LDY #AUDIO::Stream::channels
      LDA (r0), Y
      LDY #AUDIO::Track::channels_active
      STA (PLO),Y

      LDA r0
      PHA_SP ;; Audio addr lo
      LDA r1
      PHA_SP ;; Audio addr hi

      LDY #$00
      LDA PLO
      CLC
      ADC #AUDIO::Track::decoders
      STA PLO
      LDA PHI
      ADC #$00
      STA PHI

      LDA (PLO),Y
      TAX
      INY
      LDA (PLO),Y
      STX PLO
      STA PHI

      LDX #$00
    loop:
      TXA
      PHA ;; Preserve X loop counter

      PHA_SP ;; Push x for channel offset
      LDY #$00
      LDA (PLO),Y
      PHA_SP ;; lo-> Decoder
      INY
      LDA (PLO),Y
      PHA_SP ;; hi-> Decoder

      ;; Protect PLO/PHI from clobber
      LDA PHI
      PHA ;; hi-> Track.decoders
      LDA PLO ;; lo-> Track.decoders
      PHA

      ;; Arg0,1 = Audio Addr
      ;; Arg2   = Channel offset (0 = sq1, 1 = sq2, 2 = tri, 3 = noise)
      ;; Arg3,4 = Decoder Addr
      JSR InitializeDecoder
      PLN_SP 3 ;; Preserve Audio addr still

      ;; Restore PLO/PHI from clobber
      PLA ;; lo-> Track.decoders
      CLC
      ADC #$02
      STA PLO
      PLA ;; hi-> Track.decoders
      ADC #$00
      STA PHI

      PLA ;; Loop counter
      TAX
      INX
      CPX #$04
      BNE loop

      PLN_SP 2 ;; Finish using stack
      RTS
  .endproc

  ;;;; InitializeDecoder
  ;; 5-byte stack: 5 args, 0 return
  ;; Puts a decoder into the initial state for an audio stream
  .proc InitializeDecoder
      ;; Stack frame
      audio_lo = SW_STACK-5
      audio_hi = SW_STACK-4
      channel_offset = SW_STACK-3 ;; 0 = sq1, 1 = sq2, 2 = tri, 3 = noise
      decoder_lo = SW_STACK-2
      decoder_hi = SW_STACK-1

      LDX SP
      LDA audio_lo,X
      STA PLO
      LDA audio_hi,X
      STA PHI

      LDA decoder_lo,X
      STA r0
      LDA decoder_hi,X
      STA r1

      LDY #AUDIO::Stream::speed
      LDA (PLO),Y
      .repeat 4
        ASL A ;; Load speed into high 4 bits of speed_x_tick
      .endrepeat
      LDY #AUDIO::Decoder::speed_x_tick
      STA (r0),Y

      LDA channel_offset,X
      ASL A
      CLC
      ADC #AUDIO::Stream::ch0 ;; base of channel addresses
      TAY
      LDA (PLO),Y ;; lo-> ch_x
      TAX
      INY
      LDA (PLO),Y ;; hi-> ch_x
      LDY #AUDIO::Decoder::stream_head
      INY
      STA (r0),Y ;; hi-> stream_head
      DEY
      TXA
      STA (r0),Y ;; lo-> stream_head

      LDX SP
      LDY channel_offset,X
      LDA audio_rom::channel_silence_list,Y ;; Use channel offset to determine silence env type
      LDY #(AUDIO::Decoder::registers + AUDIO::Registers::env)
      STA (r0),Y ;; Write env
      LDA #%00001000 ;; Allow low notes
      LDY #(AUDIO::Decoder::registers + AUDIO::Registers::sweep)
      STA (r0),Y ;; Write sweep
      LDA #%00000000 ;; Null note
      LDY #(AUDIO::Decoder::registers + AUDIO::Registers::note_lo)
      STA (r0),Y ;; Write note_lo
      LDY #(AUDIO::Decoder::registers + AUDIO::Registers::note_hi)
      STA (r0),Y ;; Write note_hi

      LDA #$01
      LDY #AUDIO::Decoder::length
      STA (r0),Y ;; Write length

      LDA #$00
      LDY #AUDIO::Decoder::remaining
      STA (r0),Y ;; Write remaininig

      LDA #$0F
      LDY #AUDIO::Decoder::instr_x_volume
      STA (r0),Y ;; Write instrument index + volume

      RTS
  .endproc

  ;;;; StopBGM
  ;; 0-byte stack: 0 args, 0 return
  ;; Clear the BGM track
  .proc StopBGM
      LDA #<audio_ram::track_bgm
      PHA_SP
      LDA #>audio_ram::track_bgm
      PHA_SP
      JSR StopTrack
      PLN_SP 2
      RTS
  .endproc

  ;;;; StopSFX0
  ;; 0-byte stack: 0 args, 0 return
  ;; Clear the SFX0 track (lo prio)
  .proc StopSFX0
      LDA #<audio_ram::track_sfx0
      PHA_SP
      LDA #>audio_ram::track_sfx0
      PHA_SP
      JSR StopTrack
      PLN_SP 2
      RTS
  .endproc

  ;;;; StopSFX1
  ;; 0-byte stack: 0 args, 0 return
  ;; Clear the SFX1 track (hi prio)
  .proc StopSFX1
      LDA #<audio_ram::track_sfx1
      PHA_SP
      LDA #>audio_ram::track_sfx1
      PHA_SP
      JSR StopTrack
      PLN_SP 2
      RTS
  .endproc

  ;;;; StopTrack
  ;; 2-byte stack: 2 args, 0 return
  ;; Stops the given track
  .proc StopTrack
      ;; stack frame
      track_addr_lo = SW_STACK-2
      track_addr_hi = SW_STACK-1

      LDX SP
      LDA track_addr_lo,X
      STA PLO
      LDA track_addr_hi,X
      STA PHI

      ;; make all channels inactive
      LDA #$00
      LDY #AUDIO::Track::channels_active
      STA (PLO),Y

      RTS
  .endproc

  ;;;; TrackForChannel
  ;; 0-byte stack: 0 args, 0 return
  ;; PRESERVES r0
  ;; Sets P to point to the highest-priority track which uses the channel in r0
  ;; Channel is passed in r0
  ;; Valid channels are AUDIO::CHANNEL_X constants
  .proc TrackForChannel
      ;; local aliases for clarity
      temp0 = PLO
      temp1 = PHI

      LDA r0
      STA r1

      LDA audio_ram::track_bgm + AUDIO::Track::channels_active
      AND r0
      STA temp0
      LDA audio_ram::track_sfx0 + AUDIO::Track::channels_active
      AND r0
      STA temp1
      LDA audio_ram::track_sfx1 + AUDIO::Track::channels_active
      AND r0
      ASL A
      ASL r1
      ORA temp1
      ASL A
      ASL r1
      ORA temp0

      BEQ null ;; When no tracks have this channel active, return the null track
      ;; Otherwise, compare the high bit of the OR'd channels, shifting until
      ;; an active track is found. The active track is given as an offset into the track priority list.
      LDX #$02 ;; Start with highest priority
    loop:
      CMP r1
      BCS end_loop ;; Since A is nonzero, we know one track has this channel active and this branch is eventually taken
      DEX
      ASL A
      JMP loop
    end_loop:
      ;; Multiply X by 2 to index list of addresses
      TXA
      ASL A
      TAX

      LDA audio_rom::track_prio_list, X
      STA PLO
      LDA audio_rom::track_prio_list+1, X
      STA PHI
    done:
      RTS

    null:
      STA PLO
      STA PHI
      RTS
  .endproc

  ;;;; PrepareChannelBuffer
  ;; 0-byte stack: 0 args, 0 return
  ;; Uses the track pointed at by P to buffer data for the channel specified in r0
  ;; Valid channels are AUDIO::CHANNEL_X constants
  .proc PrepareChannelBuffer
      ;; Convert channel flag to offset 0-3
      LDA r0
      LDX #$FF
    loop:
      INX
      LSR A
      BNE loop
      STX r0

      ;; multiply by 2 to index into word-sized addresses
      ASL r0

      ;; If our track is null, write null to the addr list
      LDA PLO
      ORA PHI
      BEQ write

      ;; Otherwise...
      LDY #AUDIO::Track::decoders
      LDA (PLO),Y
      TAX
      INY
      LDA (PLO),Y
      STX PLO
      STA PHI
      ;; PLO/PHI now holds the decoder addr list

      LDY r0 ;; Offset of decoder address
      LDA (PLO),Y ;; Load decoder lo
      CLC
      ADC #AUDIO::Decoder::registers ;; A now holds decoderLo + offset to registers
      TAX
      INY
      LDA (PLO),Y ;; Load decoder hi
      ADC #$00 ;; Include carry from lo+offset if needed
      STA PHI ;; Registers hi
      TXA ;; Registers lo
    write:
      LDY r0
      STA audio_ram::buffer_ch_addr_list,Y
      LDA PHI
      STA audio_ram::buffer_ch_addr_list+1,Y
      RTS
  .endproc

  .proc PlayFrame
      LDA audio_ram::disable
      BNE done
      ;; Do while audio enabled
      ;; Tick
      JSR Tick

      ;; Prepare channel output from the correct priority tracks
      LDX #AUDIO::CHANNEL_SQ1
      STX r0
      JSR TrackForChannel ;; P contains a pointer for the track to play, r0 contains channel flag
      LDA PLO
      ORA PHI
      PHA ;; Preserve for channel enable/disable checking later
      JSR PrepareChannelBuffer

      LDX #AUDIO::CHANNEL_SQ2
      STX r0
      JSR TrackForChannel ;; P contains a pointer for the track to play, r0 contains channel flag
      LDA PLO
      ORA PHI
      PHA ;; Preserve for channel enable/disable checking later
      JSR PrepareChannelBuffer

      LDX #AUDIO::CHANNEL_TRI
      STX r0
      JSR TrackForChannel ;; P contains a pointer for the track to play, r0 contains channel flag
      LDA PLO
      ORA PHI
      PHA ;; Preserve for channel enable/disable checking later
      JSR PrepareChannelBuffer

      LDX #AUDIO::CHANNEL_NOISE
      STX r0
      JSR TrackForChannel ;; P contains a pointer for the track to play, r0 contains channel flag
      LDA PLO
      ORA PHI
      PHA ;; Preserve for channel enable/disable checking later
      JSR PrepareChannelBuffer

      LDA #$00
      STA r0 ;; r0 will hold our apu flags
      LDX #$04
      CLC
    loop:
      PLA
      ADC #$FF ;; Carry is unset if A is 0, set if A is nonzero
      ROL r0 ;; rotate the carry into r0, and clear the carry
      DEX
      BNE loop

      LDA r0
      LDX $00
      STX r0
      CMP audio_ram::apu_flags_buffer
      BEQ @after_cache_write
      ;; Find the rising edge flag bits here to bust their cache
      TAX
      STA r0
      EOR audio_ram::apu_flags_buffer
      AND r0
      STA r0
      STX audio_ram::apu_flags_buffer
      STX APUFLAGS
    @after_cache_write:
      JSR PlayChannels ;; r0 contains the apu flags that are newly-rising, or 0 if the cache is unchanged
    done:
      RTS
  .endproc

  ;;;; PlayChannels
  ;; Copies the decoder registers into a write cache, and writes to the APU on change
  ;; Whenever we transition from volume zero to nonzero, we must 'reload' the length counter by also writing note_hi again.
  ;; Whenever we transition from disabled to enabled, we also reload the length counter
  ;; Expects r0 to contain apu flags that have shifted from disabled->enabled
  .proc PlayChannels
      LDX #$00
      LDA r0
      BEQ loop ;; If none are rising, no checks needed
    bust_rising_cache:
      AND #$01
      BEQ @skip
      LDA #AUDIO::NOTE_HI_CACHE_BUST ;; Chosen to never be a real value for note_hi
      STA audio_ram::buffer_ch_cache_list + AUDIO::Registers::note_hi,X
    @skip:
      LSR r0
      BEQ @done ;; If no more are rising, head to loop
      LDA r0
      .repeat .SIZEOF(AUDIO::Registers)
      INX
      .endrepeat
      CPX #$10
      BNE bust_rising_cache
    @done:

      LDX #$00 ;; Channel index, 0 = sq1, 1 = sq2, 2 = tri, 3 = noise
    loop:
      STX r0

      TXA
      ASL A ;; Addr list is word-sized, so double the channel index to get the channel addr
      TAX

      LDA audio_ram::buffer_ch_addr_list,X
      STA PLO
      LDA audio_ram::buffer_ch_addr_list+1,X
      STA PHI
      ORA PLO
      BEQ next ;; channel is not active when P is null

      TXA
      ASL A ;; Register list entries are 4 bytes, twice as big as addr list entries.
      TAX

      LDY r0 ;; Channel index
      LDA audio_rom::channel_volume_mask_list, Y
      STA r1
      LDA audio_ram::buffer_ch_cache_list,X ;; Last write for env for channel
      AND r1 ;; Mask against volume
      BNE init_inner_loop
      ;; When last write was 0...
      LDY #AUDIO::Registers::env
      LDA (PLO),Y
      LDY #$FF
      AND r1 ;; Mask against volume
      BEQ init_inner_loop
      ;; And next write is not zero...
    @bust_note_hi_cache:
      LDA #AUDIO::NOTE_HI_CACHE_BUST ;; Chosen to never be a real value for note_hi
      STA audio_ram::buffer_ch_cache_list + AUDIO::Registers::note_hi,X
    init_inner_loop:
      LDY #$00 ;; Index into register list
    inner_loop:
      ;; Only write if we differ from the cache
      LDA (PLO),Y
      CMP audio_ram::buffer_ch_cache_list, X
      BEQ @ignore
      STA audio_ram::buffer_ch_cache_list, X
      STA AUDIO::APU_REGISTER_LIST, X
    @ignore:
      INX
      INY
      CPY #$04
      BNE inner_loop

    next:
      LDX r0 ;; Restore addr list counter from outer loop
      INX
      CPX #$04
      BNE loop
    done:

      RTS
  .endproc

  ;; Goes through all track addrs and ticks each track
  .proc Tick
      LDX #$00
    loop:
      LDA audio_rom::track_prio_list,X
      STA PLO
      LDA audio_rom::track_prio_list+1,X
      STA PHI
      TXA
      PHA
      JSR TickTrack
      PLA
      TAX
      INX
      INX
      CPX #$06
      BNE loop
      RTS
  .endproc

  ;;;; TickTrack
  ;; 0-byte stack: 0 args, 0 return
  ;; Decodes the next note for all active channels in the track pointed to by P
  ;; Expects P to point to a track
  .proc TickTrack
      JMP start
    loop_args:
        ;;    X = channel flag      X+1 = decoder offset
        .byte AUDIO::CHANNEL_SQ1,   AUDIO::CHANNEL_SQ1_INDEX
        .byte AUDIO::CHANNEL_SQ2,   AUDIO::CHANNEL_SQ2_INDEX
        .byte AUDIO::CHANNEL_TRI,   AUDIO::CHANNEL_TRI_INDEX
        .byte AUDIO::CHANNEL_NOISE, AUDIO::CHANNEL_NOISE_INDEX
    start:
      LDY #AUDIO::Track::channels_active
      LDA (PLO),Y
      BNE when_active
      RTS ;; Early return when no channels are active
    when_active:
      STA r0 ;; channels_active

      LDA PLO
      PHA ;; Preserve track ptr lo for updating the track channel_active flags after decoding
      LDA PHI
      PHA ;; Preserve track ptr hi for updating the track channel_active flags after decoding

      LDY #AUDIO::Track::audio_header
      LDA (PLO),Y
      PHA_SP ;; Audio header lo
      INY
      LDA (PLO),Y
      PHA_SP ;; Audio header hi

      LDY #AUDIO::Track::decoders
      LDA (PLO),Y
      TAX
      INY
      LDA (PLO),Y
      STX PLO
      STA PHI

      LDY #$00
      STY r1 ;; Used to collect EOFs from the streams, to disable those channels on the track.
    loop:
      TYA
      PHA

      LSR r1 ;; Make room in the high bit for the next return val
      LDA r0 ;; channels_active
      AND loop_args,Y
      BEQ next
      LDA loop_args+1,Y
      PHA_SP ;; Decoder channel offset
      ASL A
      TAY
      LDA (PLO),Y
      PHA_SP ;; Decoder lo
      INY
      LDA (PLO),Y
      PHA_SP ;; Decoder hi
      LDA r1
      PHA_SP ;; Return value for catching EOFs
      LDA r0
      PHA
      LDA PLO
      PHA
      LDA PHI
      PHA
      JSR DecodeStream
      PLA_SP ;; Pull return value
      STA r1 ;; Update r1
      PLA
      STA PHI
      PLA
      STA PLO
      PLA
      STA r0
      PLN_SP 3
    next:
      PLA
      TAY
      INY
      INY
      CPY #$08
      BNE loop
      PLN_SP 2 ;; Clean up stack

      PLA ;; Restore track ptr hi
      STA PHI
      PLA ;; Restore track ptr lo
      STA PLO

      LDA r1 ;; channels_eof
      BEQ done ;; When there are no eofs, we're done
      .repeat 4
        LSR A ;; Line up bits with channels_active
      .endrepeat
      EOR r0 ;; channels_active
      LDY #AUDIO::Track::channels_active
      STA (PLO),Y
    done:
      RTS
  .endproc

  ;;;; DecodeStream
  ;; 6-byte stack: 5 args, 1 return
  ;; Uses the given decoder with the given audio header to decode the next note
  ;; Uses the channel flag to make channel-specific decisions
  ;; The high bit of the return val is 1 on EOF, unchanged otherwise
  .proc DecodeStream
      ;; stack frame
      audio_lo = SW_STACK-6
      audio_hi = SW_STACK-5
      channel_offset = SW_STACK-4 ;; 0=sq1, 1=sq2, 2=tri, 3=noise
      decoder_lo = SW_STACK-3
      decoder_hi = SW_STACK-2
      has_stopped = SW_STACK-1 ;; return val

      LDX SP

      LDA decoder_lo,X
      STA PLO
      LDA decoder_hi,X
      STA PHI

      ;; Tick before anything
      ;; Count down the tick counter, execute and refill on zero
      LDY #AUDIO::Decoder::speed_x_tick
      LDA (PLO),Y
      TAX
      AND #%00001111 ;; Just the tick counter
      BEQ on_tock
      DEX
      TXA
      STA (PLO),Y
      RTS
    on_tock:
      ;; Refill tick counter to speed
      TXA
      .repeat 4
        LSR A
      .endrepeat
      ORA (PLO),Y ;; We know the low 4 bits are 0, so OR works cleanly
      STA (PLO),Y

      ;; Fetch stream head
      LDY #AUDIO::Decoder::stream_head
      LDA (PLO),Y
      STA r0
      INY
      LDA (PLO),Y
      STA r1

    check_remaining:
      ;; Continue playing the previous note if its still held
      LDY #AUDIO::Decoder::remaining
      LDA (PLO),Y
      BNE play_note

      ;; Read from stream head
    read_byte:
      LDY #$00
      LDA (r0),Y

      ;; Increment stream head
      INC r0
      BNE @skip
      INC r1
    @skip:

      TAX ;; For safe-keeping
      SEC
      SBC #$60 ;; Note range is 0-95
      BCS handle_opcode
      ;; Otherwise, undo the subtraction- we have a note

      ;; Write note
      TXA
      ASL A ;; Index into word-sized note table
      TAX
      LDA note_table,X
      LDY #(AUDIO::Decoder::registers + AUDIO::Registers::note_lo)
      STA (PLO),Y
      LDA note_table+1,X
      LDY #(AUDIO::Decoder::registers + AUDIO::Registers::note_hi)
      STA (PLO),Y

      ;; Clear mute on new note
      LDY #AUDIO::Decoder::mute_x_hold_vol
      LDA (PLO),Y
      AND #%01111111
      STA (PLO),Y

    set_length:
      LDY #(AUDIO::Decoder::length)
      LDA (PLO),Y
      LDY #(AUDIO::Decoder::remaining)
      STA (PLO),Y

    play_note:
      ;; Write back new stream head as this is a terminal state
      ;; Also frees up r0/r1 for us
      LDY #AUDIO::Decoder::stream_head
      LDA r0
      STA (PLO),Y
      INY
      LDA r1
      STA (PLO),Y

      .scope Volume
          ;; TODO: Apply volume envelope from instrument
          LDY #AUDIO::Decoder::mute_x_hold_vol
          LDA (PLO),Y
          BMI done ;; muted by silence opcode, skip the volume control
          LDY #AUDIO::Decoder::instr_x_volume
          LDA (PLO), Y
          AND #%00001111
          STA r0
          LDY #(AUDIO::Decoder::registers + AUDIO::Registers::env)
          LDA (PLO),Y
          AND #%11110000
          ORA r0
          STA (PLO),Y
        done:
      .endscope
      ;; Done using remaining and elapsed as indices into instrument envelope
      ;; Decrement remaining
      LDY #AUDIO::Decoder::remaining
      LDA (PLO),Y
      TAX
      DEX
      TXA
      STA (PLO),Y

      JMP done
    handle_opcode:
      ;; A holds the opcode vector table index
      JSR RunOpCode

      ;; Write back new stream head
      LDY #AUDIO::Decoder::stream_head
      LDA r0
      STA (PLO),Y
      INY
      LDA r1
      STA (PLO),Y
    done:
      RTS
  .endproc

  ;; Special case- can't go in audio_rom because it references methods that won't appear until the Audio scope.
  opcode_vector_table:
    ;; 0 = silence
    ;; 1 = stop
    .addr Audio::RunOpCodeSilence-1
    .addr Audio::RunOpCodeStop-1
    .addr Audio::RunOpCodeLength-1
    .addr Audio::RunOpCodeLoop-1
    ;; TODO:
    ;;   2 = set_length(l)
    ;;   3 = set_envelope(e)
    ;;   4 = loop_once
    ;;   5 = loop_n(n)

  ;;;; RunOpCode
  ;; 6-byte stack; 5 args, 1 return
  ;; Looks up the opcode handler from the vector table
  ;; Sets it and jumps to it
  ;; All opcode vectors hold a pointer to the stream head in r0+r1,
  ;; and the same stack frame as DecodeStream
  .proc RunOpCode
      ;; stack frame
      audio_lo = SW_STACK-6
      audio_hi = SW_STACK-5
      channel_offset = SW_STACK-4 ;; 0=sq1, 1=sq2, 2=tri, 3=noise
      decoder_lo = SW_STACK-3
      decoder_hi = SW_STACK-2
      has_stopped = SW_STACK-1 ;; return val

      ;; A contains opcode index. x2 to index into words
      ASL A
      TAX
      LDA opcode_vector_table+1,X
      PHA
      LDA opcode_vector_table,X
      PHA
      RTS
  .endproc

  ;;;; RunOpCodeSilence
  ;; 5-byte stack: 5 args, 0 return
  ;; Writes a 1 to the high bit of mute_x_hold_vol, indicating muted
  ;; Writes volume 0 to the env register
  ;; P is a pointer to the decoder
  ;; r0/r1 contain a pointer to the stream head
  .proc RunOpCodeSilence
      ;; stack frame
      audio_lo = SW_STACK-6
      audio_hi = SW_STACK-5
      channel_offset = SW_STACK-4 ;; 0=sq1, 1=sq2, 2=tri, 3=noise
      decoder_lo = SW_STACK-3
      decoder_hi = SW_STACK-2
      has_stopped = SW_STACK-1 ;; return val

      ;; Write zero volume bit
      LDA #%10000000
      LDY #AUDIO::Decoder::mute_x_hold_vol
      ORA (PLO),Y
      STA (PLO),Y

      ;; Set volume in env to 0
      LDX SP
      LDY #(AUDIO::Decoder::registers + AUDIO::Registers::env)
      LDA channel_offset,X
      TAX
      LDA audio_rom::channel_bitflag_list,X
      CMP #AUDIO::CHANNEL_TRI
      BEQ @when_tri
    @when_non_tri:
      LDA (PLO),Y
      AND #%11110000  ;; Clear volume bits
      JMP @set_env
    @when_tri:
      LDA #%10000000  ;; Clear volume bits
    @set_env:
      STA (PLO),Y

      ;; Dont return to handle_opcode; loop back to set_length and continue
      ;; This treats silence as if it were just another note
      PLA ;; RTS lo
      PLA ;; RTS hi
      LDA #>(Audio::DecodeStream::set_length-1)
      PHA
      LDA #<(Audio::DecodeStream::set_length-1)
      PHA
      RTS

      RTS
  .endproc

  ;;;; RunOpCodeLength
  ;; 5-byte stack: 5 args, 0 return
  ;; Sets the note length going forward by reading the next stream byte
  ;; P is a pointer to the decoder
  ;; r0/r1 contain a pointer to the stream head
  .proc RunOpCodeLength
      ;; stack frame
      audio_lo = SW_STACK-6
      audio_hi = SW_STACK-5
      channel_offset = SW_STACK-4 ;; 0=sq1, 1=sq2, 2=tri, 3=noise
      decoder_lo = SW_STACK-3
      decoder_hi = SW_STACK-2
      has_stopped = SW_STACK-1 ;; return val

      ;; Read length
      LDY #$00
      LDA (r0),Y

      ;; Write length
      LDY #AUDIO::Decoder::length
      STA (PLO),Y

      ;; Increment stream_head
      INC r0
      BNE skip
      INC r1
    skip:

      ;; Dont return to handle_opcode; loop back to read_byte and continue
      PLA ;; RTS lo
      PLA ;; RTS hi
      LDA #>(Audio::DecodeStream::read_byte-1)
      PHA
      LDA #<(Audio::DecodeStream::read_byte-1)
      PHA
      RTS
  .endproc

  ;;;; RunOpCodeStop
  ;; 6-byte stack: 5 args, 1 return
  ;; Decrements the stream head ptr in r0/r1 back to before this byte, and indicates the stream is over by writing 1 to the high bit of the ret val
  ;; P is a pointer to the decoder
  ;; r0/r1 contain a pointer to the stream head
  .proc RunOpCodeStop
      ;; stack frame
      audio_lo = SW_STACK-6
      audio_hi = SW_STACK-5
      channel_offset = SW_STACK-4 ;; 0=sq1, 1=sq2, 2=tri, 3=noise
      decoder_lo = SW_STACK-3
      decoder_hi = SW_STACK-2
      has_stopped = SW_STACK-1 ;; return val

      LDA r0
      BNE @skip
      DEC r1
    @skip:
      DEC r0
      LDX SP
      LDA has_stopped,X
      ORA #%10000000
      STA has_stopped,X
      LDY #AUDIO::Decoder::speed_x_tick
      LDA #%11110000
      AND (PLO),Y
      STA (PLO),Y
      RTS
  .endproc

  ;;;; RunOpCodeLoop
  ;; 5-byte stack: 5 args, 0 return
  ;; Resets the stream header to the beginning
  ;; P is a pointer to the decoder
  ;; r0/r1 contain a pointer to the stream head
  .proc RunOpCodeLoop
      ;; stack frame
      audio_lo = SW_STACK-6
      audio_hi = SW_STACK-5
      channel_offset = SW_STACK-4 ;; 0=sq1, 1=sq2, 2=tri, 3=noise
      decoder_lo = SW_STACK-3
      decoder_hi = SW_STACK-2
      has_stopped = SW_STACK-1 ;; return val

      ;; Reset stream_head
      LDX SP
      LDA audio_lo,X
      STA r0
      LDA audio_hi,X
      STA r1
      LDA channel_offset,X
      ASL A
      CLC
      ADC #AUDIO::Stream::ch0
      TAY
      LDA (r0),Y
      TAX
      INY
      LDA (r0),Y
      STX r0
      STA r1

      ;; Dont return to handle_opcode; loop back to read_byte and continue
      PLA ;; RTS lo
      PLA ;; RTS hi
      LDA #>(Audio::DecodeStream::read_byte-1)
      PHA
      LDA #<(Audio::DecodeStream::read_byte-1)
      PHA
      RTS
  .endproc

  .proc Disable
      LDA #$01
      STA audio_ram::disable
      RTS
  .endproc
.endscope
