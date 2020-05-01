;;;; GAME-SPECIFIC SUBROUTINES AND MACROS

INCREMENT_TIME .macro
  CLC
  LDX #$01 ; addend
  LDY #$04 ; counter
inc_time_loop_\@:
  LDA time-1,Y
  JSR AdcDec
  STA time-1,Y
  LDX #$00 ; addend
  DEY
  BNE inc_time_loop_\@
inc_time_done_\@:
  .endm

INCREMENT_SCORE .macro
  CLC
  LDX #$01 ; addend
  LDY #$02 ; counter
inc_score_loop_\@:
  LDA \1 - 1,Y
  JSR AdcDec
  STA \1 - 1,Y
  LDX #$00 ; addend
  DEY
  BNE inc_score_loop_\@
inc_score_done_\@:
  .endm

MoveBall:
  LDX ball ;; ball ypos
  LDA state
  AND #STATE_BALL_UP
  BNE move_ball_up
move_ball_down:
  INX
  CPX #BOTTOM_WALL
  BEQ move_ball_down_hit
  MOVE_SPRITE_16 ball, DIR_DOWN, #$01
  JMP move_ball_vert_done
move_ball_down_hit:
  MOVE_SPRITE_16 ball, DIR_UP, #$01
  JMP move_ball_reverse_vert
move_ball_up:
  DEX
  CPX #TOP_WALL
  BEQ move_ball_up_hit
  MOVE_SPRITE_16 ball, DIR_UP, #$01
  JMP move_ball_vert_done
move_ball_up_hit:
  MOVE_SPRITE_16 ball, DIR_DOWN, #$01
move_ball_reverse_vert:
  LDA state
  EOR #STATE_BALL_UP
  STA state
move_ball_vert_done:
  LDX ball+3 ;; ball xpos
  LDA state
  AND #STATE_BALL_LEFT
  BNE move_ball_left
move_ball_right:
  INX
  CPX #RIGHT_PADDLE
  BEQ move_ball_right_hit
  CPX #RIGHT_WALL
  BEQ move_ball_right_reset
  MOVE_SPRITE_16 ball, DIR_RIGHT, #$01
  JMP move_ball_done
move_ball_right_reset:
  JMP move_ball_reset
move_ball_right_hit:
  LDA ai_paddle ; Top ypos (closer to 0)
  SEC
  SBC #$10 ; Ball is 16 pixels tall
  CMP ball ; paddle_ypos vs ball_ypos must be <=
  BCS move_ball_right_hit_done ; Top of the paddle yvalue is greater than the bottom of the ball
  LDA ai_paddle+48 ; Bottom ypos (closer to FF)
  CLC
  ADC #$10 ; Ball is 16 pixels tall
  CMP ball ; paddle_ypos vs ball_ypos must be >=
  BCC move_ball_right_hit_done ; Bottom paddle yvalue is smaller than the top of the ball
  MOVE_SPRITE_16 ball, DIR_LEFT, #$01
  JMP move_ball_reverse_hori
move_ball_right_hit_done:
  MOVE_SPRITE_16 ball, DIR_RIGHT, #$01
  JMP move_ball_done
move_ball_left:
  DEX
  CPX #LEFT_PADDLE
  BEQ move_ball_left_hit
  CPX #LEFT_WALL
  BEQ move_ball_reset
  MOVE_SPRITE_16 ball, DIR_LEFT, #$01
  JMP move_ball_done
move_ball_left_hit:
  LDA player_paddle ; Top ypos (closer to 0)
  SEC
  SBC #$10
  CMP ball ; paddle_ypos vs ball_ypos must be <=
  BCS move_ball_left_hit_done ; top of the paddle yvalue was larger than the bottom of the ball
  LDA player_paddle+48 ; Bottom ypos (closer to FF)
  CLC
  ADC #$10
  CMP ball
  BCC move_ball_left_hit_done ; bottom of the paddle yvalue was smaller than the top of the ball
  MOVE_SPRITE_16 ball, DIR_RIGHT, #$01
  JMP move_ball_reverse_hori
