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

;; APU (Audio)
APUCTRL   = $4010
APUFC     = $4017

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

;; PRG Code areas
INTERRUPT_VECTOR_TABLE = $FFFA

;; HARDWARE ADDRESSES
STACK = $0100
SPRITE_AREA = $0200
BANKSWITCH_ADDR = $9000 ; Can be anywhere in PRG ROM actually

;; BITMASKS
SPRITE_FLIP_HORIZONTAL = %01000000

;; GAME CONSTANTS
STATE_TITLE        = %00000000
STATE_ACTION       = %10000000
STATE_P1_WIN       = %01000000
STATE_P2_WIN       = %00100000
STATE_MASK_FLAGS   = %00011111
STATE_BALL_LEFT    = %00000100
STATE_BALL_UP      = %00000010
STATE_AI_PADDLE_UP = %00000001

STRINGS_PRESS_START_SIZE = $0B
STRINGS_WINNER_SIZE = $07

LEFT_PADDLE = $30
RIGHT_PADDLE = $C8

TOP_WALL = $20
BOTTOM_WALL = $C0
LEFT_WALL = $08
RIGHT_WALL = $F8

DIR_UP    = %00001000
DIR_DOWN  = %00000100
DIR_LEFT  = %00000010
DIR_RIGHT = %00000001
DIR_VERTICAL =   %00001100
DIR_POSITIVE =   %00000101
