.proc DrawScore
    SET_PPU_ADDRESS $2042 ; modify name table at p1 score position
    WRITE_PPU_BYTES p1_score, $02

    SET_PPU_ADDRESS $205C ; modify name table at p2 score position
    WRITE_PPU_BYTES p2_score, $02
    RTS
.endproc

.proc DrawTime
    SET_PPU_ADDRESS $202D ; modify name table at time position
    WRITE_PPU_BYTES time, $04
    RTS
.endproc

.proc DrawStart
    SET_PPU_ADDRESS $238A ; modify name table at press_start position
    LDA #STATE_ACTION
    AND state
    BNE draw_blank
  draw_start:
    WRITE_PPU_BYTES strings_press_start, STRINGS_PRESS_START_SIZE
    JMP done
  draw_blank:
    WRITE_PPU_BYTES name_table, STRINGS_PRESS_START_SIZE
  done:
    RTS
.endproc

.proc DrawWinner
  .scope p1
      SET_PPU_ADDRESS $2022 ; modify name table at press_start position
      LDA #STATE_P1_WIN
      AND state
      BEQ draw_blank
    draw_win:
      WRITE_PPU_BYTES strings_winner, STRINGS_WINNER_SIZE
      JMP done
    draw_blank:
      WRITE_PPU_BYTES name_table, STRINGS_WINNER_SIZE
    done:
  .endscope

  .scope p2
      SET_PPU_ADDRESS $2037 ; modify name table at press_start position
      LDA #STATE_P2_WIN
      AND state
      BEQ draw_blank
    draw_win:
      WRITE_PPU_BYTES strings_winner, STRINGS_WINNER_SIZE
      JMP done
    draw_blank:
      WRITE_PPU_BYTES name_table, STRINGS_WINNER_SIZE
    done:
      RTS
  .endscope
.endproc
