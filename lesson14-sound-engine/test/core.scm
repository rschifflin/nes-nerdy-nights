;; Test 0
(asm-test
  (name
    "Rotate Buf Right: Len 0 does nothing")
  (description
    "Given a buffer of len 0"
    "Expects RotateBufRight to do nothing"))

;; Test 1
(asm-test
  (name
    "Rotate Buf Right: A rotation of 0 does nothing")
  (description
    "Given a buffer with no rotation"
    "Expects RotateBufRight to do nothing"))

;; Test 2
(asm-test
  (name "Rotate Buf Right: Rotation within len")
  (description
    "Given a buffer with 10 elements"
    "And a rotation of 7"
    "Expects RotateBufRight to rotate properly"))

;; Test 3
(asm-test
  (name "Rotate Buf Right: Rotation with cycles")
  (description
    "Given a buffer with 6 elements"
    "And a rotation of 2"
    "So that after 3 rotations we end up in a cycle"
    "Expects RotateBufRight to rotate properly"))

;; Test 4
(asm-test
  (name "Rotate Buf Right: Shift larger than size")
  (description
    "Given a buffer with 13 elements"
    "And a rotation of 17"
    "Expects RotateBufRight to behave like a rotation of 4"))

;; Test 5
(asm-test
  (name "Rotate Buf Right: Shift equal to size")
  (description
    "Given a buffer with 32 elements"
    "And a rotation of 32"
    "Expects RotateBufRight to behave like a rotation of 0")
  (rows 2))

;; Test 6
(asm-test
  (name "Rotate Buf Right: Large numbers")
  (description
    "Given a buffer with 255 elements"
    "And a rotation of 197"
    "Expects RotateBufRight to behave correctly")
  (rows 16))
