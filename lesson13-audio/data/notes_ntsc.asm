;; Derived from https://nerdy-nights.nes.science/downloads/missing/NotesTableNTSC.txt

;; Total size (8 octaves * 12 notes per octave) * 2 bytes per note = 192 bytes
;; Note the final 2 notes are actually 0, but included for symmetry
;; Note that these values only match for NTSC as they rely on cpu frequency

;;    A      Bb     B      C      Db     D      Eb     E      F      Gb     G      Ab
.word $07F1, $0780, $0713, $06AD, $064D, $05F3, $059D, $054D, $0500, $04B8, $0475, $0435 ;; Octave 1
.word $03F8, $03BF, $0389, $0356, $0326, $02F9, $02CE, $02A6, $027F, $025C, $023A, $021A ;; Octave 2
.word $01FB, $01DF, $01C4, $01AB, $0193, $017C, $0167, $0152, $013F, $012D, $011C, $010C ;; Octave 3
.word $00FD, $00EF, $00E2, $00D2, $00C9, $00BD, $00B3, $00A9, $009F, $0096, $008E, $0086 ;; Octave 4
.word $007E, $0077, $0070, $006A, $0064, $005E, $0059, $0054, $004F, $004B, $0046, $0042 ;; Octave 5
.word $003F, $003B, $0038, $0034, $0031, $002F, $002C, $0029, $0027, $0025, $0023, $0021 ;; Octave 6
.word $001F, $001D, $001B, $001A, $0018, $0017, $0015, $0014, $0013, $0012, $0011, $0010 ;; Octave 7
.word $000F, $000E, $000D, $000C, $000C, $000B, $000A, $000A, $0009, $0008, $0000, $0000 ;; Octave 8
