; ==========================================================================
; Data declarations and subroutine library code
; performing Player/missile operations.

; ==========================================================================
; Player/Missile memory is declared in the Memory file.

; Establish a few other immediate values relative to PMBASE

; For Single Line Resolution:

MISSILEADR = vsPmgRam+$300
PLAYERADR0 = vsPmgRam+$400
PLAYERADR1 = vsPmgRam+$500
PLAYERADR2 = vsPmgRam+$600
PLAYERADR3 = vsPmgRam+$700


; For Double Line Resolution:

; MISSILEADR = vsPmgRam+$180
; PLAYERADR0 = vsPmgRam+$200
; PLAYERADR1 = vsPmgRam+$280
; PLAYERADR2 = vsPmgRam+$300
; PLAYERADR3 = vsPmgRam+$380


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
; So, the architecture here is the "animation object" for display where
; this libary uses the Animation data to mange image display and then
; applies this to the Player/Missile object memory.
; are handled by another layer in tune with the scan line display activity.
;
; Animation ID numbers yield...
; lists of sequence numbers and control info which yield...
; list of frame numbers which yield...
; addresses to bitmaps.
; Or
; Player Object -> Animation number, sequence index, current sequence step
; sequence step -> frame number
; frame number -> bitmap address

; Random stream of consciuousness concluded.


;===============================================================================
; Variables

; Managing objects. . .
; This is the working part of an animated object on the screen.
; There is a part attached to the hardware, and a part that
; references the Animation sequences.

vsPmgEnable    .ds PMGOBJECTS, 0   ; Object is on/1 or off/0.  If off, skip processing.
vsPmgIdent     .ds PMGOBJECTS, $FF ; Missile 0 to 3. Player 4 to 7.  FF is unused

; Direct hardware relationships...

vsPmgColor     .ds PMGOBJECTS, 0   ; Color of each object.
vsPmgSize      .ds PMGOBJECTS, 0   ; HSize of object.
vsPmgVDelay    .ds PMGOBJECTS, 0   ; VDelay (for double line resolution.)

vsPmgCollideToField  .ds PMGOBJECTS, 0 ; Display code's collected M-PF or P-PF collision value.
vsPmgCollideToPlayer .ds PMGOBJECTS, 0 ; Display code's collected M-PL or P-PL collision value.

vsPmgAddrLo    .ds PMGOBJECTS, 0   ; Low Byte of objects' PMADR base
vsPmgAddrHi    .ds PMGOBJECTS, 0   ; High Byte of objects' PMADR base

vsPmgHPos      .ds PMGOBJECTS, 0   ; X position of each object (logical)
vsPmgRealHPos  .ds PMGOBJECTS, 0   ; Real X position on screen (if controls adjusts PmgHPos)

; Still "hardware", but not registers. Just memory offsets.

vsPmgVPos      .ds PMGOBJECTS, 0   ; Y coordinate of each object (logical)
vsPmgRealVPos  .ds PMGOBJECTS, 0   ; Real Y position on screen (if controls adjusts PmgVPos)
vsPmgPrevVPos  .ds PMGOBJECTS, 0   ; Previous Y position before move  (if controls adjusts PmgVPos)

; Animation sequence playing . . .

vsSeqIdent  .ds PMGOBJECTS, 0  ; Animation ID in use
vsSeqEnable .ds PMGOBJECTS, 0  ; Animation is playing/1 or stopped/0

vsSeqLo     .ds PMGOBJECTS, 0  ; low byte of animation sequence structure in use
vsSeqHi     .ds PMGOBJECTS, 0  ; high byte of animation sequence structure in use

vsSeqCount .ds PMGOBJECTS, 0   ; Number of frames in the animation sequence.
vsSeqFrame .ds PMGOBJECTS, 0   ; current index into frame list for this sequence.
vsSeqPrevFrame .ds PMGOBJECTS, 0   ; previous index used in this sequence. (No change means no redraw)

vsSeqDelay      .ds PMGOBJECTS, 0  ; Number of TV frames to wait for each animation frame
vsSeqDelayCount .ds PMGOBJECTS, 0  ; Frame countdown when AnimDelay is not zero

vsSeqLoop       .ds PMGOBJECTS, 0  ; Does animation sequence repeat? 0/no, 1/yes
vsSeqBounce     .ds PMGOBJECTS, 0  ; Does repeat go ABCDABCD or ABCDCBABCD (0/linear, 1/bounce)
vsSeqDir        .ds PMGOBJECTS, 0  ; Current direction of animation progression.

; Managing Animation Frame Bitmap Images. . .

; This organizes the data for the animation sequences.
; This is all reference information.  It is not modified
; at run-time by any code.

; Table of starting address for each image.
; Currently, designed for 256 addresses or 256 animation frame images.
; Given an entry from a sequence list (aka frame ID):

vsFrameAddrLo ; Low Byte of each animation image.
	.byte <vsImageBlank
	.byte <vsImagePlayer
	.byte <vsImageEnemy1
	.byte <vsImageEnemy2
	.rept 5,#
		.byte <[21*:1+vsImageExplosion]
	.endr

vsFrameAddrHi ; High Byte of each animation image
	.byte >vsImageBlank
	.byte >vsImagePlayer
	.byte >vsImageEnemy1
	.byte >vsImageEnemy2
	.rept 5,#
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

vsSeqLo ; Low byte of address of each animation frame sequence.
	.byte <vsAnimSeq0 ; Blankitty-blank
	.byte <vsAnimSeq1 ; Player
	.byte <vsAnimSeq2 ; Enemy 1
	.byte <vsAnimSeq3 ; Enemy 2
	.byte <vsAnimSeq4 ; Explosion

