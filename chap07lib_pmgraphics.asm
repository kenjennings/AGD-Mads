; ==========================================================================
; Data declarations and subroutine library code
; performing Player/missile operations.
;
; REQUIRED DEFINITIONS:
;
; PMG_RES
; Player/Missile resolution for pmgraphics macros/library.
; Recommended to use ANTIC.asm's PM_1LINE_RESOLUTION and 
; PM_2LINE_RESOLUTION labels for assignment in the code.
; i.e. PMG_RES=PM_2LINE_RESOLUTION
; If the command line build is necessary this is:
; PMG_RES=0 which is PM_2LINE_RESOLUTION, or 2 line resolution. 
;    (128 vertical pixels, or 2 scan lines per byte)
; PMG_RES=8 which is PM_1LINE_RESOLUTION, or 1 line resolution 
;    (256 vertical pixels, or 1 scan lines per byte)
;
; vsPmgRam
; This must be declared in Memory as the PMBASE


; ==========================================================================
; Player/Missile memory is declared in the Memory file.

; Establish a few other immediate values relative to PMBASE

; For Single Line Resolution:

.if PMG_RES=PM_1LINE_RESOLUTION
MISSILEADR = vsPmgRam+$300
PLAYERADR0 = vsPmgRam+$400
PLAYERADR1 = vsPmgRam+$500
PLAYERADR2 = vsPmgRam+$600
PLAYERADR3 = vsPmgRam+$700
.endif

; For Double Line Resolution:

.if PMG_RES=PM_2LINE_RESOLUTION
MISSILEADR = vsPmgRam+$180
PLAYERADR0 = vsPmgRam+$200
PLAYERADR1 = vsPmgRam+$280
PLAYERADR2 = vsPmgRam+$300
PLAYERADR3 = vsPmgRam+$380
.endif


vsPmgRamAddrLo
	.byte <MISSILEADR, <MISSILEADR, <MISSILEADR, <MISSILEADR
	.byte <PLAYERADR0, <PLAYERADR1, <PLAYERADR2, <PLAYERADR3

vsPmgRamAddrHi
	.byte >MISSILEADR, >MISSILEADR, >MISSILEADR, >MISSILEADR
	.byte >PLAYERADR0, >PLAYERADR1, >PLAYERADR2, >PLAYERADR3

;===============================================================================
; The Atari has four, 8-bit wide "player" objects, and four, 2-bit wide
; "missile" objects per scan line.  Naturally, this poses some limits and
; requires some cleverness to make it appear there are more objects.
;
; In spite of the limitations the system is highly flexible, and no
; library for games can account for all the possible uses.  This library
; could be overkill for a program using Player/Missiles as overlay objects
; to add color to the playfield.  It could also be inadequate for a program
; running a horizontal kernel to duplicate player/missile objects on the
; same scanline.  This is anattempt at a happy medium.
;
; This P/M Graphics library is a level of abstraction above the direct hardware
; and can implement an animated image of any number of objects.  It is the
; responsibility of other code  to track and control the number of objects
; residing on the same scan line.
;
; On the good side, since the Player/Missile bitmap is inherently the height
; of the screen, re-use of objects is partly built-in.  Making another image
; appear lower on the screen is only a matter of writing the bitmap data into
; the proper place in memory.  Vertical placement of objects and animation of
; objects are the exact same activity -- again, both are simply a matter of
; writing the desired image bitmap into the proper place in memory.

; Making the Player appear at a different horizontal location is where things
; must get clever. Since horizontal placement is limited by the number of
; horizontal position registers which is limited by the number of hardware
; overlay objects in GTIA then the library operates at a level above the
; hardware where it manages horizontal coordinates for objects, but does not
; change the actual hardware horizontal position registers.
;
; Since horizontal placement is a scanline by scanline activity it is the
; job of either main program code, vertical blank interrupt code, or display
; list interrupt code (or combinations thereof) to copy the horizontal
; position values to the hardware registers at the right time.
;
; Player/Missile color and horizontal size are also related to hardware write
; registers, so these can also be moved to this higher level of management.
;
; In short, for N objects this library maintains arrays of N "shadow registers"
; along with the arrays of N entries describing animation pointers, animation
; state, X and Y values, etc.  Its realtionship to the hardware is only that it
; copies bitmap images per the animation states to memory which happens to be
; where ANTIC reads them.  (It could write somewhere else completely different
; and the library would still function correctly to manage the object data.)
;
; So, the architecture here is the "animation object" for display.
; This libary uses the Animation data to mange image display and then
; applies this to the Player/Missile object memory.
;
; Animation ID numbers yield...
; lists of sequence numbers and control info which yield...
; list of frame numbers which yield...
; addresses to bitmaps.
; Or
; Player Object -> Animation number, sequence index, and current sequence step
; sequence step -> frame number
; frame number -> bitmap address

