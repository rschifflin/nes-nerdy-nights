;;;; Memory registers.
;; Interrupts should preserve these values to stay re-entrant
;; Like A,X and Y, may be clobbered by JSR.
SP:            .res 1 ; Software stack pointer
PLO:           .res 1 ; pointer reg used for indirection
PHI:           .res 1 ; pointer reg used for indirection
;;
r0:            .res 1 ; Simple re-usable byte register
r1:            .res 1 ; Simple re-usable byte register
;;;;

;;;; Global system variables.
;; Should not be modified by general-purpose library code
chr_bank:      .res 1  ;; Keeps track of our CHR bank, up to 16 for 8kb banks or 32 for 4kb banks
prg_bank:      .res 1  ;; Keeps track of our PRG bank, up to 8 for 32kb banks or 16 for 16kb banks
p1_controller: .res 1  ;; Holds bitmask of controller state
p2_controller: .res 1  ;; Holds bitmask of controller state

ppu_scroll_y: .res 1 ;; Holds last set ppu scroll y register. This number is 0-239

cam_x:       .res 2  ;; Holds horizontal scroll position 16bit
cam_y:       .res 2  ;; Holds vertical scroll position 16bit
cam_dx:      .res 1  ;; Holds horizontal scroll delta, signed
cam_dy:      .res 1  ;; Holds vertical scroll delta, signed

;; Rendering variables
render_flags:      .res 1 ;; For miscellaneous flags
                      ;; bit 0: whether or not the nametables are swapped. 0 = normal order, 1 = swapped order
;;;;

;;;; ZP program variables
state:         .res 1
frame_counter: .res 1
current_frame: .res 1
page_table:    .res 10 ;; TODO: .tag PageTable but solve dependency conflicts with tests
;;;;
