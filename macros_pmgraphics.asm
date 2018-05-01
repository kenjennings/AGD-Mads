;===============================================================================
;   MACROS - PLAYER/MISSILE GRAPHICS
;===============================================================================
; Generic, all-purpose, helper macros to shorten repetitive
; tasks and make more readable code
;===============================================================================


;===============================================================================
; Constants

PMGOBJECTSMAX = 16 ;  Mostly rbitrary. Up to 255 in theory.

ANIMSEQMAX    = 5  ;  Number of Animation sequences managed.

SEQFRAMESMAX  = 6  ; Maximum number of frames in an animated sequence.



;===============================================================================
; Macros/Subroutines

;===============================================================================
;														mPmgInitObject
;===============================================================================
; Setup an on-screen object for the first time.
; Sets values in Page 0 structure for animation.
; Call the library init to complete setup, and copy the page zero info
; into the PMGOBJECTS lists.
;
; objID (address)
; pmID
; color
; size
; vDelay
; hPos
; vPos
; animID
; animEnable
;
; Since the purpose of the library call is to initialize a page zero
; memory structure for the object, is doesn;t make much sense to accomdate
; arguments as page 0 addresses other than the object ID itself.
; Therefore, all argument value greater than 255 are assumed to be
; addresses and everything else byte-sized is assumed to be a literal value.

.macro mPmgInitObject objID,pmID,color,size,vDelay,hPos,vPos,animID,animEnable
	.if :0<>9
		.error "PmgInitObject: 9 arguments (object ID, P/M ID, color, size, vDelay, hPos, vPos, animation ID, animation Enable) required."
	.endif

	; This allows the caller to iterate thriough objects using
	; zbPmgCurrentIdent as the counter.
	.if :objID<>zbPmgCurrentIdent
		.if :objID>255
			lda :objID ; Get value from memory
		.else
			lda #:objID ; Get explicit value
		.endif
		sta zbPmgCurrentIdent ; Set in the zero page current object id.
	.endif

	.if :pmID<8 ; Player/Missile number or turn if off ($FF)
		lda #:pmID
	.else
		lda #$FF  ; Actually, any negative will do.
	.endif
	sta zbPmgIdent

	.if :color>$FF ; then color is an address
		lda :color
	.else
		lda #:color
	.endif
	sta zbPmgColor

	.if :size>$FF ; then size is an address
		lda :size
	.else
		lda #:size
	.endif
	sta zbPmgSize

	.if :vDelay>$FF ; then vDelay is an address
		lda :vDelay
	.else
		lda #:vDelay
	.endif
	sta zbPmgVDelay

	.if :hPos>$FF ; then hPos is an address
		lda :hPos
	.else
		lda #:hPos
	.endif
	sta zbPmgHPos ; Lib will copy to zbPmgRealHPos

	.if :vPos>$FF ; then vPos is an address
		lda :vPos
	.else
		lda #:vPos
	.endif
	sta zbPmgVPos; Lib will copy to zbPmgRealVPos and zbPmgPrevVPos

	.if :animID>$FF ; then animID is an address
		lda :animID
	.else
		lda #:animID
	.endif
	sta zbPmgSeqIdent


	.if :animEnable>$FF ; then animEnable is an address
		lda :animEnable
	.else
		lda #:animEnable
	.endif
	sta zbSeqEnable

	jsr libPmgInitObject
.endm


zbPmgCurrentIdent  .byte 0   ; current index number for PMGOBJECTS
zbPmgEnable        .byte 0   ; Object is on/1 or off/0.  If off, skip processing.
zbPmgIdent         .byte $FF ; Missile 0 to 3. Player 4 to 7.  FF is unused

zbPmgColor         .byte 0   ; Color of each object.
zbPmgSize          .byte 0   ; HSize of object.
zbPmgVDelay        .byte 0   ; VDelay (for double line resolution.)

zwPmgAddr          .word 0   ; objects' PMADR base (zwPmgAddr),zbPmgRealVPos

zbPmgHPos          .byte 0   ; X position of each object (logical)
zbPmgRealHPos      .byte 0   ; Real X position on screen (if controls adjusts PmgHPos)

zbPmgVPos          .byte 0   ; Y coordinate of each object (logical)
zbPmgRealVPos      .byte 0   ; Real Y position on screen (if controls adjusts PmgVPos)
zbPmgPrevVPos      .byte 0   ; Previous Y position before move  (if controls adjusts PmgVPos)

zbPmgCollideToField  .byte 0   ; Display code's collected M-PF or P-PF collision value.
zbPmgCollideToPlayer .byte 0   ; Display code's collected M-PL or P-PL collision value.