; Random stream of consciousness concluded.


;===============================================================================
; Variables

; Managing objects. . .
; This is the working part of an animated object on the screen.
; There is a part attached to the hardware, and a part that
; references the Animation sequences.

vsPmgEnable          .ds PMGOBJECTSMAX, 0   ; Object is on/1 or off/0.  If off, skip processing.
vsPmgIdent           .ds PMGOBJECTSMAX, $FF ; Missile 0 to 3. Player 4 to 7.  FF is unused

; Direct hardware relationships...

vsPmgColor           .ds PMGOBJECTSMAX, 0 ; Color of each object.
vsPmgSize            .ds PMGOBJECTSMAX, 0 ; HSize of object.
vsPmgVDelay          .ds PMGOBJECTSMAX, 0 ; VDelay (for double line resolution.)

vsPmgCollideToField  .ds PMGOBJECTSMAX, 0 ; Display code's collected M-PF or P-PF collision value.
vsPmgCollideToPlayer .ds PMGOBJECTSMAX, 0 ; Display code's collected M-PL or P-PL collision value.

vsPmgAddrLo          .ds PMGOBJECTSMAX, 0 ; Low Byte of objects' PMADR base
vsPmgAddrHi          .ds PMGOBJECTSMAX, 0 ; High Byte of objects' PMADR base

vsPmgHPos            .ds PMGOBJECTSMAX, 0 ; X position of each object (logical)
vsPmgRealHPos        .ds PMGOBJECTSMAX, 0 ; Real X position on screen (if logic adjust from PmgHPos)
vsPmgPrevHPos        .ds PMGOBJECTSMAX, 0 ; Previous Real X position before move (May be used to determine if linked object must move, too)

; Still "hardware", but not registers. Just memory offsets.

vsPmgVPos            .ds PMGOBJECTSMAX, 0 ; Y coordinate of each object (logical)
vsPmgRealVPos        .ds PMGOBJECTSMAX, 0 ; Real Y position on screen (if logic adjusts PmgVPos)
vsPmgPrevVPos        .ds PMGOBJECTSMAX, 0 ; Previous Real Y position before move  (if controls adjusts PmgVPos)

vsPmgChainIdent      .ds PMGOBJECTSMAX, 0 ; Object ID of next object linked to this. 
vsPmgChainOffset     .ds PMGOBJECTSMAX, 0 ; X Offset if this is chained. Real x/HPOS

; Animation sequence playing . . .

vsSeqIdent           .ds PMGOBJECTSMAX, 0 ; (R) Animation ID in use
vsSeqEnable          .ds PMGOBJECTSMAX, 0 ; (R/W) Animation is playing/1 or stopped/0

vsSeqLo              .ds PMGOBJECTSMAX, 0 ; (R) low byte of animation sequence structure in use
vsSeqHi              .ds PMGOBJECTSMAX, 0 ; (R) high byte of animation sequence structure in use

vsSeqFrameCount      .ds PMGOBJECTSMAX, 0 ; (R) Number of frames in the animation sequence.
vsSeqFrameIndex      .ds PMGOBJECTSMAX, 0 ; (W) current index into frame list for this sequence.
vsSeqFrameCurrent    .ds PMGOBJECTSMAX, 0 ; (W) current frame number.
vsSeqFramePrev       .ds PMGOBJECTSMAX, 0 ; (W) previous frame number. (No change means no redraw)

