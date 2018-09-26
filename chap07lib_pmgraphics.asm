; ==========================================================================
; Data declarations and subroutine library code
; performing Player/missile operations.
;
; REQUIRED DEFINITIONS (per command line or defined before including macros):
;
; PMG_RES
; Player/Missile resolution for pmgraphics macros/library.
; Recommended to use ANTIC.asm's PM_1LINE_RESOLUTION and
; PM_2LINE_RESOLUTION labels for assignment in the code.
; i.e. PMG_RES=PM_2LINE_RESOLUTION
; If the command line build is necessary this is:
; PMG_RES=0 which is PM_2LINE_RESOLUTION, or 2 line resolution.
;    (128 vertical pixels, or 2 scan lines per byte)
;    (1K memory map starting at a 1K boundary.)
; PMG_RES=8 which is PM_1LINE_RESOLUTION, or 1 line resolution
;    (256 vertical pixels, or 1 scan line per byte)
;    (2K memory map starting at a 2K boundary.)
;
; PMG_MAPS
; Number of Player/Missile memory maps supported.
; 1 is default.  4 is maximum.
;
; 
; vsPmgRam  (vsPmgRam0, vsPmgRam1, vsPmgRam2, vsPmgRam3)
; This must be declared in Memory at a valid location suitable for 
; ANTIC's PMBASE register relative to the vertical dimensions 
; defined by PMG_RES above.
; 
; The macros file will provide a few other calculated values based on 
; the definitions above.


;===============================================================================
; This is a general purpose library for Player/Missile graphics which is 
; flexible along certain design lines.  Fair Warning: "General Purpose" plus
; "Flexible" means it does not deliver the most optimal performance for
; anything it does.  
;
; While it is flexible for some situations, no library can account for all 
; the possible uses.  This library could be considered overkill for a program 
; using Player/Missiles as simple overlay objects to add color to the 
; playfield.  Alternatively, it would be inadequate for a program running a 
; horizontal kernel to duplicate player/missile objects on the same scan line.
; This is an attempt at a happy medium.
;
; The Atari has four, 8-bit wide "player" objects, and four, 2-bit wide
; "missile" objects per scan line.  Naturally, this poses some limits and
; requires some cleverness to make it appear there are more objects.  The 
; library supports methods of Player/missile re-use to make it appear there
; are more animated objects available than the inherent hardware limit. 
;
; The P/M Graphics library is a level of abstraction above the direct hardware 
; and does not care much about the number of Players or missiles.  It will 
; animate images in memory for a number of objects unrelated to the actual 
; limit of Players and Missiles on a scan line.  It is the responsibility of 
; the application code to track, control, and limit the number of objects 
; actually appearing on the same scan line.
;
; On the good side, since the Player/Missile bitmap is inherently the height
; of the screen, re-use of objects at different vertical positions is 
; essentially built-in.  Making another image appear lower on the screen is 
; only a matter of writing the bitmap data into the proper place in memory.  
; Vertical placement of objects and animation of objects are the exact same 
; activity -- again, both are simply a matter of writing the desired image 
; bitmap into the proper place in memory.
;
; Making the Player appear at a different horizontal location is where things
; must get clever.  Horizontal placement is limited by the number of 
; horizontal position registers which is limited by the number of Players and
; Missiles in GTIA.  The library operates at a level above the hardware where 
; it simply manages horizontal coordinates for objects, but does not change 
; the actual hardware's horizontal position registers.
;
; Since horizontal placement is a scanline by scanline activity it is the job
; of the programmer to set horizontal position registers in the main program 
; code, vertical blank interrupt code, or display list interrupt code (or 
; combinations thereof) to copy the horizontal position values to the hardware
; registers at the right time.
;
; Player/Missile color and horizontal size are also related to hardware write
; registers, so these are also the responsibility of the programmers' 
; application code.
;
; In short, for N objects this library maintains arrays of N "shadow registers"
; along with the arrays of N entries describing animation pointers, animation
; state, X and Y values, etc.  Its relationship to the hardware is only that it
; copies bitmap images per the animation states into memory which happens to be
; where ANTIC reads them.  (It could write somewhere else completely different
; and the library would still function correctly to manage the object data.)
;
; Thus, the architecture produced here is the "animation object" for display.  
; This library uses the Animation data to mange image display and then applies 
; this to the Player/Missile object memory.
;
; Animation ID numbers yield...
; lists of sequence numbers and control info which yield...
; list of frame numbers which yield...
; addresses to bitmaps.
; Or
; Player Object -> Animation number, sequence index, and current sequence step
; sequence step -> frame number
; frame number -> bitmap address
;
; PMG_MAPS value: 
; On the subject of hardware limits the library supports allocating additional
; Player/Missile  memory maps allowing for page flipping the PMBASE per each 
; video frame.  This allows a different set of Player/Missile objects or images
; per each video frame.  This can provide extra objects per scan line or allow 
; overlaying objects for additional color.  Multiple pages expand the limit of 
; Player/Missile objects per scan line to 16, 24, or 32 depending on how much 
; flickering a programmer wishes to inflict on the users. 
; 
; Is is the responsibility of the programmer's application to manage the actual
; page flipping of the PMBASE register value for each frame.
;
; Two pages allows 8 Players/8 missile per line with 30fps flickering.  Most 
; people would not be immediately aware of the flickering at this speed.
; Three sets of images is 20fps and an obvious amount of flickering for 12 
; Players/12 Missiles per line.
; Four sets of images approaches evil intent with quite an annoying amount of 
; 15fps flickering for 16 players/16 missiles per line.
;
; Color choice is important during page flipping.  The brightness of 
; overlapping objects or an object and the background should be within similar
; ranges.  Luminance value differences greater than 4 between overlapping 
; objects makes flickering more apparent.  Also, the colors of overlapping 
; objects average together.  So, a blue background and a red object will be 
; the purple-ish average of the two.

