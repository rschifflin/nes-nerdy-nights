;;;; GAME-SPECIFIC SUBROUTINES AND MACROS

.macro INCREMENT_TIME
.scope
    CLC
    LDX #$01 ; addend
    LDY #$04 ; counter
  loop:
    LDA time-1,Y
    JSR AdcDec
    STA time-1,Y
    LDX #$00 ; addend
    DEY
    BNE loop
  done:
.endscope
.endmacro

.proc MoveBall
    LDX ball ;; ball ypos
    LDA state
    AND #STATE_BALL_UP
    BNE up
  down:
    INX
    CPX #BOTTOM_WALL
    BEQ down_hit
    MOVE_SPRITE_16 ball, DIR_DOWN, $01
    JMP vert_done
  down_hit:
    MOVE_SPRITE_16 ball, DIR_UP, $01
    JMP reverse_vert
  up:
    DEX
    CPX #TOP_WALL
    BEQ up_hit
    MOVE_SPRITE_16 ball, DIR_UP, $01
    JMP vert_done
  up_hit:
    MOVE_SPRITE_16 ball, DIR_DOWN, $01
  reverse_vert:
    LDA state
    EOR #STATE_BALL_UP
    STA state
  vert_done:
    LDX ball+3 ;; ball xpos
    LDA state
    AND #STATE_BALL_LEFT
    BNE left
  right:
    INX
    CPX #RIGHT_PADDLE
    BEQ right_hit
    CPX #RIGHT_WALL
    BEQ right_reset
    MOVE_SPRITE_16 ball, DIR_RIGHT, $01
    JMP done
  right_reset:
    JMP reset
  right_hit:
    LDA ai_paddle ; Top ypos (closer to 0)
    SEC
    SBC #$10 ; Ball is 16 pixels tall
    CMP ball ; paddle_ypos vs ball_ypos must be <=
    BCS right_hit_done ; Top of the paddle yvalue is greater than the bottom of the ball
    LDA ai_paddle+48 ; Bottom ypos (closer to FF)
    CLC
    ADC #$10 ; Ball is 16 pixels tall
    CMP ball ; paddle_ypos vs ball_ypos must be >=
    BCC right_hit_done ; Bottom paddle yvalue is smaller than the top of the ball
    MOVE_SPRITE_16 ball, DIR_LEFT, $01
    JMP reverse_hori
  right_hit_done:
    MOVE_SPRITE_16 ball, DIR_RIGHT, $01
    JMP done
  left:
    DEX
    CPX #LEFT_PADDLE
    BEQ left_hit
    CPX #LEFT_WALL
    BEQ reset
    MOVE_SPRITE_16 ball, DIR_LEFT, $01
    JMP done
  left_hit:
    LDA player_paddle ; Top ypos (closer to 0)
    SEC
    SBC #$10
    CMP ball ; paddle_ypos vs ball_ypos must be <=
    BCS left_hit_done ; top of the paddle yvalue was larger than the bottom of the ball
    LDA player_paddle+48 ; Bottom ypos (closer to FF)
    CLC
    ADC #$10
    CMP ball
    BCC left_hit_done ; bottom of the paddle yvalue was smaller than the top of the ball
    MOVE_SPRITE_16 ball, DIR_RIGHT, $01
    JMP reverse_hori
  left_hit_done:
    MOVE_SPRITE_16 ball, DIR_LEFT, $01
    JMP done
  reset:
    JSR ScorePoint
    JMP done
  reverse_hori:
    LDA state
    EOR #STATE_BALL_LEFT
    STA state
    FLIPH_SPRITE_16 ball
  done:
    RTS
.endproc

.macro INCREMENT_SCORE arg_ptr
.scope
    CLC
    LDX #$01 ; addend
    LDY #$02 ; counter
  loop:
    LDA arg_ptr - 1,Y
    JSR AdcDec
    STA arg_ptr - 1,Y
    LDX #$00 ; addend
    DEY
    BNE loop
.endscope
.endmacro

.proc ScorePoint
    LDA ball+3
    CMP #$80 ;; Left half or right half of screen
    BCC p2_point ;; Ball is on the left half
  p1_point:
    INCREMENT_SCORE p1_score
    JMP done
  p2_point:
    INCREMENT_SCORE p2_score
  done:
    LDA #$80
    STA ball+3
    STA ball+11
    LDA #$88
    STA ball+7
    STA ball+15

  .scope p1
      LDA p1_score
      BEQ done
      LDA p1_score+1
      CMP #$05
      BCC done
      LDA state
      AND #STATE_MASK_FLAGS
      ORA #STATE_P1_WIN
      STA state
    done:
  .endscope

  .scope p2
      LDA p2_score
      BEQ done
      LDA p2_score+1
      CMP #$05
      BCC done
      LDA state
      AND #STATE_MASK_FLAGS
      ORA #STATE_P2_WIN
      STA state
    done:
      RTS
  .endscope
.endproc

.proc MoveAiPaddle
    LDA state
    AND #STATE_AI_PADDLE_UP
    BNE up
  down:
    LDX ai_paddle+48; bottom-most ypos of final 16x16 block
    INX
    CPX #BOTTOM_WALL
    BEQ reverse
    MOVE_SPRITE_16 ai_paddle,    DIR_DOWN, $01
    MOVE_SPRITE_16 (ai_paddle+16), DIR_DOWN, $01
    MOVE_SPRITE_16 (ai_paddle+32), DIR_DOWN, $01
    MOVE_SPRITE_16 (ai_paddle+48), DIR_DOWN, $01
    JMP done
  reverse:
    LDA state
    EOR #STATE_AI_PADDLE_UP
    STA state
    JMP done
  up:
    LDX ai_paddle; top-most ypos
    DEX
    CPX #TOP_WALL
    BEQ reverse
    MOVE_SPRITE_16 ai_paddle,    DIR_UP, $01
    MOVE_SPRITE_16 (ai_paddle+16), DIR_UP, $01
    MOVE_SPRITE_16 (ai_paddle+32), DIR_UP, $01
    MOVE_SPRITE_16 (ai_paddle+48), DIR_UP, $01
  done:
    RTS
.endproc

.proc MovePlayerPaddle
    LDA controller
    AND #CONTROLLER_P1_UP
    BNE up
    LDA controller
    AND #CONTROLLER_P1_DOWN
    BEQ done
    LDX player_paddle+48
    INX
    CPX #BOTTOM_WALL
    BEQ done
    MOVE_SPRITE_16 player_paddle,    DIR_DOWN, $01
    MOVE_SPRITE_16 (player_paddle+16), DIR_DOWN, $01
    MOVE_SPRITE_16 (player_paddle+32), DIR_DOWN, $01
    MOVE_SPRITE_16 (player_paddle+48), DIR_DOWN, $01
  done:
    RTS
  up:
    LDX player_paddle
    DEX
    CPX #TOP_WALL
    BEQ done
    MOVE_SPRITE_16 player_paddle,    DIR_UP, $01
    MOVE_SPRITE_16 (player_paddle+16), DIR_UP, $01
    MOVE_SPRITE_16 (player_paddle+32), DIR_UP, $01
    MOVE_SPRITE_16 (player_paddle+48), DIR_UP, $01
    JMP done
.endproc
