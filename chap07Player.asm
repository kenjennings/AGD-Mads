;==============================================================================
; Constants

PMG_PLAYER = 0
PMG_ENEMY0 = 1
PMG_ENEMY1 = 2
PMG_ENEMY2 = 3
PMG_ENEMY3 = 4
PMG_ENEMY4 = 5
PMG_ENEMY5 = 6
PMG_ENEMY6 = 7
PMG_ENEMY7 = 8
PMG_ENEMY8 = 9

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

; objID,pmID,fifth,color,size,vDelay,

	mPmgInitObject PMG_PLAYER,0,0,COLOR_BLACK|$08,PM_SIZE_NORMAL, 0

; objID,hPos,vPos,chainID,isChain,XOffset,YOffset,

	mPmgInitPosition PMG_PLAYER,[[PLAYER_XMIN+PLAYER_XMAX]/2], [[PLAYER_YMIN+PLAYER_YMAX]/2], PMGNOOBJECT,0,0,0

; objID,animID,animEnable,startFrame

	mPmgInitAnim PMG_PLAYER,ANIM_PLAYER,1,0

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