move_ball_left_hit_done:
  MOVE_SPRITE_16 ball, DIR_LEFT, #$01
  JMP move_ball_done
move_ball_reset:
  JSR ScorePoint
  JMP move_ball_done
move_ball_reverse_hori:
  LDA state
  EOR #STATE_BALL_LEFT
  STA state
  FLIPH_SPRITE_16 ball
move_ball_done:
  RTS

ScorePoint:
  LDA ball+3
  CMP #$80 ;; Left half or right half of screen
  BCC score_point_ai ;; Ball is on the left half
  INCREMENT_SCORE p1_score
  JMP score_point_done
score_point_ai:
  INCREMENT_SCORE p2_score
score_point_done:
  LDA #$80
  STA ball+3
  STA ball+11
  LDA #$88
  STA ball+7
  STA ball+15

  LDA p1_score
  BEQ check_p1_winner_done
  LDA p1_score+1
  CMP #$05
  BCC check_p1_winner_done
  LDA state
  AND #STATE_MASK_FLAGS
  ORA #STATE_P1_WIN
  STA state
check_p1_winner_done:
  LDA p2_score
  BEQ check_p2_winner_done
  LDA p2_score+1
  CMP #$05
  BCC check_p2_winner_done
  LDA state
  AND #STATE_MASK_FLAGS
  ORA #STATE_P2_WIN
  STA state
check_p2_winner_done:
  RTS

MoveAiPaddle
  LDA state
  AND #STATE_AI_PADDLE_UP
  BNE move_ai_paddle_up
move_ai_paddle_down:
  LDX ai_paddle+48; bottom-most ypos of final 16x16 block
  INX
  CPX #BOTTOM_WALL
  BEQ move_ai_paddle_reverse
  MOVE_SPRITE_16 ai_paddle,    DIR_DOWN, #$01
  MOVE_SPRITE_16 ai_paddle+16, DIR_DOWN, #$01
  MOVE_SPRITE_16 ai_paddle+32, DIR_DOWN, #$01
  MOVE_SPRITE_16 ai_paddle+48, DIR_DOWN, #$01
  JMP move_ai_paddle_done
move_ai_paddle_reverse:
  LDA state
  EOR #STATE_AI_PADDLE_UP
  STA state
  JMP move_ai_paddle_done
move_ai_paddle_up:
  LDX ai_paddle; top-most ypos
  DEX
  CPX #TOP_WALL
  BEQ move_ai_paddle_reverse
  MOVE_SPRITE_16 ai_paddle,    DIR_UP, #$01
  MOVE_SPRITE_16 ai_paddle+16, DIR_UP, #$01
  MOVE_SPRITE_16 ai_paddle+32, DIR_UP, #$01
  MOVE_SPRITE_16 ai_paddle+48, DIR_UP, #$01
  JMP move_ai_paddle_done
move_ai_paddle_done:
  RTS

MovePlayerPaddle
  LDA controller
  AND #CONTROLLER_P1_UP
  BNE move_player_paddle_up
  LDA controller
  AND #CONTROLLER_P1_DOWN
  BEQ move_player_paddle_done
  LDX player_paddle+48
  INX
  CPX #BOTTOM_WALL
  BEQ move_player_paddle_done
  MOVE_SPRITE_16 player_paddle,    DIR_DOWN, #$01
  MOVE_SPRITE_16 player_paddle+16, DIR_DOWN, #$01
  MOVE_SPRITE_16 player_paddle+32, DIR_DOWN, #$01
  MOVE_SPRITE_16 player_paddle+48, DIR_DOWN, #$01
move_player_paddle_done:
  RTS
move_player_paddle_up:
  LDX player_paddle
  DEX
  CPX #TOP_WALL
  BEQ move_player_paddle_done
  MOVE_SPRITE_16 player_paddle,    DIR_UP, #$01
  MOVE_SPRITE_16 player_paddle+16, DIR_UP, #$01
  MOVE_SPRITE_16 player_paddle+32, DIR_UP, #$01
  MOVE_SPRITE_16 player_paddle+48, DIR_UP, #$01
  JMP move_player_paddle_done
