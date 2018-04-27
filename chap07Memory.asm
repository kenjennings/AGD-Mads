;===============================================================================
; $00-$FF  PAGE ZERO (256 bytes)
; $00-$7F  OS variables.
; $80-$FF  Free memory if floating point functions are not used.

	ORG $80

zbTemp   .byte 0
zbParam1 .byte 0
zbParam2 .byte 0
zbParam3 .byte 0
zbParam4 .byte 0
zbParam5 .byte 0
zbParam6 .byte 0
zbParam7 .byte 0
zbParam8 .byte 0
zbParam9 .byte 0
zbLow    .byte 0
zbHigh   .byte 0
zbLow2   .byte 0
zbHigh2  .byte 0

zwAddr1 = zbLow
zwAddr2 = zbLow2

;===============================================================================
; lib_screen.asm wants these values below.
; Declare here in page 0 for better performance.
; Otherwise, remember to declare elsewhere.

screenColumn       .byte 0
screenScrollXValue .byte 0


;===============================================================================
; lib_pmgraphics.asm has a collection of variables for animation. (PMGOBJECTS)
; Declare here in page 0 for better performance, smaller code, and page
; zero special instruction benefits.

; The setup macro populates some of these, then calls the library init routine
; to finish attaching the animation to the object.
;
; The animation routine copies all of these from the PMGOBJECTS (if PmgEnable and
; PmgIdent allow) and from other Anim and Sequence lists, does its work,
; updates the current image if it changes, and then copies these values back
; into the PMGOBJECTS as needed.
;
; Individual values Set... directly in PMGOBJECTS will not cause the object to be
; redrawn.  Redraw is done only in animation processing.
;
; The fastest way to "remove" an object is to disable it.   (PmgEnable=0 )
; This action will also set the real HPOS to 0 causing any display code to move
; the object off screen where it is not visible.  Everything else, such as
; clearing the image bitmap, is an optional extra step.

zbPmgCurrentIdent  .byte 0   ; current index number for PMGOBJECTS
zbPmgEnable        .byte 0   ; Object is on/1 or off/0.  If off, skip processing.

; Direct Player/Missile hardware relationships...

zbPmgIdent         .byte $FF ; Missile 0 to 3. Player 4 to 7.  FF is unused

zbPmgColor         .byte 0   ; Color of each object.
zbPmgSize          .byte 0   ; HSize of object.
zbPmgVDelay        .byte 0   ; VDelay (for double line resolution.)

zbPmgCollideToField  .byte 0   ; Display code's collected M-PF or P-PF collision value.
zbPmgCollideToPlayer .byte 0   ; Display code's collected M-PL or P-PL collision value.

zwPmgAddr          .word 0   ; objects' PMADR base (zwPmgAddr),zbPmgRealVPos

zbPmgHPos          .byte 0   ; X position of each object (logical)
zbPmgRealHPos      .byte 0   ; Real X position on screen (if controls adjusts PmgHPos)

; Still "hardware", but not registers. Just memory offsets.

zbPmgVPos          .byte 0   ; Y coordinate of each object (logical)
zbPmgRealVPos      .byte 0   ; Real Y position on screen (if controls adjusts PmgVPos)
zbPmgPrevVPos      .byte 0   ; Previous Y position before move  (if controls adjusts PmgVPos)

; Managing Animation Frame Bitmap Images. . .

zbSeqIdent     .byte 0   ; (R) Animation (sequence) ID in use
zbSeqEnable    .byte 0   ; (W) Animation is Playing/1 or Paused/0

zwSeqAddr   .word 0   ; (R) address of of animation sequence structure (zbPmgAnimLo),zbPmgAnimSeqFrame

zbSeqCount        .byte 0 ; (R) Number of frames in the animation sequence.
zbSeqFrameIndex   .byte 0 ; (W) current index into frame list for this sequence.
zbSeqFrameCurrent .byte 0 ; (W) current frame number.
zbSeqFramePrev    .byte 0 ; (W) previous frame number. (No change means no redraw)

zbSeqDelay      .byte 0   ; (R) Number of TV frames to wait for each animation frame
zbSeqDelayCount .byte 0   ; (W) Frame countdown when vsAnimDelay is not zero

zbSeqLoop   .byte 0   ; (R) Does animation sequence repeat? 0/no, 1/yes
zbSeqBounce .byte 0   ; (R) Does repeat go ABCDABCD or ABCDCBABCD (0/linear, 1/bounce)
zbSeqDir    .byte 0   ; (W) Direction of animation progression. + or -

; Animation frame bitmap/graphics management...

; FYI "frame ID" numbers belong to the sequence management.

zwFrameAddr    .word 0   ; (R) Address of current image frame
zwFrameHeight  .byte 0   ; (R) Height of current image frame.