vsSeqHi ; Low byte of address of each animation frame sequence.
	.byte >vsAnimSeq0 ; Blankitty-blank
	.byte >vsAnimSeq1 ; Player
	.byte >vsAnimSeq2 ; Enemy 1
	.byte >vsAnimSeq3 ; Enemy 2
	.byte >vsAnimSeq4 ; Explosion

vsSeqCount .byte 1,1,1,1,6 ; Number of frames in the sequence.

vsSeqStop  .byte 0,0,0,0,5 ; Sequence frame number to use for display when stopped.
							  ; Note this is not the Anim Frame ID.  It is Sequence index.

vsSeqDelay    .byte 0,0,0,0,1 ; Number of TV frames to pause before updating sequence.

vsSeqLoop     .byte 0,0,0,0,0 ; Does sequence repeat? 0/no, 1/yes

vsSeqBounce   .byte 0,0,0,0,0 ; Does repeat go ABCDABCD or ABCDCBABCD (0/linear, 1/bounce)


;===============================================================================
;														libPmgSetColor  A X Y
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

	lda #$00 ; Clear for later activities
	ldx zbPmgIdent
	; If the Player/Missile object is negative then
	; nothing else can be set for hardware.
	bpl bDoPmgInitObject ; Positive.  build object.
	; Negative.  Unset some values.
	sta zbPmgEnable
	sta zbSeqEnable
	beq bDoPmgInitCopyToObject

bDoPmgInitObject
	sta zbPmgCollideToField
	sta zbPmgCollideToPlayer

	lda #$01
	sta zbPmgEnable

	lda vsPmgRamAddrLo,x ; Set object's Player memory base address
	sta zwPmgAddr
	lda vsPmgRamAddrHi,x
	sta zwPmgAddr+1

	lda zbPmgHPos      ; init horizontal position
	sta zbPmgRealHpos

	lda zbPmgVPos     ; init vertical position
	sta zbPmgRealVpos
	sta zbPevHPos

	; The animation data associations.

	ldx zbSeqIdent ; Get the animation number (The Sequence)

	lda vsSeqLo,x       ; Collect the sequence address.
	sta zwSeqAddr
	lda vsSeqHi,x
	sta zwSeqAddr+1

	lda vsSeqCount,x ; Copy Sequence frame count
	sta zbSeqCount

	; If Enable is 1 then configure all for first frame
	lda zbSeqEnable
	beq bLPIODoDisabled ; Enable is 0.  Do something else.

	lda vsSecCount,x ; Frame count for sequence
	sta zbSeqCount

	lda #0
	sta zbSeqFrameIndex ; Set animation index in sequence to 0.

	tay ; Actual frame numbers
	lda (zwSeqAddr),y
	sta zbSeqFrameCurrent
	sta zbSeqFramePrev

	lda vsSeqDelay,x
	sta zbSeqDelay
	sta zbSeqDelayCount

	lda vsSeqLoop,x
	sta zbSeqLoop

	lda vsSeqBounce,x
	sta zbSeqBounce

	lda vsSeqDir,x
	sta zbSeqDir

bDoPmgInitCopyToObject
	ldx zbPmgCurrentIdent

	lda zbPmgEnable
	sta vsPmgEnable,x

	lda zbPmgIdent
	sta vsPmgIdent,x

	lda zbPmgIdent
	sta
	rts


;===============================================================================
;														libPmgSetColor  A X Y
;===============================================================================

; Copy Sequence reference values to page 0.
; X is sequence id.

libSeqRefToZero
; Get the animation number (The Sequence)

	ldx zbSeqIdent

	lda vsSeqLo,x       ; Collect the sequence address.
	sta zwSeqAddr
	lda vsSeqHi,x
	sta zwSeqAddr+1

	lda vsSeqCount,x ; Copy Sequence frame count
	sta zbSeqCount

	; If Enable is 1 then configure all for first frame
	lda zbSeqEnable
	beq bLPIODoDisabled ; Enable is 0.  Do something else.

	lda vsSecCount,x ; Frame count for sequence
	sta zbSeqCount

	lda #0
	sta zbSeqFrameIndex ; Set animation index in sequence to 0.

	tay ; Actual frame numbers
	lda (zwSeqAddr),y
	sta zbSeqFrameCurrent
	sta zbSeqFramePrev

	lda vsSeqDelay,x
	sta zbSeqDelay
	sta zbSeqDelayCount

	lda vsSeqLoop,x
	sta zbSeqLoop

	lda vsSeqBounce,x
	sta zbSeqBounce

	lda vsSeqDir,x
	sta zbSeqDir

;===============================================================================
;														libPmgSetColor  A Y
;===============================================================================
; Set Player/Missile color.
; If Player Number is greater then 3, then update the "fifth" player COLOR3.
;
; Y  = object Number
; A  = Color

libPmgSetColor
	sta zbPmgColor,Y

	rts



;==============================================================================
;														libPmgSetFrame  A Y
;==============================================================================
; Set the Player to an animation frame.
;
; This requires a redraw of the player.
;
; Y = Sprite Number    (Address)
; A = Anim Index       (Address)
libPmgSetFrame

		sta vsPmgCurrentFrame,y

		jsr redraw
	rts

;==============================================================================
;							PmgInit  A  X  Y
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
	lda #ENABLE_PLAYERS | ENABLE_MISSILES
	sta GRACTL

    rts


;==============================================================================
;										PmgMoveAllZero  A  X
;==============================================================================
; Reset all Players and Missiles horizontal positions to 0, so
; that none are visible no matter the size or bitmap contents.
;
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
;										PmgClearBitmaps                A  X
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
	bne bLoopClearBitmaps ; Use for single line resolution P/M graphics

    ; bpl bLoopClearBitmaps ; Use for double line resolution P/M graphics

	rts