zbPmgAnimIdent     .byte 0   ; Animation ID in use
zbPmgAnimEnable    .byte 0   ; Animation is playing/1 or stopped/0

zwPmgAnimSeqAddr      .word 0   ; address of of animation sequence structure (zbPmgAnimLo),zbPmgAnimSeqFrame
zbPmgAnimSeqCount     .byte 0   ; Number of frames in the animation sequence.
zbPmgAnimSeqFrame     .byte 0   ; current index into frame list for this sequence.
zbPmgAnimPrevSeqFrame .byte 0   ; previous index used in this sequence. (No change means no redraw)

zbPmgAnimDelay      .byte 0   ; Number of TV frames to wait for each animation frame
zbPmgAnimDelayCount .byte 0   ; Frame countdown when vsAnimDelay is not zero

zbPmgAnimLoop       .byte 0   ; Does animation sequence repeat? 0/no, 1/yes
zbPmgAnimBounce     .byte 0   ; Does repeat go ABCDABCD or ABCDCBABCD (0/linear, 1/bounce)
zbPmgAnimSeqDir     .byte 0   ; Current direction of animation progression. + or -

zwAnimFrameAddr     .word 0   ; Address of current image frame
zwAnimFrameHeight   .byte 0   ; Height of current image frame.





defm    LIBSPRITE_DIDCOLLIDEWITHSPRITE_A  ; /1 = Sprite Number (Address)

        ldy /1
        lda SpriteNumberMask,y
        and SPSPCL

        endm


;==============================================================================

defm    LIBSPRITE_ISANIMPLAYING_A      ; /1 = Sprite Number    (Address)

        ldy /1
        lda spriteAnimsActive,y

        endm


;==============================================================================

defm    LIBSPRITE_PLAYANIM_AVVVV        ; /1 = Sprite Number    (Address)
                                        ; /2 = StartFrame       (Value)
                                        ; /3 = EndFrame         (Value)
                                        ; /4 = Speed            (Value)
                                        ; /5 = Loop True/False  (Value)

        ldy /1

        lda #True
        sta spriteAnimsActive,y
        lda #/2
        sta spriteAnimsStartFrame,y
        sta spriteAnimsFrame,y
        lda #/3
        sta spriteAnimsEndFrame,y
        lda #/4
        sta spriteAnimsSpeed,y
        sta spriteAnimsDelay,y
        lda #/5
        sta spriteAnimsLoop,y

        endm

;===============================================================================
;														mPmgSetColor_MV
;===============================================================================
; Set Color for a player 0 to 3.
; "Missiles" are also Player 0 to 3.
; Any value greater than 3 will change the "fifth" player color COLOR3.
;
; Sprite Number    (Address)
; Color            (Value)

.macro mPmgSetColor_MV objID,color
	ldy #:objID
	lda #:color

	jsr libPmgSetColor
.endm

;===============================================================================
;														mPmgSetColor_MM
;===============================================================================
; Set Color for a player 0 to 3.
; "Missiles" are also Player 0 to 3.
; Any value greater than 3 will change the "fifth" player color COLOR3.
;
; Sprite Number    (Address)
; Color            (Value)

.macro mPmgSetColor_MM objID,color
	ldy #:objID
	lda :color

	jsr libPmgSetColor
.endm

;===============================================================================
;														mPmgSetColor
;===============================================================================
; PmgSetColor wrapper.
;
; If color is greater then 255, then it is an address.
;
; Sprite Number    (Address)
; Color            (Value)

.macro mPmgSetColor pmgNumber,color
	.if :0<>2
		.error "PmgSetColor: 2 arguments (P/M number, color) required."
	.else
		.if :color>255 ; then color is an address
			mPmgSetColor_MM pmgNumber,color
		.else
			mPmgSetColor_MV pmgNumber,color
		.endif
	.endif
.endm


;==============================================================================

defm    LIBSPRITE_SETFRAME_AA           ; /1 = Sprite Number    (Address)
                                        ; /2 = Anim Index       (Address)
        ldy /1

        clc     ; Clear carry before add
        lda /2  ; Get first number
        adc #SPRITERAM ; Add

        sta SPRITE0,y
        endm

	jsr libPmSetFrame

;===============================================================================

defm    LIBSPRITE_SETFRAME_AV           ; /1 = Sprite Number    (Address)
                                        ; /2 = Anim Index       (Value)
        ldy /1

        clc     ; Clear carry before add
        lda #/2  ; Get first number
        adc #SPRITERAM ; Add

        sta SPRITE0,y
        endm

;===============================================================================

