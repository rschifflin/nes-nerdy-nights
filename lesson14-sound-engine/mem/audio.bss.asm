.scope audio
  disable:          .res 1
  apu_flags_buffer: .res 1
  opcode_vector:    .res 2

tracks:
  track_bgm:        .tag AUDIO::Track
  track_sfx0:       .tag AUDIO::Track
  track_sfx1:       .tag AUDIO::Track

decoders:
  decoder_0:        .tag AUDIO::Decoder
  decoder_1:        .tag AUDIO::Decoder
  decoder_2:        .tag AUDIO::Decoder
  decoder_3:        .tag AUDIO::Decoder
  decoder_4:        .tag AUDIO::Decoder
  decoder_5:        .tag AUDIO::Decoder
  decoder_6:        .tag AUDIO::Decoder
  decoder_7:        .tag AUDIO::Decoder
  decoder_8:        .tag AUDIO::Decoder
  decoder_9:        .tag AUDIO::Decoder
  decoder_A:        .tag AUDIO::Decoder
  decoder_B:        .tag AUDIO::Decoder

  ;; Buffered to not write unless register changes
  buffer_ch_cache_list:
    sq1_last:   .tag AUDIO::Registers
    sq2_last:   .tag AUDIO::Registers
    tri_last:   .tag AUDIO::Registers
    noise_last: .tag AUDIO::Registers

  ;; Set by PrepareChannelBuffer, otherwise defaults to last write
  buffer_ch_addr_list:
    sq1_addr:   .res 2 ;; -> AUDIO::Registers
    sq2_addr:   .res 2 ;; -> AUDIO::Registers
    tri_addr:   .res 2 ;; -> AUDIO::Registers
    noise_addr: .res 2 ;; -> AUDIO::Registers

.endscope
