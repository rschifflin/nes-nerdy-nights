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
    LDA p2_paddle ; Top ypos (closer to 0)
    SEC
    SBC #$10 ; Ball is 16 pixels tall
    CMP ball ; paddle_ypos vs ball_ypos must be <=
    BCS right_hit_done ; Top of the paddle yvalue is greater than the bottom of the ball
    LDA p2_paddle+48 ; Bottom ypos (closer to FF)
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
    LDA p1_paddle ; Top ypos (closer to 0)
    SEC
    SBC #$10
    CMP ball ; paddle_ypos vs ball_ypos must be <=
    BCS left_hit_done ; top of the paddle yvalue was larger than the bottom of the ball
    LDA p1_paddle+48 ; Bottom ypos (closer to FF)
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
    LDA #$01
    EOR bank
    STA bank
    ROL A
    JSR MapperWriteCHR0

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

.macro MOVE_PADDLE arg_paddle, arg_controller
  LDA #<arg_paddle
  STA ptr
  LDA #>arg_paddle
  STA ptr+1
  LDX arg_controller
  JSR MovePaddle
.endmacro
.proc MovePaddle
    TXA
    AND #CONTROLLER_UP
    BNE up
    TXA
    AND #CONTROLLER_DOWN
    BEQ done
  down:
    LDY #$30
    LDA (ptr), Y
    TAX
    INX
    CPX #BOTTOM_WALL
    BEQ done
    LDA #DIR_DOWN
    PHA
    JMP move
  done:
    RTS
  up:
    LDY #$00
    LDA (ptr), Y
    TAX
    DEX
    CPX #TOP_WALL
    BEQ done
    LDA #DIR_UP
    PHA
  move:
    ;; ptr contains address to paddle
    ;; r0 contains amount
    ;; A contains direction
    LDA #$01
    STA r0
    PLA ;; Peek to put direction in A
    PHA ;;
    JSR MoveSprite16

    .repeat 3
      ;; Add 16 to pointer
      LDA ptr
      CLC
      ADC #$10
      STA ptr
      LDA ptr+1
      ADC #$00
      STA ptr+1
      LDA #$01
      STA r0
      PLA ;; Peek to put direction in A
      PHA ;;
      JSR MoveSprite16
    .endrepeat

    PLA ; clean up stack
    JMP done
.endproc
