;==============================================================================
; Constants

PLAYER_FRAME           = 1
PLAYER_HORIZONTALSPEED = 2
PLAYER_VERTICALSPEED   = 1
; PLAYERXMINHIGH        = 0     ; 0*256 + 24 = 24  minX
; PLAYERXMINLOW         = 24
PLAYER_XMIN            = 24
; PLAYERXMAXHIGH        = 1     ; 1*256 + 64 = 320 maxX
; PLAYERXMAXLOW         = 64
PLAYER_XMAX            = 64
PLAYER_YMIN            = 180
PLAYER_YMAX            = 229

;===============================================================================
; Variables

playerSprite .byte 0
playerX      .byte 0
;playerXHigh  .byte 0
;playerXLow   .byte 175
PlayerY      .byte 229

;===============================================================================
; Macros/Subroutines

libGamePlayerInit
;	LIBSPRITE_ENABLE_AV             playerSprite, True
; N/A Atari

; objID,pmID,color,size,vDelay,hPos,vPos,chainID,XOffset,YOffset,animID,animEnable

	mPmgInitObject 0,0, COLOR_BLACK|$08, PM_SIZE_NORMAL, 0,[[PLAYER_XMIN+PLAYER_XMAX]/2], [[PLAYER_YMIN+PLAYER_YMAX]/2], PMGNOOBJECT,0,1,1

;	LIBSPRITE_SETFRAME_AV           playerSprite, PLAYERFRAME
;	mPmgSetFrame playerSprite, PLAYER_FRAME

;	LIBSPRITE_SETCOLOR_AV           playerSprite, LightGray
;	mPmgSetColor playerSprite, COLOR_BLACK|$08

;	LIBSPRITE_MULTICOLORENABLE_AV   playerSprite, True
; N/A Atari

	rts

;===============================================================================

libGamePlayerUpdate

	jsr gamePlayerUpdatePosition

	rts


;===============================================================================

gamePlayerUpdatePosition

	LIBINPUT_GETHELD GameportLeftMask
	bne gPUPRight

	LIBMATH_SUB16BIT_AAVVAA playerXHigh, PlayerXLow, 0, PlayerHorizontalSpeed, playerXHigh, PlayerXLow

gPUPRight
	LIBINPUT_GETHELD GameportRightMask
	bne gPUPUp

	LIBMATH_ADD16BIT_AAVVAA playerXHigh, PlayerXLow, 0, PlayerHorizontalSpeed, playerXHigh, PlayerXLow

gPUPUp
	LIBINPUT_GETHELD GameportUpMask
	bne gPUPDown
	LIBMATH_SUB8BIT_AVA PlayerY, PlayerVerticalSpeed, PlayerY

gPUPDown
	LIBINPUT_GETHELD GameportDownMask
	bne gPUPEndmove
	LIBMATH_ADD8BIT_AVA PlayerY, PlayerVerticalSpeed, PlayerY

gPUPEndmove
	; clamp the player x position
	LIBMATH_MIN16BIT_AAVV playerXHigh, playerXLow, PlayerXMaxHigh, PlayerXMaxLow
	LIBMATH_MAX16BIT_AAVV playerXHigh, playerXLow, PlayerXMinHigh, PlayerXMinLow

	; clamp the player y position
	LIBMATH_MIN8BIT_AV playerY, PlayerYMax
	LIBMATH_MAX8BIT_AV playerY, PlayerYMin

	; set the sprite position
	LIBSPRITE_SETPOSITION_AAAA playerSprite, playerXHigh, PlayerXLow, PlayerY

	rts