; Random stream of consciousness concluded.


; ==========================================================================
; Player/Missile memory is declared in the Memory file.

; Establish a few other immediate values relative to PMBASE.  These could 
; have been put directly into the .byte assignments below.  They're listed 
; here just to illustrate each memory map. 

; For Single Line Resolution:

.if PMG_RES=PM_1LINE_RESOLUTION
	.if PMG_MAPS>0
		MISSILEADR0 = vsPmgRam0+$300
		PLAYERADR0  = vsPmgRam0+$400
		PLAYERADR1  = vsPmgRam0+$500
		PLAYERADR2  = vsPmgRam0+$600
		PLAYERADR3  = vsPmgRam0+$700
	.endif
	.if PMG_MAPS>1
		MISSILEADR1 = vsPmgRam1+$300
		PLAYERADR4  = vsPmgRam1+$400
		PLAYERADR5  = vsPmgRam1+$500
		PLAYERADR6  = vsPmgRam1+$600
		PLAYERADR7  = vsPmgRam1+$700
	.endif
	.if PMG_MAPS>2
		MISSILEADR2 = vsPmgRam2+$300
		PLAYERADR8  = vsPmgRam2+$400
		PLAYERADR9  = vsPmgRam2+$500
		PLAYERADR10 = vsPmgRam2+$600
		PLAYERADR11 = vsPmgRam2+$700
	.endif
	.if PMG_MAPS>3
		MISSILEADR3 = vsPmgRam3+$300
		PLAYERADR12 = vsPmgRam3+$400
		PLAYERADR13 = vsPmgRam3+$500
		PLAYERADR14 = vsPmgRam3+$600
		PLAYERADR15 = vsPmgRam3+$700
	.endif
.endif

; For Double Line Resolution:

.if PMG_RES=PM_2LINE_RESOLUTION
	.if PMG_MAPS>0
		MISSILEADR0 = vsPmgRam0+$180
		PLAYERADR0  = vsPmgRam0+$200
		PLAYERADR1  = vsPmgRam0+$280
		PLAYERADR2  = vsPmgRam0+$300
		PLAYERADR3  = vsPmgRam0+$380
	.endif
	.if PMG_MAPS>1
		MISSILEADR1 = vsPmgRam1+$180
		PLAYERADR4  = vsPmgRam1+$200
		PLAYERADR5  = vsPmgRam1+$280
		PLAYERADR6  = vsPmgRam1+$300
		PLAYERADR7  = vsPmgRam1+$380
	.endif
	.if PMG_MAPS>2
		MISSILEADR2 = vsPmgRam2+$180
		PLAYERADR8  = vsPmgRam2+$200
		PLAYERADR9  = vsPmgRam2+$280
		PLAYERADR10 = vsPmgRam2+$300
		PLAYERADR11 = vsPmgRam2+$380
	.endif
	.if PMG_MAPS>3
		MISSILEADR3 = vsPmgRam3+$180
		PLAYERADR12 = vsPmgRam3+$200
		PLAYERADR13 = vsPmgRam3+$280
		PLAYERADR14 = vsPmgRam3+$300
		PLAYERADR15 = vsPmgRam3+$380
	.endif
.endif

; Hardware references.

; The index here is the P/M Ident. 
; ID entries increase with the number of memory maps provided.
; PMG_MAPS = 1: PmgIdent = Player 0  to 3,  Missile 4  to 7.
; PMG_MAPS = 2: PmgIdent = Player 8  to 11, Missile 12 to 15.
; PMG_MAPS = 3: PmgIdent = Player 16 to 19, Missile 20 to 23.
; PMG_MAPS = 4: PmgIdent = Player 24 to 27, Missile 28 to 31.
; For each P/M Ident declare the memory Map starting address...

vsPmgRamAddrLo
.if PMG_MAPS>0
	.byte <PLAYERADR0, <PLAYERADR1, <PLAYERADR2, <PLAYERADR3
	.byte <MISSILEADR0, <MISSILEADR0, <MISSILEADR0, <MISSILEADR0
	.if PMG_MAPS>1
		.byte <PLAYERADR4, <PLAYERADR5, <PLAYERADR6, <PLAYERADR7
		.byte <MISSILEADR1, <MISSILEADR1, <MISSILEADR1, <MISSILEADR1
		.if PMG_MAPS>2
			.byte <PLAYERADR8, <PLAYERADR9, <PLAYERADR10, <PLAYERADR11
			.byte <MISSILEADR2, <MISSILEADR2, <MISSILEADR2, <MISSILEADR2
			.if PMG_MAPS>3
				.byte <PLAYERADR12, <PLAYERADR13, <PLAYERADR14, <PLAYERADR15
				.byte <MISSILEADR3, <MISSILEADR3, <MISSILEADR3, <MISSILEADR3
			.endif
		.endif
	.endif
