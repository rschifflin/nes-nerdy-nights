.segment "iNes" ; Defines a header segment for emulators. When using a real cart, we would strip these bytes and just use the zeropage as the start
  .byte $4e, $45, $53, $1a ; ines filetype magic bytes
  .byte $02 ; # of 16kb PRG segments
  .byte $02 ; # of 8kb CHR segments
  .byte %00010001 ; # Upper nibble: mapper 1. Lower nibble: Nametable mirroring in the PPU

