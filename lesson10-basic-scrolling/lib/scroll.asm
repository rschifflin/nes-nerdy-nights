.macro UPDATE_SCROLL_BUFFER
.scope
  LDA #PPUCTRL_INC32
  STA PPUCTRL

.endscope
.endmacro
