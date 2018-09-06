;===============================================================================
;   MACROS - PLAYER/MISSILE GRAPHICS
;===============================================================================
; Generic, all-purpose, helper macros to shorten repetitive
; tasks and make more readable code
;===============================================================================


;===============================================================================
; Constants

; the hardware stuff

PMGOBJECTSMAX = 16  ; Mostly arbitrary.  In theory, up to 255.
					; In practice, something else: the entry index value
					; corresponding to the zbPmgCurrentIdent zero page
					; addressed cannot be referenced directly.

PMGNOOBJECT   = $FF ; a symbol to represent an object ID that
					; is not a valid object ID.
					; This also works to identify a P/M hardware
					; ID (Player 0 to 3, Missile 0 to 3) as not valid

; Three states for a set of missiles managed as Fifth Player.
; 1) NO_FIFTH_PLAYER is default for all objects.  Behave normally.
; 2) FIFTH_PLAYER means source image is written to the missile 
;    memory map as unmasked bytes like it were a player.  Use this 
;    for the Parent object (aka the first of a chained object).
; 3) FIFTH_PLAYER_CHILD will suppress all vertical position 
;    changes and any image map writes for the missile  Horizontal 
;    placement and math will still occur.  Use this on the 
;    chained objects.

; Setup of objects to make a group of missiles a fifth player...  
; If all objects are normal width then Xoffset is +2 color clocks for each:
; Object 1, PMG ID 4, FIFTH_PLAYER,       XOffset+0, Chain ID is 2.        Is Chain = 0
; Object 2, PMG ID 5, FIFTH_PLAYER_CHILD, XOffset+2, Chain ID is 3,        Is Chain = 1
; Object 3, PMG ID 6, FIFTH_PLAYER_CHILD, XOffset+2, Chain ID is 4,        Is Chain = 1
; Object 4, PMG ID 7, FIFTH_PLAYER_CHILD, XOffset+2, Chain ID is NOOBJECT, Is Chain = 1

NO_FIFTH_PLAYER    = $00
;FIFTH_PLAYER      = this is from GTIA.asm value.
FIFTH_PLAYER_CHILD = $FF

; the soft stuff...

ANIMSEQMAX    = 5    ; Number of Animation sequences managed.

SEQFRAMESMAX  = 6    ; Maximum number of frames in an animated sequence.

; Still conmtemplating this...

SEQBLANKFRAME = $FF  ; If a sequence is assigned FF, it will write 
                     ; zero value bytes over the last frame height.



;===============================================================================
; Macros/Subroutines

;===============================================================================
; 													mPmgLdxObjId  X
;===============================================================================
; Something very repetitive.
; Load the X with the object ID.
; If objID is the zero page variable for the current ID, use that.
; Otherwise values less than 256 is an explicit value, and values
; greater than or equal to 256 are from memory.

.macro mPmgLdxObjId objId
	.if :0<>1
		.error "mPmgLdxObjId: 1 argument (object ID) required."
	.endif

	.if :objID<>zbPmgCurrentIdent ; Use the page 0 value?
		mLDX_VM :objID            ; No. Either explicit or memory.
	.else
		ldx :zbPmgCurrentIdent    ; Yes.  reload from page 0.
	.endif
.endm