.endif

vsPmgRamAddrHi
.if PMG_MAPS>0
	.byte >PLAYERADR0, >PLAYERADR1, >PLAYERADR2, >PLAYERADR3
	.byte >MISSILEADR0, >MISSILEADR0, >MISSILEADR0, >MISSILEADR0
	.if PMG_MAPS>1
		.byte >PLAYERADR4, >PLAYERADR5, >PLAYERADR6, >PLAYERADR7
		.byte >MISSILEADR1, >MISSILEADR1, >MISSILEADR1, >MISSILEADR1
		.if PMG_MAPS>2
			.byte >PLAYERADR8, >PLAYERADR9, >PLAYERADR10 >PLAYERADR11
			.byte >MISSILEADR2, >MISSILEADR2, >MISSILEADR2, >MISSILEADR2
			.if PMG_MAPS>3
				.byte >PLAYERADR12, >PLAYERADR13, >PLAYERADR14, >PLAYERADR15
				.byte >MISSILEADR3, >MISSILEADR3, >MISSILEADR3, >MISSILEADR3
			.endif
		.endif
	.endif
.endif

; For each P/M Ident declare the masking data which is necessary for missiles 
; sharing the same bitmap. Bitmap sharing for Missiles is disabled when 
; "Fifth Player" is enabled.  (GTIA.asm defined values)
; A bit of redundancy here to maintain the lookup by P/M Ident.

; For reference, when Missiles are processed individually:
; (P/M Memory AND vsPmgMaskAND_OFF) OR (Image AND vsPmgMaskAND_ON)

; Turn off selected Missile bits, keep the neighbors' bits.
vsPmgMaskAND_OFF 
.if PMG_MAPS>0
	.byte $FF,$FF,$FF,$FF
	.byte MASK_MISSILE0_BITS, MASK_MISSILE1_BITS, MASK_MISSILE2_BITS, MASK_MISSILE3_BITS
	.if PMG_MAPS>1
		.byte $FF,$FF,$FF,$FF
		.byte MASK_MISSILE0_BITS, MASK_MISSILE1_BITS, MASK_MISSILE2_BITS, MASK_MISSILE3_BITS
		.if PMG_MAPS>2
			.byte $FF,$FF,$FF,$FF
			.byte MASK_MISSILE0_BITS, MASK_MISSILE1_BITS, MASK_MISSILE2_BITS, MASK_MISSILE3_BITS
			.if PMG_MAPS>3
				.byte $FF,$FF,$FF,$FF
				.byte MASK_MISSILE0_BITS, MASK_MISSILE1_BITS, MASK_MISSILE2_BITS, MASK_MISSILE3_BITS
			.endif
		.endif
	.endif
.endif

; Turn off the neighbors' bits, keep the selected Missile bits.
vsPmgMaskAND_ON 
.if PMG_MAPS>0
	.byte $00,$00,$00,$00
	.byte MISSILE0_BITS, MISSILE1_BITS, MISSILE2_BITS, MISSILE3_BITS
	.if PMG_MAPS>1
		.byte $00,$00,$00,$00
		.byte MISSILE0_BITS, MISSILE1_BITS, MISSILE2_BITS, MISSILE3_BITS
		.if PMG_MAPS>2
			.byte $00,$00,$00,$00
			.byte MISSILE0_BITS, MISSILE1_BITS, MISSILE2_BITS, MISSILE3_BITS
			.if PMG_MAPS>3
				.byte $00,$00,$00,$00
				.byte MISSILE0_BITS, MISSILE1_BITS, MISSILE2_BITS, MISSILE3_BITS
			.endif
		.endif
	.endif
.endif



;===============================================================================
; Variables

; Managing objects. . .
; This is the working part of an animated object on the screen.
; There is a part attached to the hardware, and a part that
; references the Animation sequences.

vsPmgEnable          .ds PMGOBJECTSMAX, 0   ; Object is on/1 or off/0. If off, skip processing.
vsPmgIdent           .ds PMGOBJECTSMAX, $FF ; PmgIdent value limit expands per PMG_MAPS value. FF is unused
; PMG_MAPS = 1: PmgIdent = Player 0  to 3,  Missile 4  to 7.
; PMG_MAPS = 2: PmgIdent = Player 8  to 11, Missile 12 to 15.
; PMG_MAPS = 3: PmgIdent = Player 16 to 19, Missile 20 to 23.
; PMG_MAPS = 4: PmgIdent = Player 24 to 27, Missile 28 to 31.

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
vsPmgFifth           .ds PMGOBJECTSMAX, 0 ; Is Missile linked together for Fifth Player.

; Still "hardware", but not registers. Just memory offsets.

