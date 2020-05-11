;; PPU (Video)
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
OAMDATA   = $2004
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014
PPUCTRL_INC32 = %00000100

;; APU (Audio)
APUCTRL   = $4010
APUFC     = $4017

;; MMC (Memory mapper chip)
MMC1_RESET_BIT            = %10000000
MMC1_CONFIG_SHIFT_REGISTER = $8000
MMC1_CHR_BANK0_SHIFT_REGISTER = $A000
MMC1_CHR_BANK1_SHIFT_REGISTER = $C000
MMC1_PRG_BANK_SHIFT_REGISTER  = $E000

;; Controller
CONTROLLER_STATUS    = $4016
CONTROLLER_P1        = $4016
CONTROLLER_P2        = $4017
CONTROLLER_A      = %10000000
CONTROLLER_B      = %01000000
CONTROLLER_SELECT = %00100000
CONTROLLER_START  = %00010000
CONTROLLER_UP     = %00001000
CONTROLLER_DOWN   = %00000100
CONTROLLER_LEFT   = %00000010
CONTROLLER_RIGHT  = %00000001

;; Work RAM areas
SW_STACK = $0700

;; PRG Code areas
PRG_ROM = $8000
INTERRUPT_VECTOR_TABLE = $FFFA

;; HARDWARE ADDRESSES
STACK = $0100

;; BITMASKS
SPRITE_FLIP_HORIZONTAL = %01000000
DIR_VERTICAL =   %00001100
DIR_POSITIVE =   %00000101

;; RENDER FLAGS
RENDER_FLAG_NAMETABLES_FLIPPED = %00000001
RENDER_FLAG_SCROLL_LOCKED      = %10000000 ;; AND when the NMI thread has finished and the main thread needs a lock on cam_dx/cam_dy again
RENDER_FLAG_SCROLL_UNLOCKED    = %01111111 ;; AND when the main thread has finished all calculations with cam_dx/cam_dy and its safe to use these values in NMI

;; SCROLL FLAGS
SCROLL_BUFFER_LEFT_ATTR_READY      = %00001000
SCROLL_BUFFER_LEFT_NAME_READY      = %00000100
SCROLL_BUFFER_RIGHT_ATTR_READY     = %00000010
SCROLL_BUFFER_RIGHT_NAME_READY     = %00000001