vsSeqFrameDelay      .ds PMGOBJECTSMAX, 0 ; (R) Number of TV frames to wait for each animation frame
vsSeqDelayCount      .ds PMGOBJECTSMAX, 0 ; (W) Frame countdown when SeqDelay is not zero

vsSeqFrameLoop       .ds PMGOBJECTSMAX, 0 ; (R) Does animation sequence repeat? 0/no, 1/yes
vsSeqFrameBounce     .ds PMGOBJECTSMAX, 0 ; (R) Does repeat go ABCDABCD or ABCDCBABCD (0/linear, 1/bounce)
vsSeqFrameDir        .ds PMGOBJECTSMAX, 0 ; (W) Current direction of animation progression.

; Managing Animation Frame Bitmap Images. . .

; This organizes the data for the animation sequences.
; This is all reference information.  It is not modified
; at run-time by any code.

; Table of starting address for each image.
; Currently, designed for 256 addresses or 256 animation frame images.
; Given an entry from a sequence list (aka frame ID):

vsFrameAddrLo ; Low Byte of each animation image.
	.byte <vsImageBlank  ; 0
	.byte <vsImagePlayer ; 1
	.byte <vsImageEnemy1 ; 2
	.byte <vsImageEnemy2 ; 3
	.rept 5,#           ; 4, 5, 6, 7, 8
		.byte <[21*:1+vsImageExplosion]
	.endr

vsFrameAddrHi ; High Byte of each animation image
	.byte >vsImageBlank  ; 0
	.byte >vsImagePlayer ; 1
	.byte >vsImageEnemy1 ; 2
	.byte >vsImageEnemy2 ; 3
	.rept 5,#           ; 4, 5, 6, 7, 8
		.byte >[21*:1+vsImageExplosion]
	.endr

vsFrameHeight ; Number of Bytes in each animation image
	.ds 9,21 ; All frames 21 bytes tall


; Managing Animation Sequences,
; given a sequence ID...

vsSeq0 .byte 0 ; Blank, do nothing (frame number 0)

vsSeq1 .byte 1 ; Player animation image (frame number 1)

vsSeq2 .byte 2 ; Enemy 1 animation image (frame number 2)

vsSeq3 .byte 3 ; Enemy 2 animation image (frame number 3)

vsSeq4 .byte 4,5,6,7,8,0 ; Explosion animation images (frame numbers 4 to 8, and then blank)

vsSeqAnimLo ; Low byte of address of each animation frame sequence.
	.byte <vsSeq0 ; Blankitty-blank
	.byte <vsSeq1 ; Player
	.byte <vsSeq2 ; Enemy 1
	.byte <vsSeq3 ; Enemy 2
	.byte <vsSeq4 ; Explosion

vsSeqAnimHi ; Low byte of address of each animation frame sequence.
	.byte >vsSeq0 ; Blankitty-blank
	.byte >vsSeq1 ; Player
	.byte >vsSeq2 ; Enemy 1
	.byte >vsSeq3 ; Enemy 2
	.byte >vsSeq4 ; Explosion

vsSeqCount  .byte 1,1,1,1,6 ; Number of frames in the sequence. 

vsSeqStop   .byte 0,0,0,0,5 ; Sequence frame number to use for display when stopped.
							  ; Note this is not the Anim Frame ID.  It is Sequence index.

vsSeqDelay  .byte 0,0,0,0,1 ; Number of TV frames to pause before updating sequence.

vsSeqLoop   .byte 0,0,0,0,0 ; Does sequence repeat? 0/no, 1/yes

vsSeqBounce .byte 0,0,0,0,0 ; Does repeat go ABCDABCD or ABCDCBABCD (0/linear, 1/bounce)


;===============================================================================
;												libPmgInitObject  A X Y
;===============================================================================
; Setup an on-screen object for the first time.
;
; The macro puts the hardware values and coordinates into the
; Page 0 locations.  This routine finalizes the Page Zero
; locations.  Then the object is copied from Page Zero back
; to the real PMOBJECTS entry location.
;
; These base values in the Page 0 structure are set
; by the macro:
;     objID   ; pmID   ; color   ; size    ; vDelay
;     hPos    ; vPos
;     animID  ; animEnable
;
;Now, finish the rest...