vsPmgVPos            .ds PMGOBJECTSMAX, 0 ; Y coordinate of each object (logical)
vsPmgRealVPos        .ds PMGOBJECTSMAX, 0 ; Real Y position on screen (if logic adjusts PmgVPos)
vsPmgPrevVPos        .ds PMGOBJECTSMAX, 0 ; Previous Real Y position before move  (if controls adjusts PmgVPos)
vsPmgPrevHeight      .ds PMGOBJECTSMAX, 0 ; Remember frame height when switching between anims.

vsPmgIsChain         .ds PMGOBJECTSMAX, 0 ; This object is chained to a prior object.
vsPmgChainIdent      .ds PMGOBJECTSMAX, 0 ; Object ID of next object linked to this.
vsPmgXOffset         .ds PMGOBJECTSMAX, 0 ; X offset of HPos (typically for a chained P/M object)
vsPmgYOffset         .ds PMGOBJECTSMAX, 0 ; Y offset of VPos (typically for a chained P/M object)
; Animation sequence playing . . .

vsPmgSeqRedraw       .ds PMGOBJECTSMAX, 0 ; On next redraw pass, update P/M image.
vsPmgSeqBlank        .ds PMGOBJECTSMAX, 0 ; Before redraw, blank bytes at vsPmgPrevHPos

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
	.ds 9,21 ; All nine frames 21 bytes tall, but each sequence could 
	         ; have its own height for frames.

; Managing Animation Sequences,

ANIM_BLANK     = 0 ; Blankitty-blank
ANIM_PLAYER    = 1 ; Player Ship
ANIM_ENEMY1    = 2 ; Enemy 1
ANIM_ENEMY2    = 3 ; Enemy 2
ANIM_EXPLOSION = 4 ; Explosion


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
;												PmgInitObject  A X Y
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
;     objID   ; pmID   ; fifth  ;  color   ; size    ; vDelay
;
; Now, Move to object...

libPmgInitObject
	; The physical hardware associations. . .

	ldx zbPmgCurrentIdent
	jsr libPmgZeroObject  ; Zero all PMOBJECTS variables.

	ldy zbPmgIdent

	; An initialized object is all 0 values, so the object 
	; is  disabled by default.

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
;												PmgInitPosition A X Y
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
;  hPos    ; vPos    ; next chain ID   ; Chained flag  ;   Xoffset  ;  Yoffset

libPmgInitPosition

	rts



;===============================================================================
;												PmgInitAnim A X Y
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
;  anim ID    ; animEnable    ;  start frame   

libPmgInitAnim

	rts



;===============================================================================
;												PmgZeroObject  A X
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
	sta vsPmgPrevHPos,x
	sta vsPmgFifth,x

	sta vsPmgVPos,x
	sta vsPmgRealVPos,x
	sta vsPmgPrevVPos,x
	sta vsPmgPrevHeight,x

	sta vsPmgIsChain,x
	; chain ident is non-zero.  set it below.
	sta vsPmgXOffset,x
	sta vsPmgYOffset,x

	sta vsPmgSeqRedraw,x
	sta vsPmgSeqBlank,x

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

	lda #PMGNOOBJECT      ; This non-value is not a 0 value.
	sta vsPmgChainIdent,x

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

	; shouldn't mask be included?
	
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

	lda zbPmgFifth
	sta vsPmgFifth,x

	lda zbPmgColor
	sta vsPmgColor,x

	lda zbPmgSize
	sta vsPmgSize,x

	lda zbPmgVDelay
	sta vsPmgVDelay,x

	
	
	
	
	
	
	
	lda zbPmgHPos
	sta vsPmgHPos,x
	clc                 ; Add X offset to make real position
	adc zbPmgXOffset
	sta vsPmgRealHPos,x
	; intentionally do not change previous HPos.  It is 0 by default.

	lda zbPmgVPos
	sta vsPmgVPos,x
	clc                 ; Add X offset to make real position
	adc zbPmgYOffset
	sta vsPmgRealVPos,x
	; intentionally do not change previous VPos.  It is 0 by default.

	lda zbPmgIsChain
	sta vsPmgIsChain,x

	lda zbPmgChainIdent
	sta vsPmgChainIdent,x

	lda zbPmgXOffset
	sta vsPmgXOffset,x

	lda zbPmgYOffset
	sta vsPmgYOffset,x

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

	inc vsPmgSeqRedraw,x  ; Force redraw at next opportunity.
	inc vsPmgSeqBlank,x   ; Clear old frame at PrevVpos for PrevHeight.
	
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

	ldy vsPmgXOffset,x     ; Does this object have an offset?
	beq setHposSkipOffset  ; No, skip the manipulation

	clc                    ; Yes.
	adc vsPmgXOffset,x     ; Offset the position.

