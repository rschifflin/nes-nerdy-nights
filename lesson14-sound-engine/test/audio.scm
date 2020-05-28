;; Test 0
(asm-test
  (name
    "Init")
  (description
    "It initializes the track pointers as expected")
  (rows 4))

;; Test 1
(asm-test
  (name
    "PlayBGM")
  (description
    "It sets the channel mask"
    "And sets the audio stream pointer in the track"
    "And sets the stream head of the first decoder"
    "And sets the stream head of the second decoder"
    "And sets the stream head of the third decoder"
    "And sets the stream head of the fourth decoder")
  (rows 3))

;; Test 2
(asm-test
  (name
    "PlaySFX0")
  (description
    "It sets the channel mask"
    "And sets the audio stream pointer in the track"
    "And sets the stream head of the first decoder"
    "And sets the stream head of the second decoder"
    "And sets the stream head of the third decoder"
    "And sets the stream head of the fourth decoder")
  (rows 3))

;; Test 3
(asm-test
  (name
    "PlaySFX1")
  (description
    "It sets the channel mask"
    "And sets the audio stream pointer in the track"
    "And sets the stream head of the first decoder"
    "And sets the stream head of the second decoder"
    "And sets the stream head of the third decoder"
    "And sets the stream head of the fourth decoder")
  (rows 3))

;; Test 4
(asm-test
  (name
    "TrackForChannel with all tracks")
  (description
    "It should return the highest priority track's addr"))

;; Test 5
(asm-test
  (name
    "TrackForChannel with staggered track priority")
  (description
    "It should return the correct priority track's addr"))

;; Test 6
(asm-test
  (name
    "TrackForChannel with no tracks")
  (description
    "It should return the null track addr"))

;; Test 7
(asm-test
  (name
    "PrepareChannelBuffer with one channel")
  (description
    "It should set the buffer_ch_addr_list to the correct decoder register offsets"))

;; Test 8
(asm-test
  (name
    "PrepareChannelBuffer with all four channels")
  (description
    "It should set the buffer_ch_addr_list to the correct decoder register offsets"))

;; Test 9
(asm-test
  (name
    "PrepareChannelBuffer with null channel")
  (description
    "It should set the buffer_ch_addr_list to the null addr"))

;; Test 10-a
(asm-test
  (name
    "Decode tick pt1")
  (description
    "It should only act on the correct tick based on speed"
    "Pt1: The first tick always tocks over"))

;; Test 10-b
(asm-test
  (name
    "Decode tick pt2")
  (description
    "It should only act on the correct tick based on speed"
    "Pt1: At default speed, after initial tick, do not tock over after 5 ticks"))

;; Test 10-c
(asm-test
  (name
    "Decode tick pt3")
  (description
    "It should only act on the correct tick based on speed"
    "Pt1: At default speed, after initial tick, do tock over after 6 ticks"))

;; Test 11-a
(asm-test
  (name
    "Decode stop pt1")
  (description
    "It should only stop when it reads a stop opcode"
    "Pt1: Before a stop opcode is reached, dont modify the return value"))

;; Test 11-b
(asm-test
  (name
    "Decode stop pt2")
  (description
    "It should only stop when it reads a stop opcode"
    "Pt2: Once a stop opcode is reached, the return val has its high bit set to 1"))

;; Test 11-c
(asm-test
  (name
    "Decode stop pt3")
  (description
    "It should only stop when it reads a stop opcode"
    "Pt3: Once a stop opcode is reached, all future decode calls' return vals have the high bit set to 1"))

;; Test 12-a
(asm-test
  (name
    "Decode silence pt1")
  (description
    "Reading a silence opcode sets the mute_x_hold_vol bit to 1"
    "Pt1: Before a silence opcode is reached, dont modify the volume"))

;; Test 12-b
(asm-test
  (name
    "Decode silence pt2")
  (description
    "Reading a silence opcode sets the mute_x_hold_vol bit to 1"
    "Pt2: Once a silence opcode is reached, the volume is always 0"))

;; Test 12-c
(asm-test
  (name
    "Decode silence pt3")
  (description
    "Reading a silence opcode sets the mute_x_hold_vol bit to 1"
    "Pt3: Once another note is read after the silence, the volume is restored"))

;; Test 13-a
(asm-test
  (name
    "Decode length pt1")
  (description
    "Reading a length opcode sets the note length, and continues"
    "decoding, reading the next note"))

;; Test 13-b
(asm-test
  (name
    "Decode length pt2")
  (description
    "When remaining is not zero, decoding decremets remaining"))

;; Test 14-c
(asm-test
  (name
    "Decode length pt3")
  (description
    "When remaining is zero, decoding reads the next byte"))

;; Test 15-a
(asm-test
  (name
    "Decode loop")
  (description
    "When decoding a loop, we simply skip back to the first byte"))

;; Test 15-b
(asm-test
  (name
    "Decode loop pt2")
  (description
    "We can play a loop forever"))

;; Test 15-c
(asm-test
  (name
    "Decode loop pt3")
  (description
    "When looping, the volume stream also loops back to the start"))

;; Test 16-a
;(asm-test
;  (name
;    "Decode volume pt1")
;  (description
;    "With no hold, use the next volume value in the stream"))

;; Test 16-b
;(asm-test
; (name
;   "Decode volume pt2")
; (description
;   "With still no hold, use the next volume value in the stream"))

;; Test 16-c
;(asm-test
; (name
;   "Decode volume pt3")
; (description
;   "With a hold of 3, use the same volume for 3 frames"))

;; Test 16-d
;(asm-test
; (name
;   "Decode volume pt4")
; (description
;   "After a hold, use the next volume value in the stream"))

;; Test 16-e
;(asm-test
; (name
;   "Decode volume pt5")
; (description
;   "After a hold forever, always use the same volume"))

;; Test 17-a
(asm-test
 (name
   "Decode instrument pattern 1 pt1")
 (description
   "After initial read, volume is A"
   "A->A->A->E->9->3->2->1"))

;; Test 17-b
(asm-test
 (name
   "Decode instrument pattern 1 pt2")
 (description
   "After 4 reads, volume is E"
   "A->A->A->E->9->3->2->1"))

;; Test 17-c
(asm-test
 (name
   "Decode instrument pattern 1 pt3")
 (description
   "After 8 reads, volume is 1"
   "A->A->A->E->9->3->2->1"))

;; Test 17-d
(asm-test
 (name
   "Decode instrument pattern 1 pt4")
 (description
   "For all reads after 8, volume is 1"
   "A->A->A->E->9->3->2->1"))
