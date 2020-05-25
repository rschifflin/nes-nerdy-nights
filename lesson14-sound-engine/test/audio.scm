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

;; Test 10
(asm-test
  (name
    "Decode")
  (description
    "It should only act on the correct tick based on speed and tempo"))