setHPosSkipOffset
	sta vsPmgRealHPos, x   ; Save new (adjusted value) as the real position

	ldy vsPmgChainIdent,x  ; Is this chained to another object?
	cpy #PMGNOOBJECT
	beq exitSetHPos        ; Ident $FF means no link.

	; The linked object needs to be updated, but the current X
	; is the current object ID, not the linked object ID.
	; Changing X would disrupt up every function that follows
	; each expecting X to be the current object ID.
	; Page 0 to the rescue -- zbPmgCurrentIdent.  This is set
	; by the main code for the current object, and should not
	; be changed by the library.  Therefore, the code can change
	; X to pick a new object, and then later return X to the
	; current object.

	ldx vsPmgChainIdent,x  ; Move to chained object.

	; The A register contains the current object's "Real" HPos.
	; This becomes the linked object's logical HPos to be offset.

	; jsr libPmgSetHPos  ; Yes, Evil Recursion. It works, but
	; it creates an immediate limit on how many objects can be
	; linked based on the current state of the 6502 stack.

	; A non-recursive, but still looping version does the same
	; successfully without blowing up due to possibly variable
	; hardware conditions.

	jmp libPmgSetHPos

exitSetHPos
	ldx zbPmgCurrentIdent ; restore the possibly destroyed X value

	rts


;===============================================================================
;														PmgSetVPos  X A
;===============================================================================
; Set the Object Vertical position.
; (Here animation code could optionally vector to churn VPOS to real HPOS.)
; If this object has a chain offset, then update the chained object.
; and if that is chained, then the same, so on.
;
; X  = the current PMOBJECT ID.
; A  = the logical vPos

libPmgSetVPos

	ldy vsPmgRealVPos,x    ; Get the old (real hardware) value and save it for
	sty vsPmgPrevVPos,x    ; animation code to make decisions about changes.

	sta vsPmgVPos, x       ; Save the passed value as the logical value

	ldy vsPmgYOffset,x     ; Does this object have an offset?
	beq setHposSkipOffset  ; No, skip the manipulation

	clc                    ; Yes.
	adc vsPmgChainOffset,x ; Offset the position.

setVPosSkipOffset
	sta vsPmgRealVPos, x   ; Save new (adjusted value) as the real position

	cmp vsPmgPrevVPos,x    ; Did VPos change?
	beq setVPosSkipRedraw  ; No.  Do not flag it for redraw.

	inc vsPmgSeqRedraw,x   ; Yes.  VPos change means image redraw is needed.

setVPosSkipRedraw
	lda vsPmgChainIdent,x  ; Is this chained to another object?
	cmp #PMGNOOBJECT
	beq exitSetVPos        ; Ident $FF means no link.

	; The linked object needs to be updated.
	; The code can change X to pick a new object, and then later
	; return X to the current object using page 0 zbPmgCurrentIdent.

	tax                 ; Move to chained object.
	lda vsPmgRealVPos,x  

	; The A register contains the current object's "Real" VPos.
	; This becomes the linked object's logical VPos to be offset.

	jmp libPmgSetVPos

exitSetVPos
	ldx zbPmgCurrentIdent ; restore the possibly destroyed X value

	rts


;===============================================================================
; 														PmgSeqRedraw  A X Y
;===============================================================================
; Redraw the current PMOBJECT.
;
; Code that modifies the vertical position or changes the animation frame 
; number for the object will automatically increment vsPmgSeqRedraw to
; indicate the P/M image must be redrawn.
; This is also forced when setting a new animation.
;
; X = current pmobject. (also in zbPmgCurrentIdent)

libPmgSeqRedraw 
	lda vsPmgSeqRedraw,x ; Is object X flagged to redraw?
	bne bPmgRedraw       ; Yes.  Do it.

bExitNoRedraw
	rts                  ; Leave.

;===============================================================================
; PmgSeqRedraw 1) Testing.  Setup masks.

bPmgRedraw
	lda #0               ; Turn off Redraw flag
	sta vsPmgSeqRedraw,x

	ldy vsPmgIdent,x     ; Get current P/M graphics (hardware) ID
	sty zbPmgIdent       ; Save in case routine needs it again.

	cpy #PMGNOOBJECT     ; Is it assigned to a real P/M object?
	beq bExitNoRedraw    ; No.  Exit.
	mPmgCmpMaxident      ; Compare Y to hardware ID max.
	bcs bExitNoRedraw    ; It is >=  max, so then exit.
	; technically, the mPmgCmpMaxident/BCS also catches the value of 
	; #PMGNOOBJECT, so the earlier comparison was not needed. 

	; Valid P/M identity.
	; Is this a fifth player child object?
	lda vsPmgFifth,x
	cmp #FIFTH_PLAYER_CHILD
	beq bExitNoRedraw    ; Yes, do not redraw.

	; Use alternative default (player) mask for fifth player.
	cmp #FIFTH_PLAYER    ; Is it the parent object?
	bne bCopyPMGMasks    ; No.  Copy masks as-is.
	lda vsPmgMaskAND_OFF ; Yes.  Copy regular Player mask to Missile.
	sta zbPmgMaskAND_OFF
	lda vsPmgMaskAND_ON
	sta zbPmgMaskAND_ON
	beq bCheckForPMGZero  ; Because we know the player ON mask is 0.

	; Save the mask info for the object.
	; For reference, when Missiles are processed:
	; P/M Memory = (P/M Memory AND vsPmgMaskAND_OFF) OR (Image AND vsPmgMaskAND_ON)
	; if pmid = a Player then the default mask does no masking.
