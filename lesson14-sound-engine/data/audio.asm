.scope audio_data
  ignore_volume:
    .byte AUDIO::VOLUME_HOLD_FOREVER
  instrument0:
    .byte $0F
  instrument_blip:
    .byte $17
    .byte $2F
    .byte $3A
    .byte $0A
  volume_creep:
    .byte $0A, $87
    .byte $0F, $80

  test_song_1:
    .byte %00000011 ;; Just sq1 and sq2
    .byte %00000101 ;; speed/tempo, speed 5 = 24 ticks/beat = 150 bpm

    ;; In the future:
    ;; .repeat n .byte instruments?
    ;; .repeat n .byte patterns?
    ;; .repeat n .byte frames?

    .addr test_song_sq1_stream ;; ch0
    .addr test_song_sq2_stream ;; ch1
    .addr test_song_stop ;; ch2
    .addr test_song_stop ;; ch3

    .addr volume_creep ;; ch0
    .addr volume_creep ;; ch1
    .addr volume_creep ;; ch2
    .addr volume_creep ;; ch3

    .addr instrument_blip
  test_song_2:
    .byte %00000101 ;; Just sq1 and tri
    .byte %00000101 ;; speed/tempo, speed 5 = 24 ticks/beat = 150 bpm

    ;; In the future:
    ;; .repeat n .byte instruments?
    ;; .repeat n .byte patterns?
    ;; .repeat n .byte frames?

    .addr test_song_2_all_stream ;; ch0
    .addr test_song_stop ;; ch1
    .addr test_song_2_all_stream ;; ch2
    .addr test_song_stop ;; ch3

    .addr test_song_2_volume_stream ;; ch0
    .addr ignore_volume ;; ch1
    .addr test_song_2_volume_stream ;; ch0
    .addr ignore_volume ;; ch3

    .addr instrument0
  test_song_3:
    .byte %00001111 ;; All channels
    .byte %00000101 ;; speed/tempo, speed 5 = 24 ticks/beat = 150 bpm
    ;.addr test_song_sq1_stream;; ch0
    ;.addr test_song_sq1_stream ;; ch1
    ;.addr test_song_sq1_stream ;; ch2
    ;.addr test_song_sq1_stream ;; ch3
    .addr test_song_intense_stream;; ch0
    .addr test_song_intense_stream ;; ch1
    .addr test_song_intense_stream ;; ch2
    .addr test_song_intense_stream ;; ch3

    .addr ignore_volume ;; ch0
    .addr ignore_volume ;; ch1
    .addr ignore_volume ;; ch2
    .addr ignore_volume ;; ch3

    .addr instrument0
  test_sfx_1:
    .byte %00001100 ;; All channels
    .byte %00000101 ;; speed/tempo, speed 5 = 24 ticks/beat = 150 bpm
    ;.addr test_song_sq1_stream;; ch0
    ;.addr test_song_sq1_stream ;; ch1
    ;.addr test_song_sq1_stream ;; ch2
    ;.addr test_song_sq1_stream ;; ch3
    .addr test_song_intense_stream;; ch0
    .addr test_song_intense_stream ;; ch1
    .addr test_song_intense_stream ;; ch2
    .addr test_song_intense_stream ;; ch3

    .addr ignore_volume ;; ch0
    .addr ignore_volume ;; ch1
    .addr ignore_volume ;; ch2
    .addr ignore_volume ;; ch3

    .addr instrument0
  test_sfx_2:
    .byte %00000011 ;; All channels
    .byte %00000101 ;; speed/tempo, speed 5 = 24 ticks/beat = 150 bpm
    ;.addr test_song_sq1_stream;; ch0
    ;.addr test_song_sq1_stream ;; ch1
    ;.addr test_song_sq1_stream ;; ch2
    ;.addr test_song_sq1_stream ;; ch3
    .addr test_song_intense_stream;; ch0
    .addr test_song_intense_stream ;; ch1
    .addr test_song_intense_stream ;; ch2
    .addr test_song_intense_stream ;; ch3

    .addr ignore_volume ;; ch0
    .addr ignore_volume ;; ch1
    .addr ignore_volume ;; ch2
    .addr ignore_volume ;; ch3

    .addr instrument0

  test_song_intense_stream:
    .byte AUDIO::OP_CODES::LENGTH, $01
    .byte $27
    .byte AUDIO::OP_CODES::LOOP

  test_song_sq1_stream:
    ;; 4 notes = 1 beat
    ;; C(2) = $1b
    ;; C(3) = $27
    ;; C(4) = $33
    ;; C(5) = $3f
    ;; C(6) = $4b

    .byte AUDIO::OP_CODES::LENGTH, $04
    .byte $27
    .byte $33
    .byte AUDIO::OP_CODES::SILENCE
    .byte $3F
    .byte $4B
    .byte AUDIO::OP_CODES::SILENCE
    .byte $3F
    .byte $33
    .byte $27
    .byte $1B
    .byte AUDIO::OP_CODES::SILENCE
    .byte AUDIO::OP_CODES::LOOP

  test_song_sq2_stream:
    .byte AUDIO::OP_CODES::LENGTH, $04
    .repeat 4
      .byte AUDIO::OP_CODES::SILENCE
    .endrepeat
    .byte AUDIO::OP_CODES::STOP

  test_song_2_all_stream:
    .byte $27, $33, $3F, $4B
    .byte $3F, $33, $27, $1B
    .byte AUDIO::OP_CODES::STOP

  test_song_2_volume_stream:
    .byte $02, $06, $0A, $0F
    .byte $0F, $0A, $06, $02
    .byte $0F, AUDIO::VOLUME_HOLD_FOREVER

  test_song_stop:
    .byte AUDIO::OP_CODES::STOP
  .endscope
