DrawScore:
  SET_PPU_ADDRESS $2042 ; modify name table at p1 score position
  WRITE_PPU_BYTES p1_score, #$02

  SET_PPU_ADDRESS $205C ; modify name table at p2 score position
  WRITE_PPU_BYTES p2_score, #$02
  RTS

DrawTime:
  SET_PPU_ADDRESS $202D ; modify name table at time position
  WRITE_PPU_BYTES time, #$04
  RTS