bCopyPMGMasks
	lda vsPmgMaskAND_OFF,y ; retrieved by PM Ident in Y
	sta zbPmgMaskAND_OFF
	lda vsPmgMaskAND_ON,y
	sta zbPmgMaskAND_ON

;===============================================================================
; PmgSeqRedraw 2) Forced Blanking the P/M image.
;
; Yes, under most circumstance forced blanking the P/M image and 
; redrawing the image are largely redundant.  But general purpose 
; library means results must be consistent and predictable.  When 
; switching between animations of different sizes it is possible 
; there may be residual bytes of the previous animation image left
; behind. The safest thing to do it remove the previous image. 
; Remember, this wastefulness does not happen all the time.

; P/M image memory map address is needed for clearing the P/M image 
; byte map, and for copying the animation image to the P/M memory,
; so this value is established now.  However, the P/M memory 
; addressing method is different between clearing the image and 
; copying the image. In both cases we need the high byte of the 
; address, but for clearing the memory the low byte is the start 
; of the page.
;
; Therefore, the High Byte is always from the table.
; For clearing the image the Low Byte is 0 and the Y register 
; will be the vertical position.

bCheckForPMGZero
	; Set the high byte even if the current image will not be cleared,
	; because it will be used for the image copying later 
	lda vsPmgRamAddrHi,y
	sta zwPmgAddr+1

	; Is frame blanking set?  
	; The library sets a forced blank which is needed when 
	; switching between Animation sequences of different sizes.
	lda vsPmgSeqBlank,x
	beq bPMGDrawImageSetup ; Nope. Do not zero the current P/M image

	lda #0        ; Low byte is 0, because Y will be Prev Vpos
	sta zwPmgAddr

	ldy vsPmgPrevVPos,x ; CHANGED Y for library routine!!  Lost hardware ID.
	lda vsPrevHeight,x  
	tax                 ; CHANGED X for library routine!  (height)  Lost the PM Object index.
	jsr libPmgZeroCurrentFrameImage

;===============================================================================
; PmgSeqRedraw 3) Draw the new P/M object's image.

bPMGDrawImageSetup
	ldx zbPmgCurrentIdent ; X may have been changed. Reload as object ID.

	ldy vsSeqFrameCurrent,x ; Y = index into frame numbers

    ; Load the Frame address 

    lda vsFrameAddrLo,y      ; Copy frame address to zero page for later.
    sta zwFrameAddr
    lda vsFrameAddrHi,y
    sta zwFrameAddr+1

	lda vsFrameHeight,y      ; Copy current frame height to zero page for later.
	sta zbFrameHeight
	sta vsPrevHeight,x       ; also update last height as the current height.

;===============================================================================
; PmgSeqRedraw 4) Redraw image and clear residual lines.
;                (or clear residual lines and redraw image.)   
;
; Load zwPmgAddr with address of image in P/M memory.
; This means the real vertical position plus the base 
; address of one of the PM graphics object memory maps.
; Note that vertical position plus the low byte of the 
; address to the memory map will not exceed the range
; of the one-byte value range.  (In other words, the 
; math never carries to the high byte).

; The memory management of the Player/Missile is different
; depending on the direction of movement.   When the image
; moves up the screen, then routine draws the image first
; and erases the exposed remains of the previous frame at 
; the bottom. When the image moves down the reverse occurs:
; the routine must erase the trailing residue first at the 
; top, then copy the image data into memory at the new position.

; Therefore the "start" of the P/M address is based on the 
; previous vertical position when the new image location 
; moves down the screen, and on the new vertical position 
; when the new image moves up the screen.

; The high byte is always from the table, and was loaded earlier.
; For copying the image the Low Byte will be vertical position and
; the Y register will be 0, counting forward. 

	ldy zbPmgIdent ; temporarily, Y = P/M hardware ID to get memory map

; Which direction?
	lda vsPmgPrevVPos,x
	cmp vsPmgRealVPos,x
	beq bRedrawCurrentPosition ; prev = new
	bcc bRedrawMoveDown        ; prev < new
;	bcs bRedrawMoveUp          ; prev > new (the same as moving to current.)

bRedrawCurrentPosition ; The same as moving up without the clearing action.
bRedrawMoveUp
	lda vsPmgRealVPos,x

; For Single Line Resolution
; .if PMG_RES=PM_1LINE_RESOLUTION then low byte = real vpos
;   nop ; figured out there was nothing to do
; .endif

; For Double Line Resolution:
.if PMG_RES=PM_2LINE_RESOLUTION ; then low byte = real vpos + pmadr low byte
	clc
	adc vsPmgRamAddrLo,y
.endif

	sta zwPmgAddr  ; save low byte of starting P/M memory address

	clc
	lda vsPmgPrevVPos,x ; Previous vpos - Real vpos = lines at bottom to zero.
	sbc vsPmgRealVPos,x
	sta zbPmgLinesToZero

	ldx zbFrameHeight        ; determined earlier
	jsr libPmgCopyFrameToPM

	ldx zbPmgLinesToZero
	beq bSkipZeroLines ; This could be true if redrawn at same postion.
	jsr libPmgZeroLinesToPMBottom
bSkipZeroLines

	rts


