.repeat 4, n
  .ident(.concat("attr_table_screen", .string(n*3))):
    .repeat 64
      .byte %00000000
    .endrepeat
  .ident(.concat("attr_table_screen", .string(n*3 + 1))):
    .repeat 64
      .byte %11111111
    .endrepeat

  .ident(.concat("attr_table_screen", .string(n*3 + 2))):
    .repeat 64
      .byte %10101010
    .endrepeat
.endrepeat
