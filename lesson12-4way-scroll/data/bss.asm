sprite_area:               .res 256

scroll_speed:              .res 1 ;; How much to scroll by when pressing left or right
scroll_buffer_status:      .res 1 ;; Indicates whether a buffer is ready (1) or not-ready (0). bit 3 = left attr, bit 2 = left name, bit 1 = right_attr, bit 0 = right_name
scroll_buffer_left_name:   .res 30
scroll_buffer_right_name:  .res 30
scroll_buffer_left_attr:   .res 8
scroll_buffer_right_attr:  .res 8

scroll_buffer_top_name:   .res 33
scroll_buffer_bottom_name:  .res 33
scroll_buffer_top_attr:   .res 9
scroll_buffer_bottom_attr:  .res 9

is_last_vertical_up: .res 1 ;; A bool indicating the last vertical direction travelled was up (0) or down (1)
