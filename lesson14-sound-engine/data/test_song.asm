test_song_1:
    .byte %00000011 ;; Just sq1 and sq2
    .byte $FF ;; spempo, unused still

    ;; In the future:
    ;; .repeat n .byte instruments?
    ;; .repeat n .byte patterns?
    ;; .repeat n .byte frames?

    .addr note_c3 ;; ch0
    .addr note_c4 ;; ch1
    .addr note_c3 ;; ch2
    .addr note_c3 ;; ch3

test_song_2:
    .byte %00000101 ;; Just sq1 and tri
    .byte $FF ;; spempo, unused still

    ;; In the future:
    ;; .repeat n .byte instruments?
    ;; .repeat n .byte patterns?
    ;; .repeat n .byte frames?

    .addr note_c4 ;; ch0
    .addr note_c4 ;; ch1
    .addr note_c4 ;; ch2
    .addr note_c4 ;; ch3

test_song_3:
    .byte %00000001 ;; Just sq1
    .byte $FF ;; spempo, unused still

    ;; In the future:
    ;; .repeat n .byte instruments?
    ;; .repeat n .byte patterns?
    ;; .repeat n .byte frames?

    .addr note_c5 ;; ch0
    .addr note_c5 ;; ch1
    .addr note_c5 ;; ch2
    .addr note_c5 ;; ch3

note_c3:
  .word NOTE_C_3

note_c4:
  .word NOTE_C_4

note_c5:
  .word NOTE_C_5
