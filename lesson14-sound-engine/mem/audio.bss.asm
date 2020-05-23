.scope audio
  disable:    .res 1

  track_bgm:        .tag AUDIO::Track
  track_sfx0:       .tag AUDIO::Track
  track_sfx1:       .tag AUDIO::Track
  track_prio_list:
    .addr track_bgm ;; Lowest priority
    .addr track_sfx0
    .addr track_sfx1 ;; Highest priority

  ;; Buffered to not write unless register changes
  buffer_ch_write_list:
    sq1_last:   .tag AUDIO::Registers
    sq2_last:   .tag AUDIO::Registers
    tri_last:   .tag AUDIO::Registers
    noise_last: .tag AUDIO::Registers

  ;; Set by BufferPlay, otherwise defaults to last write
  buffer_ch_addr_list:
    sq1_addr:   .addr sq1_last ;; -> AUDIO::Registers
    sq2_addr:   .addr sq2_last ;; -> AUDIO::Registers
    tri_addr:   .addr tri_last ;; -> AUDIO::Registers
    noise_addr: .addr noise_last ;; -> AUDIO::Registers
.endscope
