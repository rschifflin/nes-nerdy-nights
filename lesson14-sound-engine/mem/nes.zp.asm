;;;; Global system variables.
;; Should not be modified by general-purpose library code
chr_bank:      .res 1  ;; Keeps track of our CHR bank, up to 16 for 8kb banks or 32 for 4kb banks
prg_bank:      .res 1  ;; Keeps track of our PRG bank, up to 8 for 32kb banks or 16 for 16kb banks
p1_controller: .res 1  ;; Holds bitmask of controller state
p2_controller: .res 1  ;; Holds bitmask of controller state
