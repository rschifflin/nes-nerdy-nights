;; Test 0
(asm-test
  (name "Push 1")
  (description "Pushes 1 integer onto the sw stack"))

;; Test 1
(asm-test
  (name "Push 55")
  (description "Pushes 55 integers onto the sw stack")
  (rows 4))

;; Test 2
(asm-test
  (name "Push 255")
  (description "Pushes 255 integers onto the sw stack")
  (rows 16))

;; Test 3
(asm-test
  (name "Pull 1")
  (description "Pulls 1 integer from the sw stack"))

;; Test 4
(asm-test
  (name "Pull 133")
  (description "Pulls 133 integers from the sw stack")
  (rows 9))

;; Test 5
(asm-test
  (name "Pull 255")
  (description "Pull 255 integers from the sw stack")
  (rows 16))

;; Test 6
(asm-test
  (name "Push and pull")
  (description "Make a series of pushes and pulls, ending with 0-63 in the stack")
  (rows 4))

;; Test 7
(asm-test
  (name "PushN")
  (description "Increments SP by N"))

;; Test 8
(asm-test
  (name "PullN")
  (description "Decrements SP by N"))
