.repeat 3, n
  .ident(.concat("attr_table_screen", .string(n*4))):
    .repeat 64
      .byte %00000000
    .endrepeat
  .ident(.concat("attr_table_screen", .string(n*4 + 1))):
    .repeat 64
      .byte %11111111
    .endrepeat

  .ident(.concat("attr_table_screen", .string(n*4 + 2))):
    .repeat 64
      .byte %10101010
    .endrepeat

  .ident(.concat("attr_table_screen", .string(n*4 + 3))):
    .repeat 64
      .byte %01010101
    .endrepeat
.endrepeat
