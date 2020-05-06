;; Sets the MMC1 Mapper to the following:
;;   Swap 8kb char banks
;;   Swap 16kb PRG banks at $8000
;;   Vertical mirroring

.proc ConfigureMapper
  LDA #MMC1_RESET_BIT
  STA MMC1_CONFIG_SHIFT_REGISTER

  LDA #%00001110
  .repeat 4
    STA MMC1_CONFIG_SHIFT_REGISTER
    LSR A
  .endrepeat
  STA MMC1_CONFIG_SHIFT_REGISTER
  RTS
.endproc

.proc MapperWritePRG
  .repeat 4
    STA MMC1_PRG_BANK_SHIFT_REGISTER
    LSR A
  .endrepeat
  STA MMC1_PRG_BANK_SHIFT_REGISTER
  RTS
.endproc

.proc MapperWriteCHR0
  .repeat 4
    STA MMC1_CHR_BANK0_SHIFT_REGISTER
    LSR A
  .endrepeat
  STA MMC1_CHR_BANK0_SHIFT_REGISTER
  RTS
.endproc

.proc MapperWriteCHR1
  .repeat 4
    STA MMC1_CHR_BANK1_SHIFT_REGISTER
    LSR A
  .endrepeat
  STA MMC1_CHR_BANK1_SHIFT_REGISTER
  RTS
.endproc