bRedrawMoveDown 
	lda vsPmgPrevVPos,x

; For Single Line Resolution
; if PMG_RES=PM_1LINE_RESOLUTION then low byte = prev vpos

; For Double Line Resolution:
.if PMG_RES=PM_2LINE_RESOLUTION ; then low byte = prev vpos + pmadr low byte
	clc
	adc vsPmgRamAddrLo,y
.endif

	sta zwPmgAddr

	clc 
	lda vsPmgRealVPos,x ; Real vpos - Previous vpos = lines at top to zero.
	sbc vsPmgPrevVPos,x
	sta zbPmgLinesToZero ; not really needed.  using in X immediately.

	tax ; save number of zero lines
	jsr libPmgZeroLinesToPMTop

	ldx zwFrameHeight
	jsr libPmgCopyFrameToPM

	rts


;===============================================================================
; (internal)                                   PmgZeroCurrentFrameImage  A X Y
;===============================================================================
; Clear the last frame image in P/M memory.
;
; Typically called to clear the image of the old frame when changing to an 
; animation that has a different frame size.
;
; zbPmgMaskAND_OFF = Mask to set Missile bits off; ($FF for players)
; zbPmgMaskAND_ON  = Mask to set Missile Bits on.  ($00 for Players)
;
; zwPmgAddr   = Address in P/M memory to begin.  (PMADR+VPos)
;
; X = frame height

libPmgZeroCurrentFrameImage
	lda zbPmgMaskAND_ON ; If this is zero, then this is for a player.
	beq bDoZeroPlayerImage

	; Zero Missile Image 

	; Now, at this point the target PM/M address is set, 
	; Y contains the starting location offset in memory (vpos),
	; X contains the height of the object (number of bytes to zero) 

bWriteZeroMissileImage   ; used when Missiles are separate objects
	lda (zwPmgAddr),Y    ; Get Missile byte
	and zbPmgMaskAND_OFF ; Turn off the missile's bits.
	sta (zwPmgAddr),Y    ; Put the byte back
	iny
	beq bPMGDrawImageSetup ; Safety.  If Y wraps to 0, then we're leaving the P/M bitmap.
	dex
	bne bWriteZeroMissileImage ; until height is reached.
	rts

bDoZeroPlayerImage

	; Now, at this point the target PM/M address is set, 
	; Y contains the starting location offset in memory (vpos),
	; X contains the height of the object (number of bytes to zero) 

	; lda #0 ; We know that this is already 0 due to  lda zbPmgMaskAND_ON

bWriteZeroPlayerImage   ; used for Players, and Fifth Player for  Missiles
	sta (zwPmgAddr),Y   ; Set Player byte
	iny
	beq bPMGDrawImageSetup ; Safety.  If Y wraps to 0, then we're leaving the P/M bitmap.
	dex
	bne bWriteZeroPlayerImage ; until height is reached.
	rts


;===============================================================================
; (internal)                                   PmgCopyFrameToPM  A X Y
;===============================================================================
; Copy the current Frame data to P/M memory.
;
; zbPmgMaskAND_OFF = Mask to set Missile bits off; ($FF for players)
; zbPmgMaskAND_ON  = Mask to set Missile Bits on.  ($00 for Players)
;
; zwFrameAddr = Address of frame image
; zwPmgAddr   = Address in P/M memory to begin.  (PMADR+VPos)
;
; X = frame height

libPmgCopyFrameToPM
	ldy #0

	lda zbPmgMaskAND_ON
	beq bLoopCopyFramePlayer    ; Because we know the player ON mask is 0.

; Missiles share P/M image memory.  Therefore animation frames
; and P/M image memory must be masked to combine only the bits
; that apply to the missile.

bLoopCopyFrameMissile
	lda (zwFrameAddr),y  ; Get animation frame
	and zbPmgMaskAND_ON  ; Keep only the frame image bits for missile.
	sta zbTemp           ; Save to merge with Missile memory.
	lda (zwPmgAddr),Y    ; Get Missile byte
	and zbPmgMaskAND_OFF ; Turn off the missile's bits.
	ora zbTemp           ; Combine frame bits with Missile byte
	sta (zwPmgAddr),Y    ; Save to Missile memory.
	iny
	dex ; frame height
	bne bLoopCopyFramePlayer
	rts

; Players, just a strip-o-bytes.
; Same logic for Fifth player, missiles imitating a player.
bLoopCopyFramePlayer
	lda (zwFrameAddr),y
	sta (zwPmgAddr),y
	iny
	dex ; frame height
	bne bLoopCopyFramePlayer
	rts


;===============================================================================
; (internal)                                   PmgZeroLinesToPMTop  A X Y
;===============================================================================
; Clear/write zero bytes to the lines at the 
; top of the P/M image that are unneeded when
; the P/M image moves down.
;
; The reason Y is NOT incremented is that PmgAddr points
; to data BEFORE the new/current image in P/M memory.
; That data needs to be cleared and the address incremented
; until it reaches the actual location of the P/M image.
; Then the next action would be to copy the image to 
; P/M Memory (libPmgCopyFrameToPM) which expects to use
; Y as the index looping through memory. 
;
; zbPmgMaskAND_OFF = Mask to set Missile bits off; ($FF for players)
; zbPmgMaskAND_ON  = Mask to set Missile Bits on.  ($00 for Players)
;
; zwPmgAddr   = Address in P/M memory to begin.  (PMADR+VPos)
;
; X = height
; Y = 0

