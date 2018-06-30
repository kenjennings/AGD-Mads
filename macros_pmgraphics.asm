;===============================================================================
;   MACROS - PLAYER/MISSILE GRAPHICS
;===============================================================================
; Generic, all-purpose, helper macros to shorten repetitive
; tasks and make more readable code
;===============================================================================


;===============================================================================
; Constants

PMGOBJECTSMAX = 16 ; Mostly arbitrary.  In theory, up to 255.  
                 ; In practice, something else: the entry index value 
                 ; corresponding to the zbPmgCurrentIdent zero page 
                 ; addressed cannot be referenced directly.

ANIMSEQMAX    = 5  ; Number of Animation sequences managed.  

SEQFRAMESMAX  = 6  ; Maximum number of frames in an animated sequence.



;===============================================================================
; Macros/Subroutines

;===============================================================================
; 													mPmgLdxObjId  X
;===============================================================================
; Something very repetetive.
; Load the X with the object ID.
; If objID is the zero page variable for the current ID, use that.
; Otherwise values less than 256 is an explicit value, and values
; greater than or equal to 256 are from memory.

.macro mPmgLdxObjId objId
	.if :0<>1
		.error "mPmgLdxObjId: 1 argument (object ID) required."
	.endif

	.if :objID<>zbPmgCurrentIdent ; Use the page 0 value?
		mLDX_VM :objID          ; No. Either explicit or memory. 
	.else 
		ldx :zbPmgCurrentIdent   ; Yes.  reload from page 0.
	.endif
.endm


;===============================================================================
;														mPmgInitObject
;===============================================================================
; Setup an on-screen object for the first time.
; Sets values in Page 0 structure for animation.
; Call the library init to complete setup, and copy the page zero info
; into the PMGOBJECTS lists.
; (Everything is done here through Page 0 to make the macro and its 9 
; arguments less memory abusive.  The alternative would be to 
; declare a populated structure of all the arguments and pass that
; by its address.  The macro method allows for addresses to variables,
; so it is more flexible than a declred structure which would have 
; to be determined at build time.  BUT, for the purposes of the simple
; demo, the values are all known at build time, so using a structure
; would make sense.  Have I talked myself out of anything yet?)
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
; memory structure for the object, it doesn't make much sense to accommodate
; arguments as page 0 addresses other than the object ID itself.
; Therefore, all argument value greater than 255 are assumed to be
; addresses and everything else byte-sized is assumed to be a literal value.

.macro mPmgInitObject objID,pmID,color,size,vDelay,hPos,vPos,animID,animEnable
	.if :0<>9
		.error "PmgInitObject: 9 arguments (object ID, P/M ID, color, size, vDelay, hPos, vPos, animation ID, animation Enable) required."
	.endif

	; This allows the caller to iterate through objects using
	; the zbPmgCurrentIdent in page zero as the counter.
	; Otherwise any other number less than 255 is assumed to be a
	; literal value.
	.if :objID<>zbPmgCurrentIdent ; don't let it change it here.
		mLDA_VM :objID
		sta zbPmgCurrentIdent ; Set in the zero page current object id.
	.endif

	.if :pmID<8 ; Player/Missile number or turn if off ($FF)
		lda #:pmID
	.else
		lda #$FF  ; Actually, any negative will do.
	.endif
	sta zbPmgIdent

	mLDA_VM :color
	sta zbPmgColor

	mLDA_VM :size
	sta zbPmgSize

	mLDA_VM :vDelay
	sta zbPmgVDelay

	mLDA_VM :hPos
	sta zbPmgHPos ; Lib will copy to zbPmgRealHPos

	mLDA_VM :vPos
	sta zbPmgVPos; Lib will copy to zbPmgRealVPos and zbPmgPrevVPos

	mLDA_VM :animID
	sta zbPmgSeqIdent

	mLDA_VM :animEnable
	sta zbSeqEnable

	jsr libPmgInitObject
.endm


;===============================================================================
;											mPmgDidCollideWithPmg  X
;===============================================================================
; Check the collision  value for this (Y) objects's Player/Missile object.
; This is testing the value in a PMGOBJECTS list.
; This value must have been collected by a process highly dependant on 
; screen placements.  
; After clearing the collision register the next reliable read to populate 
; this value in the list must occur AFTER the Player/Missile object has 
; been displayed.
;

.macro mPmgDidCollideWithPmg objID
	.if :0<>1
		.error "PmgDidCollideWithPmg: 1 argument (object ID) required."
	.endif

	mPmgLdxObjId :objID ; Load X with PMGOBJECTS Id

	lda vsPmgCollideToPlayer, X
.endm


;===============================================================================
;											mPmgIsAnimPlaying  X
;===============================================================================
; Check the anim progress value for this (X) objects's Player/Missile object.

.macro mPmgIsAnimPlaying objID
	.if :0<>1
		.error "mPmgIsAnimPlaying: 1 argument (object ID) required."
	.endif

	mPmgLdxObjId :objID ; Load X with PMGOBJECTS Id

	lda vsSeqEnable, X
.endm


;===============================================================================
;											mPmgPlayAnim  X  Y
;===============================================================================
; Start the anim playing this (X) objects's Player/Missile object.
; Note this only (re)assigns the sequence to an item on the PMGOBJECTS lists.
; This does not actually cause a display change.
; For the display to change the image update routine must be invoked.

.macro mPmgPlayAnim objID, seqId
	.if :0<>2
		.error "mPmgPlayAnim: 2 arguments (object ID, sequence ID) required."
	.endif

	mPmgLdxObjId :objID ; Load X with PMGOBJECTS Id

	mLDY_VM :seqId     ; Load Y with sequence number 

	jsr libPmgSetSequence

.endm


;===============================================================================
;												mPmgSetColor  X  A
;===============================================================================
; Set Color for a PMGOBJECTS entry.
; This is not updating actual color registers.  
; This only updates the color in a PMGOBJECTS list of objects.
;
; Object ID Number    (Address) aka Sprite number
; Color               (Value)

.macro mPmgSetColor objID,color
	mPmgLdxObjId :objID ; Load X with PMGOBJECTS Id
	lda #:color

	sta vsPmgColor,x
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
