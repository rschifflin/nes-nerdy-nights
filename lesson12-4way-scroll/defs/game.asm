;; page variables, used to determine width/height and page dimensions
;; name tables, meta-tile tables, and attr tables all carry a small header defining this struct
.struct PageTable
  span_width        .byte ;; # of pages per row
  span_height       .byte ;; # of rows
  width_bytes       .byte
  height_bytes      .byte
  page_bytes        .word ;; width_bytes * height_bytes
  span_width_bytes  .word ;; span_width * page_bytes
  start_byte        .addr
.endstruct

.struct PageByte
  x_pixels .byte ;; # of world coordinate pixels spanned horizontally by a page byte
  y_pixels .byte ;; # of world coordinate pixels spanned vertically by a page byte
.endstruct

.struct PageHeader
  table .tag PageTable
  byte  .tag PageByte
.endstruct

.struct PageByteRef
  page_n            .byte ;; Index of referenced page byte
  offset_x          .byte ;; Row offset of referenced page byte
  offset_y          .byte ;; Col offset of referenced page byte
.endstruct

MAX_X_SCROLL = $0300
MIN_X_SCROLL = $0000
MAX_X_SCROLL_SPEED = $07
MIN_X_SCROLL_SPEED = $01

MAX_Y_SCROLL = $01E0
MIN_Y_SCROLL = $0000
MAX_Y_SCROLL_SPEED = $07
MIN_Y_SCROLL_SPEED = $01
