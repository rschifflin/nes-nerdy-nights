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

test_song_3:
    .byte %00000001 ;; Just sq1
    .byte %00000101 ;; speed/tempo, speed 5 = 24 ticks/beat = 150 bpm

    ;; In the future:
    ;; .repeat n .byte instruments?
    ;; .repeat n .byte patterns?
    ;; .repeat n .byte frames?

    .addr test_song_stop ;; ch0
    .addr test_song_stop ;; ch1
    .addr test_song_stop ;; ch2
    .addr test_song_stop ;; ch3

test_song_sq1_stream:
  ;; 4 notes = 1 beat
  ;; C(2) = $1b
  ;; C(3) = $27
  ;; C(4) = $33
  ;; C(5) = $3f
  ;; C(6) = $4b

  .byte AUDIO::OP_CODES::LENGTH, $04
  .byte $27,
  .byte $33,
  .byte AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE
  .byte $3F
  .byte $4B
  .byte AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE
  .byte $3F
  .byte $33
  .byte $27
  .byte $1B
  .byte AUDIO::OP_CODES::STOP

test_song_sq2_stream:
  .byte AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE
  .byte AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE
  .byte AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE
  .byte AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE, AUDIO::OP_CODES::SILENCE
  .byte AUDIO::OP_CODES::STOP

test_song_2_all_stream:
  .byte $27, $33, $3F, $4B
  .byte $3F, $33, $27, $1B
  .byte AUDIO::OP_CODES::STOP

test_song_stop:
  .byte AUDIO::OP_CODES::STOP