libPmgInitObject
	; The physical hardware associations. . .

	ldx zbPmgCurrentIdent
	jsr libPmgZeroObject  ; Zero all PMOBJECTS variables.

	ldy zbPmgIdent

	; By default an initized object is all 0 values, so the
	; object is already disabled.

	; The Player/Missile object is negative, so leave it disabled.  
	bmi bDoPmgInitContinue

	; Otherwise, enable the object.
	inc vsPmgEnable,x ; Evilness.

	; And reset the hardware-specific pointer and P/M ID
	jsr libPmgResetBase

	; Copy the remaining values to P/M object.
bDoPmgInitContinue
	jsr libPmgCopyZPToObject 

	; Next, the animation data associations.
	; Even though the hardware P/M object may be 
	; disabled, the animation will still be set up and
	; the enable flag updated to whatever was given as
	; the initialization argument.

	lda zbSeqEnable
	ldy zbSeqIdent

	jsr libPmgSetupAnim

	rts


;===============================================================================
;												libPmgZeroObject  A X
;===============================================================================
; Zero all the PMOBJECTS variables and leave the 
; PMOBJECT and animation disabled.
;
; X  = the current PMOBJECT ID.

libPmgZeroObject

	lda #0

	sta vsPmgEnable,x
	sta vsPmgIdent,x

	sta vsPmgColor,x
	sta vsPmgSize,x
	sta vsPmgVDelay,x
	sta vsPmgCollideToField,x  
	sta vsPmgCollideToPlayer,x 

	sta vsPmgAddrLo,x 
	sta vsPmgAddrHi,x

	sta vsPmgHPos,x
	sta vsPmgRealHPos,x

	sta vsPmgVPos,x
	sta vsPmgRealVPos,x
	sta vsPmgPrevVPos,x

	sta vsSeqIdent,x
	sta vsSeqEnable,x

	sta vsSeqLo,x
	sta vsSeqHi,x

	sta vsSeqFrameCount,x
	sta vsSeqFrameIndex,x
	sta vsSeqFrameCurrent,x
	sta vsSeqFramePrev,x

	sta vsSeqFrameDelay,x
	sta vsSeqDelayCount,x
	sta vsSeqFrameLoop,x
	sta vsSeqFrameBounce,x
	sta vsSeqFrameDir,x

	rts


;===============================================================================
;												PmgResetBase  A  X  Y
;===============================================================================
; Repopulate the Player/Missile base address in the 
; current PMOBJECTs (X) for the Player/Missile object (Y)

libPmgResetBase

	lda vsPmgRamAddrLo,y
	sta vsPmgAddrLo,x
	lda vsPmgRamAddrHi,y
	sta vsPmgAddrHi,x

	sty vsPmgIdent,x

	rts


;===============================================================================
;												PmgCopyZPToObject  A X
;===============================================================================
; Copy the Page zero values to the current Player/Missile object:
; Excluding the PM/Base Address and P/M ident.
;
; X  = the current PMOBJECT ID.
; A  = sequence enable flag.
; Y  = the sequence ID.

libPmgCopyZPToObject

	lda zbPmgColor
	sta vsPmgColor,x

	lda zbPmgSize
	sta vsPmgSize,x

	lda zbPmgVDelay
	sta vsPmgVDelay,x

	lda zbPmgHPos
	sta vsPmgHPos,x
	sta vsPmgRealHPos,x

	lda zbPmgVPos
	sta vsPmgVPos,x
	sta vsPmgRealVPos,x
	sta vsPmgPrevVPos,x

	rts


;===============================================================================
;												PmgSetupAnim  A X Y
;===============================================================================
; Setup to "Play" animation... 
; Assigns the animation sequence values in a PMOBJECT.
;
; Note that even if the PMOBJECT is "disabled" the 
; sequence information will still be established.
; Animations just don't play when the PMOBJECT is disabled.
;
; Uses Page 0 zwFrameAddr.
;
; X  = the current PMOBJECT ID.
; A  = the Sequence Enable Flag ( 0 off, !0 on)
; Y  = the Sequence ID.