;===============================================================================
;														PmgInitObject
;===============================================================================
; Setup an on-screen object for the first time.
; Sets values in structure for animation.
; Call the library init to complete setup, and copy the page zero info
; into the PMGOBJECTS lists.
;
; The purpose of the library call is to initialize an entry into multiple
; memory structures for the object.  Other than the object ID itself all 
; argument value greater than 255 are assumed to be addresses and 
; everything else byte-sized is assumed to be a literal value.
;
; Everything is passed here through Page 0 to make the macro and its 
; numerous arguments less memory abusive.  The alternative would be to
; declare a populated structure of all the arguments and pass that
; by its address.  (Hmm, that actually does sound more-ish clever-like
; than what is being done here.)  The macro method allows for addresses
; to variables, so it is more flexible than a declred structure which
; would still have to be populated (at build time or more expensively, 
; at run-time).  BUT, for the purposes of the simple demo games, the 
; values are all known at build time, so using a structure would make 
; really make sense.  Have I talked myself out of anything yet?)
;
; The numerous arguments were too numerous.  It got to the point of 14 
; arguments making the invocation a messy bear.  This clearly needed some 
; logical breakdown.  
;
; The PMOBJECT is divided into three related sections:
;
; 1) Basic object and hardware values. [This routine, PmgInitObject)
; 2) position and chaining (these are related) [PmgInitPosition]
; 3) Animation information [PmgInitAnimation]
;
; This first initialization step will populate all the basic hardware 
; assignments for the PMOBJECT.  It will also zero/default all the 
; other parts in the object. This means on completion the default 
; conditions also include: 
;
; 1) The object is not chained.
; 2) The object does not chain to another object.
; 3) Horizonal and verical, and Current and Previous positions are 0.
; 4) The animation assigned is sequence 0 (Blank Frame). 
;
; Since this is not an allocating activity this could be called 
; for an object in use to re-use it.  PMOBJECT initialization does 
; not clear any display bitmap information.  It would be good form 
; for the caller to directly assign the animation to the blank 
; frame sequence and force a redraw before calling the init to 
; redo the object.
;
; Arguments:
;
; objID  - index into PMOBJECT (address) ($FF will use Page 0 memory $FF value)
; pmID   - Player (0 to 3), Missile (4-7), or PMGNOOBJECT
; Fifth  - Enable Fifth Player logic. (Use GTIA.asm's FIFTH_PLAYER/on. or 0/off)
;          * When Fifth Player is disabled (off/0) then objects using 
;          pmID values 4 to 7 will be treated as an individual missiles
;          and the library will automatically mask the animation image
;          information during updates so that it does not disturb the 
;          bits shared by other missiles.
;          * When Fifth Player is enabled, then the library will not
;          mask the image bits and will simply copy the image bytes.
;          * To effectively use Fifth Player:
;          - Assign an object using the pmIdfor Missile 3 (value 7) 
;            with FIFTH_PLAYER on.  
;          - Chain the object for Missile 2 to Missile 3.
;          - In the object for Missile 2 use an X offset from Missile 3 
;            to automatically position missile 2 next to Missile 3, 
;            (and so on to connect Missile 2 to 1 and Missile 1 to 0.)  
;          - Chained objects for missiles 2, 1, and 0 should be assigned 
;            animation 0 (blank frame). 
;          FYI: This does NOT directly affect the GPRIOR value FIFTH_PLAYER.
; color  - Value for COLPMx.  Note that the value is not copied to the color 
;          register.  It is the responsibility of the display loop to fetch
;          this value and write it to the correct color register. 
; size   - Use GTIA.asm's values for PM_SIZE_* 
; vDelay - Use GTIA.asm's values for VD_*.  Code setting VDELAY must mask based on pmID.
;

.macro mPmgInitObject objID,pmID,fifth,color,size,vDelay
	.if :0<>6
		.error "PmgInitObject: 5 arguments (object ID, P/M ID, fifth player, color, size, vDelay) required."
	.endif

	; This allows the caller to iterate through objects using the 
	; zbPmgCurrentIdent in page zero as the counter. Otherwise any 
	; other number less than 255 is assumed to be a literal value.
	.if :objID<>zbPmgCurrentIdent ; don't let it change it here.
		mLDA_VM :objID
		sta zbPmgCurrentIdent ; Set in the zero page current object id.
	.endif

	.if :pmID<8 ; Player/Missile number or turn if off ($FF)
		lda #:pmID
	.else
		lda #PMGNOOBJECT  ; Not a valid player/missile
	.endif
	sta zbPmgIdent

	mLDA_VM :fifth
	sta zbPmgFifth ; flag to make a Missile behave like a Player.

	mLDA_VM :color
	sta zbPmgColor

	mLDA_VM :size
	sta zbPmgSize

	mLDA_VM :vDelay
	sta zbPmgVDelay

	jsr libPmgInitObject
.endm


;===============================================================================
;														PmgInitPosition
;===============================================================================
; Next P/M Graphics initialization section. . .
;
; 2) position and chaining (these are related)
;
; hPos    - Logical Horizonal position, left to right, 0 to 255
; vPos    - Logical vertical position, top to bottom, 0 to 255
; chainID - objID of next object linked to this one. $FF for no chain
; isChain - Flag this is a chained object. 0/no. 1/yes. If yes, then main iteration code will skip this entry
; XOffset - Add to hPos to get "Real Hpos". (typically when this object is chained.))
; YOffset - Add to vPos to get "Real Vpos". (typically when this object is chained.))
;
; Note that the main initialization automatically zeros/sets defaults
; for all these.  If the defaults are good there's no need to 
; call this for initialization.

