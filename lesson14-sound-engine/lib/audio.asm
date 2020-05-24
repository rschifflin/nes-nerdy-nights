;; Sound engine API
.scope Audio
  .linecont +

  track_prio_list:
    .addr audio::track_bgm ;; Lowest priority
    .addr audio::track_sfx0
    .addr audio::track_sfx1 ;; Highest priority

  channel_silence_list:
    .byte APU_ENV_SILENCE
    .byte APU_ENV_SILENCE
    .byte APU_TRI_SILENCE
    .byte APU_ENV_SILENCE

  .proc Init
      ;; Initialize audio engine

      ;; Set decoders for tracks
      LDA #<audio::decoders
      STA PLO
      LDA #>audio::decoders
      STA PHI

      LDX #$00
    loop_bgm:
      LDA PLO
      STA audio::track_bgm + AUDIO::Track::sq1, X
      CLC
      ADC #.SIZEOF(AUDIO::Decoder)
      STA PLO

      LDA PHI
      STA audio::track_bgm + AUDIO::Track::sq1 + 1, X
      ADC #$00
      STA PHI
      INX
      INX
      CPX #$08
      BNE loop_bgm

      LDX #$00
    loop_sfx0:
      LDA PLO
      STA audio::track_sfx0 + AUDIO::Track::sq1, X
      CLC
      ADC #.SIZEOF(AUDIO::Decoder)
      STA PLO

      LDA PHI
      STA audio::track_sfx0 + AUDIO::Track::sq1 + 1, X
      ADC #$00
      STA PHI
      INX
      INX
      CPX #$08
      BNE loop_sfx0

      LDX #$00
    loop_sfx1:
      LDA PLO
      STA audio::track_sfx1 + AUDIO::Track::sq1, X
      CLC
      ADC #.SIZEOF(AUDIO::Decoder)
      STA PLO

      LDA PHI
      STA audio::track_sfx1 + AUDIO::Track::sq1 + 1, X
      ADC #$00
      STA PHI
      INX
      INX
      CPX #$08
      BNE loop_sfx1

      JMP Enable
  .endproc

  .proc Enable
      LDA #APU_FLAGS_SQ1_ENABLE  | \
           APU_FLAGS_SQ2_ENABLE | \
           APU_FLAGS_TRI_ENABLE | \
           APU_FLAGS_NOISE_ENABLE
      STA APUFLAGS

      LDA #APU_ENV_SILENCE
      STA APU_SQ1_ENV
      STA APU_SQ2_ENV
      STA APU_NOISE_ENV

      LDA #APU_TRI_SILENCE
      STA APU_TRI_CTRL

      LDA #$00
      STA audio::disable
      LDA #$01
      STA audio::force_write
      RTS
  .endproc

  .proc LoadAudio
      ;; Takes a memory address in P holding an encoded audio stream and adds it to the audio list
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
      LDA #<audio::track_bgm
      PHA_SP
      LDA #>audio::track_bgm
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
      LDA #<audio::track_sfx0
      PHA_SP
      LDA #>audio::track_sfx0
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

      LDA #<audio::track_sfx1
      PHA_SP
      LDA #>audio::track_sfx1
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

      LDA PLO
      CLC
      ADC #AUDIO::Track::sq1
      STA PLO
      LDA PHI
      ADC #$00
      STA PHI

      LDX #$00
    loop:
      TXA
      PHA ;; Preserve X loop counter

      PHA_SP ;; Push x for ch offset
      LDY #$00
      LDA (PLO),Y
      PHA_SP ;; lo-> Decoder
      INY
      LDA (PLO),Y
      PHA_SP ;; hi-> Decoder

      ;; Protect PLO/PHI from clobber
      LDA PHI
      PHA ;; hi-> Track.chan
      LDA PLO ;; lo-> Track.chan
      PHA

      ;; Arg0,1 = Audio Addr
      ;; Arg2   = Channel offset (0 = sq1, 1 = sq2, 2 = tri, 3 = noise)
      ;; Arg3,4 = Decoder Addr
      JSR InitializeDecoder
      PLN_SP 3 ;; Preserve Audio addr still

      ;; Restore PLO/PHI from clobber
      PLA ;; lo-> Track.chan
      CLC
      ADC #$02
      STA PLO
      PLA ;; hi-> Track.chan
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

      LDY #AUDIO::Stream::spempo
      LDA (PLO),Y

      LDY #AUDIO::Decoder::spempo
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
      LDA channel_silence_list,Y ;; Use channel offset to determine silence env type
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
      RTS
  .endproc

  ;;;; StopBGM
  ;; 0-byte stack: 0 args, 0 return
  ;; Clear the BGM track
  .proc StopBGM
      LDA #<audio::track_bgm
      PHA_SP
      LDA #>audio::track_bgm
      PHA_SP
      JSR StopTrack
      PLN_SP 2
      RTS
  .endproc

  ;;;; StopSFX0
  ;; 0-byte stack: 0 args, 0 return
  ;; Clear the SFX0 track (lo prio)
  .proc StopSFX0
      LDA #<audio::track_sfx0
      PHA_SP
      LDA #>audio::track_sfx0
      PHA_SP
      JSR StopTrack
      PLN_SP 2
      RTS
  .endproc

  ;;;; StopSFX1
  ;; 0-byte stack: 0 args, 0 return
  ;; Clear the SFX1 track (hi prio)
  .proc StopSFX1
      LDA #<audio::track_sfx1
      PHA_SP
      LDA #>audio::track_sfx1
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

      LDA audio::track_bgm + AUDIO::Track::channels_active
      AND r0
      STA temp0
      LDA audio::track_sfx0 + AUDIO::Track::channels_active
      AND r0
      STA temp1
      LDA audio::track_sfx1 + AUDIO::Track::channels_active
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

      LDA track_prio_list, X
      STA PLO
      LDA track_prio_list+1, X
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
      LDA #AUDIO::Track::sq1
      CLC
      ADC r0 ;; Offset of decoder address
      TAY
      LDA (PLO),Y ;; Load decoder lo
      CLC
      ADC #AUDIO::Decoder::registers ;; A now holds decoderLo + offset to registers
      PHA ;; Can't store yet, still using PLO/PHI to point to decoder data
      INY
      LDA (PLO),Y ;; Load decoder hi
      ADC #$00 ;; Include carry from lo+offset if needed
      STA PHI
      PLA ;; Registers lo
    write:
      LDX r0
      STA audio::buffer_ch_addr_list,X
      LDA PHI ;; Registers hi
      STA audio::buffer_ch_addr_list+1,X
      RTS
  .endproc

  .proc PlayFrame
      LDA audio::disable
      BNE done
      ;; Do while audio enabled
      ;; Tick
      JSR Tick

      ;; Prepare channel output from the correct priority tracks
      LDX #AUDIO::CHANNEL_SQ1
      STX r0
      JSR TrackForChannel ;; P contains a pointer for the track to play, r0 contains channel flag
      JSR PrepareChannelBuffer

      LDX #AUDIO::CHANNEL_SQ2
      STX r0
      JSR TrackForChannel ;; P contains a pointer for the track to play, r0 contains channel flag
      JSR PrepareChannelBuffer

      LDX #AUDIO::CHANNEL_TRI
      STX r0
      JSR TrackForChannel ;; P contains a pointer for the track to play, r0 contains channel flag
      JSR PrepareChannelBuffer

      LDX #AUDIO::CHANNEL_NOISE
      STX r0
      JSR TrackForChannel ;; P contains a pointer for the track to play, r0 contains channel flag
      JSR PrepareChannelBuffer

      ;; Write to APU
      JSR PlayChannels
    done:
      RTS
  .endproc

  .proc PlayChannels
      LDX #$00 ;; Index into channel buffer address list, incremented by 2
    loop:
      LDA audio::buffer_ch_addr_list,X
      STA PLO
      LDA audio::buffer_ch_addr_list+1,X
      STA PHI

      TXA
      STA r0 ;; Preserve addr list counter for after the inner loop
      ASL A ;; Register list entries are 4 bytes, twice as big as addr list entries.
            ;; So we multiply our addr list offset by 2
      TAX

      LDA PLO
      ORA PHI
      BNE non_null_case ;; silence channel when P is null
    null_case:
      LDA r0 ;; Silence list entries are 1 byte, twice as small as addr list entries.
      LSR A  ;; So we divide by 2
      TAY
      LDA channel_silence_list,Y
      CMP audio::buffer_ch_write_list, X
      BEQ @ignore
      STA audio::buffer_ch_write_list, X
      STA AUDIO::APU_REGISTER_LIST, X
    @ignore:
      JMP next

    non_null_case:
      LDY #$00 ;; Index into register list
    inner_loop:
      ;; If force_write is set, always write
      LDA audio::force_write
      BNE @force_write

      ;; Else, only write if we differ from the cache
      LDA (PLO),Y
      CMP audio::buffer_ch_write_list, X
      BEQ @ignore
      JMP @write
    @force_write:
      LDA (PLO),Y
    @write:
      STA audio::buffer_ch_write_list, X
      ;; TODO: Apply dynamic channel env (volume, duty, etc)
      STA AUDIO::APU_REGISTER_LIST, X
    @ignore:
      INX
      INY
      CPY #$04
      BNE inner_loop

    next:
      LDX r0 ;; Restore addr list counter from outer loop
      INX    ;; Addr lists are word-sized, so inc by 2
      INX
      CPX #$08
      BNE loop

      LDA #$00
      STA audio::force_write
      RTS

  .endproc

  ;; Goes through all track addrs and ticks each track
  .proc Tick
      LDX #$00
    loop:
      LDA track_prio_list,X
      STA PLO
      LDA track_prio_list+1,X
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
      LDY #AUDIO::Track::channels_active
      LDA (PLO),Y
      BEQ done ;; No channels active
      PHA ;; Preserve for later

      LDY #AUDIO::Track::audio_header
      LDA (PLO),Y
      PHA_SP ;; Audio header lo
      INY
      LDA (PLO),Y
      PHA_SP ;; Audio header hi

      PLA ;; Restore
      AND #AUDIO::CHANNEL_SQ1

      BEQ done_sq1
      LDY #AUDIO::Track::sq1
      LDA (PLO),Y
      PHA_SP ;; Decoder lo
      INY
      LDA (PLO),Y
      PHA_SP ;; Decoder hi
      JSR DecodeStream
      PLN_SP 2

      ;LDA #audio::track_bgm + AUDIO::Track::channels_active
    done_sq1:

      ;BIT #AUDIO::CHANNEL_SQ2
      ;BEQ done_sq2
      ;; Run square 2 channel
      ;; ...
      ;LDA #audio::track_bgm + AUDIO::Track::channels_active
    done_sq2:

      ;BIT #AUDIO::CHANNEL_TRI
      ;BEQ done_tri
      ;; Run tri channel
      ;; ...
      ;LDA #audio::track_bgm + AUDIO::Track::channels_active
    done_tri:
      ;BIT #AUDIO::CHANNEL_NOISE
      ;BEQ done
      ;; Run noise channel
      ;; ...

      PLN_SP 2 ;; clean up stack
    done:
      RTS
  .endproc

  .proc TickSfx0
      ;; Same as above with sfx0 addresses
      ;; ...
      RTS
  .endproc
  .proc TickSfx1
      ;; Same as above with sfx1 addresses
      ;; ...
      RTS
  .endproc

  ;;;; DecodeStream
  ;; 4-byte stack: 4 args, 0 return
  ;; Uses the given decoder with the given audio header to decode the next note
  .proc DecodeStream
      ;; stack frame
      audio_lo = SW_STACK-4
      audio_hi = SW_STACK-3
      decoder_lo = SW_STACK-2
      decoder_hi = SW_STACK-1

      LDX SP

      ;; For now, just play whatever note is at stream head forever
      LDA decoder_lo,X
      STA PLO
      LDA decoder_hi,X
      STA PHI

      LDY #AUDIO::Decoder::stream_head
      LDA (PLO),Y
      STA r0
      INY
      LDA (PLO),Y
      STA r1

      ;; Duty 50%    | Manual control | Volume max (15)
      LDA #%10000000 | %00110000      | %00001111
      LDY #(AUDIO::Decoder::registers + AUDIO::Registers::env)
      STA (PLO),Y

      LDY #$00
      LDA (r0),Y
      LDY #(AUDIO::Decoder::registers + AUDIO::Registers::note_lo)
      STA (PLO),Y

      LDY #$01
      LDA (r0),Y
      LDY #(AUDIO::Decoder::registers + AUDIO::Registers::note_hi)
      STA (PLO),Y

      RTS
  .endproc

  .proc Disable
      LDA #$00
      STA APUFLAGS
      LDA #$01
      STA audio::disable
      RTS
  .endproc
.endscope