defm    LIBSPRITE_SETMULTICOLORS_VV     ; /1 = Color 1          (Value)
                                        ; /2 = Color 2          (Value)
        lda #/1
        sta SPMC0
        lda #/2
        sta SPMC1
        endm

;===============================================================================

defm    LIBSPRITE_SETPOSITION_AAAA      ; /1 = Sprite Number    (Address)
                                        ; /2 = XPos High Byte   (Address)
                                        ; /3 = XPos Low Byte    (Address)
                                        ; /4 = YPos             (Address)

        lda /1                  ; get sprite number
        asl                     ; *2 as registers laid out 2 apart
        tay                     ; copy accumulator to y register

        lda /3                  ; get XPos Low Byte
        sta SP0X,y              ; set the XPos sprite register
        lda /4                  ; get YPos
        sta SP0Y,y              ; set the YPos sprite register

        ldy /1
        lda spriteNumberMask,y  ; get sprite mask

        eor #$FF                ; get compliment
        and MSIGX               ; clear the bit
        sta MSIGX               ; and store

        ldy /2                  ; get XPos High Byte
        beq @end                ; skip if XPos High Byte is zero
        ldy /1
        lda spriteNumberMask,y  ; get sprite mask

        ora MSIGX               ; set the bit
        sta MSIGX               ; and store
@end
        endm

;===============================================================================

defm    LIBSPRITE_SETPOSITION_VAAA      ; /1 = Sprite Number    (Value)
                                        ; /2 = XPos High Byte   (Address)
                                        ; /3 = XPos Low Byte    (Address)
                                        ; /4 = YPos             (Address)

        ldy #/1*2               ; *2 as registers laid out 2 apart
        lda /3                  ; get XPos Low Byte
        sta SP0X,y              ; set the XPos sprite register
        lda /4                  ; get YPos
        sta SP0Y,y              ; set the YPos sprite register

        lda #1<<#/1             ; shift 1 into sprite bit position
        eor #$FF                ; get compliment
        and MSIGX               ; clear the bit
        sta MSIGX               ; and store

        ldy /2                  ; get XPos High Byte
        beq @end                ; skip if XPos High Byte is zero
        lda #1<<#/1             ; shift 1 into sprite bit position
        ora MSIGX               ; set the bit
        sta MSIGX               ; and store
@end
        endm


;===============================================================================

defm    LIBSPRITE_SETPRIORITY_AV ; /1 = Sprite Number           (Address)
                                 ; /2 = True = Back, False = Front (Value)
        ldy /1
        lda spriteNumberMask,y

        ldy #/2
        beq @disable
@enable
        ora SPBGPR ; merge with the current SPBGPR register
        sta SPBGPR ; set the new value into the SPBGPR register
        jmp @done
@disable
        eor #$FF ; get mask compliment
        and SPBGPR
        sta SPBGPR
@done
        endm

;==============================================================================

defm    LIBSPRITE_STOPANIM_A            ; /1 = Sprite Number    (Address)

        ldy /1
        lda #0
        sta spriteAnimsActive,y

        endm

;==============================================================================

libSpritesUpdate

        ldx #0
lSoULoop
        ; skip this sprite anim if not active
        lda spriteAnimsActive,X
        bne lSoUActive
        jmp lSoUSkip
lSoUActive

        stx spriteAnimsCurrent
        lda spriteAnimsFrame,X
        sta spriteAnimsFrameCurrent

        lda spriteAnimsEndFrame,X
        sta spriteAnimsEndFrameCurrent

        LIBSPRITE_SETFRAME_AA spriteAnimsCurrent, spriteAnimsFrameCurrent

        dec spriteAnimsDelay,X
        bne lSoUSkip

        ; reset the delay
        lda spriteAnimsSpeed,X
        sta spriteAnimsDelay,X

        ; change the frame
        inc spriteAnimsFrame,X

        ; check if reached the end frame
        lda spriteAnimsEndFrameCurrent
        cmp spriteAnimsFrame,X
        bcs lSoUSkip

        ; check if looping
        lda spriteAnimsLoop,X
        beq lSoUDestroy

        ; reset the frame
        lda spriteAnimsStartFrame,X
        sta spriteAnimsFrame,X
        jmp lSoUSkip

lSoUDestroy
        ; turn off
        lda #False
        sta spriteAnimsActive,X
        LIBSPRITE_ENABLE_AV spriteAnimsCurrent, False

lSoUSkip
        ; loop for each sprite anim
        inx
        cpx #SpriteAnimsMax
        ;bne lSUloop
        beq lSoUFinished
        jmp lSoUloop
lSoUFinished

        rts
