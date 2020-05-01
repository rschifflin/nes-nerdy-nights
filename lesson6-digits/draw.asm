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

DrawStart:
  SET_PPU_ADDRESS $238A ; modify name table at press_start position
  LDA #STATE_ACTION
  AND state
  BNE draw_start_blank
  WRITE_PPU_BYTES strings_press_start, #STRINGS_PRESS_START_SIZE
  JMP draw_start_done
draw_start_blank:
  WRITE_PPU_BYTES name_table, #STRINGS_PRESS_START_SIZE
draw_start_done:
  RTS

DrawWinner:
  SET_PPU_ADDRESS $2022 ; modify name table at press_start position
  LDA #STATE_P1_WIN
  AND state
  BEQ draw_p1_win_blank
  WRITE_PPU_BYTES strings_winner, #STRINGS_WINNER_SIZE
  JMP draw_p1_win_done
draw_p1_win_blank:
  WRITE_PPU_BYTES name_table, #STRINGS_WINNER_SIZE
draw_p1_win_done:
  SET_PPU_ADDRESS $2037 ; modify name table at press_start position
  LDA #STATE_P2_WIN
  AND state
  BEQ draw_p2_win_blank
  WRITE_PPU_BYTES strings_winner, #STRINGS_WINNER_SIZE
  JMP draw_p2_win_done
draw_p2_win_blank:
  WRITE_PPU_BYTES name_table, #STRINGS_WINNER_SIZE
draw_p2_win_done:
  RTS