.macro mPmgInitPosition objID,hPos,vPos,chainID,isChain,XOffset,YOffset
	.if :0<>7
		.error "PmgInitPosition: 7 arguments (object ID, hPos, vPos, chain ID, is Chain, X Offset, Y Offset) required."
	.endif

	; This allows the caller to iterate through objects using the 
	; zbPmgCurrentIdent in page zero as the counter. Otherwise any 
	; other number less than 255 is assumed to be a literal value.
	.if :objID<>zbPmgCurrentIdent ; don't let it change it here.
		mLDA_VM :objID
		sta zbPmgCurrentIdent ; Set in the zero page current object id.
	.endif

	mLDA_VM :hPos
	sta zbPmgHPos ; Lib will copy to zbPmgRealHPos

	mLDA_VM :vPos
	sta zbPmgVPos; Lib will copy to zbPmgRealVPos and zbPmgPrevVPos

	mLDA_VM :chainID ; The next objext in the chain.
	sta zbPmgChainIdent

	mLDA_VM :isChain ; This object is a chained object.
	sta zbPmgIsChain

	mLDA_VM :XOffset ; HPos + XOffset = Real HPos
	sta zbPmgXOffset

	mLDA_VM :YOffset ; VPos + YOffset = Real VPos
	sta zbPmgYOffset

	jsr libPmgInitPosition
.endm


;===============================================================================
;														PmgInitAnim
;===============================================================================
; Next P/M Graphics initialization section. . .
;
; 3) Animation information
;
; animID     - Animation number. Index into vsSeq animation controls (NOT PMOBJECTS)
; animEnable - Enable frame/counter processing 0/disable, 1/enable.
; StartFrame - set the initial sequence frame.  vsSeqAnim Address offset. (usually 0)
;
; Note that the main initialization automatically zeros these
; values which results in assignment to the blank frame animation.
; If the defaults are good there's no need to call this for initialization.;

.macro mPmgInitAnim objID,animID,animEnable, startFrame
	.if :0<>4
		.error "PmgInitAnim: 4 arguments (object ID, animation ID, animation Enable, Start Frame) required."
	.endif

	; This allows the caller to iterate through objects using the 
	; zbPmgCurrentIdent in page zero as the counter. Otherwise any 
	; other number less than 255 is assumed to be a literal value.
	.if :objID<>zbPmgCurrentIdent ; don't let it change it here.
		mLDA_VM :objID
		sta zbPmgCurrentIdent ; Set in the zero page current object id.
	.endif

	mLDA_VM :animID
	sta zbSeqIdent

	mLDA_VM :animEnable
	sta zbSeqEnable

	mLDA_VM :startFrame
	sta zbSeqStart

	jsr libPmgInitAnim
.endm


;===============================================================================
;														PmgSetHPos  X A
;===============================================================================
; Set the Object Horizontal position.
; If this object has a chain offset, then add the offset for the real position.
; If this object is chained then the library will update the chained object.
; and if that is chained, then the same, so on.

.macro mPmgSetHPos objId, hPos
	.if :0<>2
		.error "PmgSetHPos: 2 arguments (object ID, hPos) required."
	.endif

	mPmgLdxObjId :objID ; Load X with PMGOBJECTS Id

	mLDA_VM :hPos ; Load A with logical horizontal position

	jsr libPmgSetHPos

.endm


;===============================================================================
;											PmgDidCollideWithPmg  X
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
;											PmgIsAnimPlaying  X
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
;											PmgPlayAnim  X  Y
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
;												PmgSetColor  X  A
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