libPmgSetupAnim

	sta vsSeqEnable,x

	sty vsSeqIdent,x  ; Y = sequence index. 

	; Pick up sequence parameters, put in PMOBJECTs

	lda vsSeqAnimLo,y ; Collect the sequence address.
	sta vsSeqLo,x
	sta zwFrameAddr   ; Save to reference later
	lda vsSeqAnimHi,y
	sta vsSeqHi,x 
	sta zwFrameAddr+1

	lda vsSeqCount,y ; Copy Sequence frame count
	sta vsSeqFrameCount,x ; Frame count for sequence

	lda #0
	sta vsSeqFrameIndex,x ; Set animation index from sequence to 0.

	lda vsSeqDelay,y
	sta vsSeqFrameDelay,x
	sta vsSeqDelayCount,x

	lda vsSeqLoop,y
	sta vsSeqFrameLoop,x

	lda vsSeqBounce,y
	sta vsSeqFrameBounce,x

	ldy #0
	sty vsSeqFrameDir,x 

	lda (zwFrameAddr),y ; Get frame number 0 in this index.

	sta vsSeqFrameCurrent,x ; And set current frame to same.
	sta vsSeqFramePrev,x    ; and set previous frame to same.

	rts


;===============================================================================
;														PmgSetHPos  X A
;===============================================================================
; Set the Object Horizontal position.
; (Here animation code could optionally vector to churn HPOS to real HPOS.)
; If this object has a chain offset, then add the offset for the real position.
; If this object is chained then the library will update the chained object.  
; and if that is chained, then the same, so on. 
;
; X  = the current PMOBJECT ID.  
; A  = the logical hPos

libPmgSetHPos 

	ldy vsPmgRealHPos,x    ; Get the old (real hardware) value and save it for 
	sty vsPmgPrevHPos,x    ; animation code to make decisions about changes. 
	
	sta vsPmgHPos, x       ; Save the passed value as the logical value

	ldy vsPmgChainOffset,x ; Does this object have a chain offset?
	beq setHposSkipOffset  ; No, skip the manipulation

	clc                    ; Yes.
	adc vsPmgChainOffset,x ; Offset the position.    

setHPosSkipOffset
	sta vsPmgRealHPos, x   ; Save new (adjusted value) as the real position 

	ldy vsPmgChainIdent,x  ; Is this chained to another object?
	cpy #PMGNOOBJECT
	beq exitSetHPos        ; Ident $FF means no link.

	; The linked object needs to be updated, but the current X
	; is the current object ID, not the linked object ID. 
	; Changing X would mess up every function that follows 
	; which expects X to be the current object ID.
	; Page 0 to the rescue -- zbPmgCurrentIdent.  This is set 
	; by the main code for the current object, and should not 
	; be changed by the library.  Therefore, the code can change 
	; X to pick a new object, and then later return to the 
	; current object.

	ldx vsPmgChainIdent,x

	; The A register contains the current object's "Real" HPos.
	; This becomes the linked object's logical HPos to be offset.

	; jsr libPmgSetHPos  ; Yes, Evil Recursion. It works, but 
	; it creates an immediate limit on how many objects can be 
	; linked based on the current state of the 6502 stack.

	; A non-recursive, but still looping version does the same
	; successfully without blowing up due to unknown and 
	; possibly variable hardware conditions.

	jmp libPmgSetHPos

exitSetHPos
	ldx zbPmgCurrentIdent ; restore the possibly destroyed X value

	rts


;===============================================================================
;												PmgSetColor  A X
;===============================================================================
; Set Player/Missile color.
; This is not updating actual color registers.  
; This only updates the color in a PMGOBJECTS list of objects.
;
; X  = the current PMOBJECT ID.
; A  = Color

libPmgSetColor

	sta vsPmgColor,x

	rts


;==============================================================================
;												PmgSetFrame  A X
;==============================================================================
; Set the Player to an animation frame.
;
; This requires a redraw of the player.
;
; X = Sprite Number    (Address)
; A = Anim Index       (Address)

libPmgSetFrame

	sta vsPmgCurrentFrame,x

	jsr redraw

	rts


;==============================================================================
;											PmgEnableObject  X
;==============================================================================
; Turn an object on.  The assumption is that it was already initialized
; but only temporarily disabled to stop display for a reason.
;
; This allows animation processing to consider this object again.
;
; X  = the current PMOBJECT ID.