;===============================================================================
; $100-$1FF  The 6502 stack.


;===============================================================================
; $200-$4FF  OS variables, and Central I/O device control control and buffers.


;===============================================================================
; $480-$4FF  Free memory.


;===============================================================================
; $500-$57D  Free memory.


;===============================================================================
; $57E-$5FF  Free memory IF floating point library functions are not used.


;===============================================================================
; $600-$6FF  Free memory.


;===============================================================================
; $700-$153F  DOS 2.0 FMS when loaded into memory


;===============================================================================
; $1540-$3306  DUP (DOS user interface menus) when loaded into memory.


;===============================================================================
; Part of DUP may be overlapped by a program when MEMSAVE file is present to
; allow the swapping.  However, the game programs are fairly simple.  There
; is no reason to do anything clever in low memory/DOS memory outside of
; Page 0.  Thus program start addresses should use the LOMEM_DOS_DUP symbol
; and then do alignment as needed from there.

; LOMEM_DOS =     $2000 ; First available memory after DOS
; LOMEM_DOS_DUP = $3308 ; First available memory after DOS and DUP


;===============================================================================
; $3308-$BFFF  Minimum free memory for the program use. (35.24K (worst case))
;              See notes below about possible cartridges.


; ==========================================================================
; Create the custom game screen
;
; This is 26 lines of Mode 2 text (aka BASIC GRAPHICS 0)
; Why 26?  Because we can.
;
; See ScreenSetMode to change the Display List to text modes 2, 4, or 6
; which all share the same number of scanlines per mode line, so the
; Display Lists are nearly identical.
;
; mDL_LMS macro requires ANTIC.asm.  That should have already been included,
; since the program is working on a screen display..

	ORG $4000

SCREENRAM ; Imitate the C64 convention of a full-screen for a display mode.
vsScreenRam
	.ds [25*40] ; 25 lines for the screen.

SCREENDIAGRAM
vsScreenDiagRam
.if DO_DIAG=1
	.ds [2*40]  ; 2 lines for diagnostics
.endif

	.align $0400 ; Go to 1K boundary  to make sure display list
	             ; doesn't cross the 1K boundary.

vsDisplayList
.if DO_DIAG=0
	.byte DL_BLANK_8   ; extra 8 blank to center 25 text lines
.endif

	.byte DL_BLANK_8   ; 8 blank scan lines
	.byte DL_BLANK_4   ;

.if DO_DIAG=1
	mDL_LMS DL_TEXT_2, vsScreenDiagRam ; show diagnostics from last bytes.
.endif

	mDL_LMS DL_TEXT_2, vsScreenRam ; mode 2 text and init memory scan address
	.rept 24
	.byte DL_TEXT_2   ; 24 more lines of mode 2 text (memory scan is automatic)
	.endr

.if DO_DIAG=1
	mDL_LMS DL_TEXT_2, vsScreenDiagRam+40 ; show from last bytes.
.endif

	.byte DL_JUMP_VB    ; End.  Wait for Vertical Blank.
	.word vsDisplayList ; Restart the Display List


	.align $0800 ; For Player/Missile graphics get the next 2K boundary

PMGRAM
vsPmgRam
;	.ds [2048]  Ordinarily, do it this way with .DS to reserve the block.
; But, a little cheating going on here. We're using the unused part of the P/M memory
; map for the animation images which is far larger than the space needed for the
; nine animation frames.

vsImageBlank .ds 21,0 ; Could probably handle this in code
					  ;  but good form to have an officially blank frame.
vsImagePlayer
	icl "chap07player.bin"
vsImageEnemy1
	icl "chap07enemyship1.bin"
vsImageEnemy2
	icl "chap07enemyship2.bin"
vsImageExplosion
	icl "chap07explosion.bin" ; 5 frames

	ORG vsPgRam+2048


;===============================================================================
; $3308-$7FFF  Free memory.


;===============================================================================
; $8000-$BFFF  Cartridge B (right cartridge) (8K).
;              A right cart is only possible (and rarely so) on Atari 800.
;              16K cart in the A or left slot also occupies this space.
;              Free memory if no cartridge is installed.


;===============================================================================
; $A000-$BFFF  Cartridge A (left cartridge) or BASIC ROM (8K)
;              Free memory if no cartridge is installed or BASIC is disabled.


;===============================================================================
; $C000-$CFFF  On some machines, unused.  On others, OS ROM or RAM. (4K)


;===============================================================================
; $D000-$D7FF  Custom Chip I/O registers (2K)


;===============================================================================
; $D800-$FFFF  Operating System (10K)
;       $D800-$DFFF  OS Floating Point Math Package (2K)
;       $E000-$E3FF  Default OS Screen Font (1K)
;       $E400-$FFFF  General OS functions (7K)