libPmgZeroLinesToPMTop
	lda zbPmgMaskAND_ON
	beq bZeroPlayerTop    ; Because we know the player ON mask is 0.

	; Missile zero, twiddle bits...

bLoopZeroLinesMissileTop
	lda (zwPmgAddr),Y    ; Get Missile byte
	and zbPmgMaskAND_OFF ; Turn off the missile's bits.
	sta (zwPmgAddr),Y    ; Put the byte back
	inc zwPmgAddr
	beq bExitPmgZeroLinesToPMTop; if this wraps to 0 then we're done.
	dex ; height
	bne bLoopZeroLinesMissileTop
	rts

	; Player.  Just zero the bytes.

bZeroPlayerTop
	lda #0
bLoopZeroLinesPlayerTop
	sta (zwPmgAddr),y
	inc zwPmgAddr
	beq bExitPmgZeroLinesToPMTop; if this wraps to 0 then we're done.
	dex ; height
	bne bLoopZeroLinesPlayerTop

bExitPmgZeroLinesToPMTop
	rts


;===============================================================================
; (internal)                                   PmgZeroLinesToPMBottom  A X Y
;===============================================================================
; Clear/write zero bytes to the lines at the 
; bottom of the P/M image that are unneeded when
; the P/M image moves up.
;
; Y is incremented here, because the image was drawn
; into P/M memory by libPmgCopyFrameToPM and Y is 
; now the correct index for the next byte following
; the image. 
;
; zwPmgAddr   = Address in P/M memory to begin.  (PMADR+VPos)
;
; X = height
; Y = index in P/M image.


libPmgZeroLinesToPMBottom
	lda zbPmgMaskAND_ON
	beq bZeroPlayerBottom    ; Because we know the player ON mask is 0.

	; Missile zero, twiddle bits...

bLoopZeroLinesMissileBottom
	lda (zwPmgAddr),Y    ; Get Missile byte
	and zbPmgMaskAND_OFF ; Turn off the missile's bits.
	sta (zwPmgAddr),Y    ; Put the byte back
	inc zwPmgAddr
	beq bExitPmgZeroLinesToPMBottom; if this wraps to 0 then we're done.
	dex ; height
	bne bLoopZeroLinesMissileBottom
	rts

	; Player.  Just zero the bytes.

	bZeroPlayerBottom
	lda #0
bLoopZeroLinesPlayerBottom
	sta (zwPmgAddr),y
	inc zwPmgAddr
	beq bExitPmgZeroLinesToPMBottom; if this wraps to 0 then we're done.
	dex ; height
	bne bLoopZeroLinesPlayerBottom

bExitPmgZeroLinesToPMBottom
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

	; if this object is chained, should it also change the linked object(s)?
	; Maybe add that later.

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

	; if this object is chained, should it also change the linked object?
	; Maybe add that later.  It could only adjust this if both parts have
	; the same number of frames.

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
; and prevent any screen glitchiness on startup.
;
; Reset all Players and Missiles horizontal positions to 0, so
; that none are visible no matter the size or bitmap contents.
; Also reset sizes.
;
; A wholesale screen change from a complex, multi-plexed Player/Missile
; arrangement in the middle of program run time is the responsibility 
; of the program to end the Players/Missiles in acceptable locations.

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
	.if PMG_MAPS>0
		sta MISSILEADR0,x ; Missiles
		sta PLAYERADR0,x  ; Player 0
		sta PLAYERADR1,x  ; Player 1
		sta PLAYERADR2,x  ; Player 2
		sta PLAYERADR3,x  ; Player 3
	.endif
	.if PMG_MAPS>1
		sta MISSILEADR1,x ; Missiles 
		sta PLAYERADR4,x  ; Player 0
		sta PLAYERADR5,x  ; Player 1
		sta PLAYERADR6,x  ; Player 2
		sta PLAYERADR7,x  ; Player 3
	.endif
	.if PMG_MAPS>2
		sta MISSILEADR2,x ; Missiles
		sta PLAYERADR8,x  ; Player 0
		sta PLAYERADR9,x  ; Player 1
		sta PLAYERADR10,x ; Player 2
		sta PLAYERADR11,x ; Player 3
	.endif
	.if PMG_MAPS>3
		sta MISSILEADR3,x ; Missiles
		sta PLAYERADR12,x ; Player 0
		sta PLAYERADR13,x ; Player 1
		sta PLAYERADR14,x ; Player 2
		sta PLAYERADR15,x ; Player 3
	.endif
	inx
	.if PMG_RES=PM_1LINE_RESOLUTION
	bne bLoopClearBitmaps ; Count 1 to 255, then 0 breaks out of loop
	.else ; Use for double line resolution P/M graphics
	bpl bLoopClearBitmaps ; Count 1 to 127, then 128 breaks out of loop
	.endif
	rts