libPmgEnableObject

	lda #1
	sta vsPmgEnable,x

	rts


;==============================================================================
;											PmgDisableObject  X
;==============================================================================
; The fastest way to "remove" an object is to disable it.  (PmgEnable=0 )
; This action will also set the real HPOS to 0 causing any display code 
; to move the object off screen where it is not visible.  Everything else, 
; such as clearing the image bitmap, is an optional extra step.
;
; X  = the current PMOBJECT ID.

libPmgDisableObject

	lda #0
	sta vsPmgEnable,x

	jsr libPmgMoveObjectZero

	rts


;==============================================================================
;											PmgMoveObjectZero  A X
;==============================================================================
; Reset HPOS of a PMOBJECTS object to zero.
;
; Reset horizontal positions to 0, so it is not visible 
; on screen no matter the size or bitmap contents.
;
; X  = the current PMOBJECT ID.

libPmgMoveObjectZero

	lda #$00     ; 0 position

	sta vsPmgHPos,x
	sta vsPmgRealHPos,x

	rts


;==============================================================================
;											PmgMoveAllObjectsZero  A  X
;==============================================================================
; Reset HPOS of all PMOBJECTS objects to zero.
;
; Reset all Players and Missiles horizontal positions to 0, so
; that none are visible no matter the size or bitmap contents.
;
; There could be 254 objects.  So, comparison for bpl and beq 
; won't work here.  Must be explicit comparison to limit.

libPmgMoveAllObjectsZero

	lda #$00     ; 0 position
	tax          ; count the PMOBJECTS 

bLoopZeroPMObjPosition
	sta vsPmgHPos,x
	sta vsPmgRealHPos,x
	inx
	cpx #PMGOBJECTSMAX
	bne bLoopZeroPMObjPosition

	rts


;==============================================================================
;												PmgInit  A  X  Y
;==============================================================================

libPmgInit

	; get all Players/Missiles off screen.
	jsr libPmgMoveAllZero

	; clear all bitmap images
	jsr libPmgClearBitmaps

	; Tell ANTIC where P/M memory occurs for DMA to GTIA
	lda #>vsPmgRam
	sta PMBASE

	; Enable GTIA to accept DMA to the GRAFxx registers.
	lda #ENABLE_PLAYERS|ENABLE_MISSILES
	sta GRACTL

	rts


;==============================================================================
;											PmgMoveAllZero  A  X
;==============================================================================
; Simple hardware reset of all Player/Missile registers.
; Typically used only at program startup to zero everything
; and prevent any screen glitchiness.
;
; Reset all Players and Missiles horizontal positions to 0, so
; that none are visible no matter the size or bitmap contents.
; Also reset sizes.

libPmgMoveAllZero

	lda #$00     ; 0 position
	ldx #$03     ; four objects, 3 to 0

bLoopZeroPMPosition
	sta HPOSP0,x ; Player positions 3, 2, 1, 0
	sta SIZEP0,x ; Player width 3, 2, 1, 0
	sta HPOSM0,x ; Missiles 3, 2, 1, 0 just to be sure.
	dex
	bpl bLoopZeroPMPosition

	sta SIZEM    ; and Missile size 3, 2, 1, 0

	rts


;==============================================================================
;											PmgClearBitmaps  A  X
;==============================================================================
; Zero the bitmaps for all players and missiles

libPmgClearBitmaps

	lda #$00
	tax      ; count 0 to 255.

bLoopClearBitmaps
	sta MISSILEADR,x ; Missiles
	sta PLAYERADR0,x ; Player 0
	sta PLAYERADR0,x ; Player 1
	sta PLAYERADR0,x ; Player 2
	sta PLAYERADR0,x ; Player 3
	inx
	.if PMG_RES=PM_1LINE_RESOLUTION
	bne bLoopClearBitmaps ; Count 1 to 255, then 0 breaks out of loop
	.else ; Use for double line resolution P/M graphics
	bpl bLoopClearBitmaps ; Count 1 to 127, then 128 breaks out of loop
	.endif
	rts




