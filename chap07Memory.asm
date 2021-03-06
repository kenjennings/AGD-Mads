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
; lib_input.asm needs these values below.

zbGameportLastFrame .byte 0
zbGameportThisFrame .byte 0
zbGameportDiff      .byte 0
zbTriggerLastFrame  .byte 0
zbTriggerThisFrame  .byte 0
zbTriggerDiff       .byte 0
zbFireDelay         .byte 0
zbFireBlip          .byte 1 ; reversed logic to match other input


;===============================================================================
; lib_screen.asm wants these values below.
; Declare here in page 0 for better performance.
; Otherwise, remember to declare elsewhere.

screenColumn       .byte 0
screenScrollXValue .byte 0


;===============================================================================
; lib_pmgraphics.asm has a collection of variables for animation. (PMGOBJECTS)
;
; Initialization requires a number of arguments, declared here.
; The setup macro populates some of these, then calls the library init routine
; to finish attaching the animation parts to the object.
;
; Other values are here in page 0 for better performance,
; smaller code, and page zero special instruction benefits.
;;
; Individual values Set... directly in PMGOBJECTS will not cause the object
; to be redrawn.  Redraw is done only in animation processing.

zbPmgEnable      .byte 0   ; Object is on/1 or off/0.  If off, skip processing.

; Direct Player/Missile hardware relationships...

zbPmgIdent       .byte $FF ; Missile 0 to 3. Player 4 to 7.  FF is unused

zbPmgFifth       .byte 0   ; Flag to make Missile behave like Player.
zbPmgColor       .byte 0   ; Color of each object.
zbPmgSize        .byte 0   ; HSize of object.  (Use GTIA.asm PM_SIZE_*)
zbPmgVDelay      .byte 0   ; VDelay (for double line resolution.)

zbPmgHPos        .byte 0   ; X position of each object (logical)
zbPmgVPos        .byte 0   ; Y coordinate of each object (logical)

zbPmgChainIdent  .byte 0   ; Object ID of next chained object.
zbPmgisChain     .byte 0   ; Flag if this object is a chain object. 0/No, 1/Yes.
zbPmgXOffset     .byte 0   ; X offset of HPos (typically for a chained P/M object)
zbPmgYOffset     .byte 0   ; Y offset of VPos (typically for a chained P/M object)

; Animation sequence assignment

zbSeqIdent       .byte 0   ; (R) Animation (sequence) ID in use
zbSeqEnable      .byte 0   ; (W) Animation is Playing/1 or Paused/0
zbSeqStart       .byte 0   ; (R) Force start frame index at initialization

; objects' mask info.  works like this:
; P/M Memory = (P/M Memory AND vsPmgMaskAND_OFF) OR (Image AND vsPmgMaskAND_ON)

zbPmgMaskAND_OFF .byte 0   ; Turn off selected Missile bits, keep the neighbors' bits.
zbPmgMaskAND_ON  .byte 0   ; Turn off the neighbors' bits, keep the selected Missile bits.

; objects' P/M base. Use as: lda (zwPmgAddr),zbPmgRealVPos [as Y]

zwPmgAddr        .word 0

; Animation frame bitmap/graphics management...
; FYI "frame ID" numbers belong to the sequence management.

zwFrameAddr      .word 0   ; (R) Address of current image frame
zbFrameHeight    .byte 0   ; (R) Height of current image frame.

zbPmgLinesToZero .byte 0   ; Number of bytes of P/M memory to zero before or after frame.

; Forcing Pmg Ident to end of page 0, address $FF.  Therefore, the
; non-Page 0 memory values can be $00 to $FE.  (theoretically)
; This means the real (theoretical) list of working PMOBJECTS could
; be numbered from 0 to $FE (254).
;
; Realistically, 0 to 254 objects is ridiculous.  Even putting the ident
; at $80 would allow for 0 to 127 object IDs which is more than any game
; could find realistic.  Though, for the sake of completing the thought
; process on this subject, the ident value $80 provides some gains -- for
; instance, all valid object IDs would then be only positive numbers which
; can cut down some explicit comparisons.

	ORG $FF

zbPmgCurrentIdent .byte 0   ; current index number for PMGOBJECTS


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
; So many people think the Atari displays only 192 scan lines or
; 24 lines of mode 2 text (aka Graphics 0).  But, this is an artificial
; limit enforced by the Operating System when it creates graphics modes.
; The reality is the ANTIC hardware displays 240 scan lines (30 mode 2 text
; lines). No special tricks, no interrupts or assembly register bashing
; needed.  All it requires is a Display List to specify using these lines.
;
; The games use displays showing 25 lines of Mode 2 text to immitate the
; default C64 screen size.
;
; When the build includes the option for visual diagnostics the Display
; List adds two extra lines (27 total text lines) for diagnostics.
; One line appears above the game's regular 25 lines, and one line appears
; below the game's display.  This keeps the game's screen centered and
; fixed to the same scan line position regardless if the visual diagnostics
; lines are present or absent.
;
; See ScreenSetMode to change the Display List to text modes 2, 4, or 6
; which all share the same number of scanlines per mode line, so the
; Display Lists are nearly identical.
;
; mDL_LMS macro requires ANTIC.asm.  That should have already been included,
; since the program is working on a screen display.

; ==========================================================================
; (1) Declare/define text screen memory
; ==========================================================================

	ORG $4000

SCREENRAM ; Imitate the C64 convention of a full-screen for a display mode.
vsScreenRam
	.ds [25*40] ; 25 lines for the screen.

SCREENDIAGRAM ; Space for two more lines of diagnostic text
vsScreenDiagRam
.if DO_DIAG=1
	.ds [2*40]  ; 2 lines for diagnostics
.endif

; ==========================================================================
; (2) Declare/define Display List
; ==========================================================================

; The Display List.  Since a Display List cannot cross a 1K boundary,
; a complicated program may push the alignment to the next 1K.  But,
; this is not too terribly complicated, and the Display List will be
; small, so it is reasonable to just align to the next page.

	.align $0100 ; Go to next page to make sure display list
	             ; doesn't cross the 1K boundary.

vsDisplayList
.if DO_DIAG=0          ; If Diag is off then
	.byte DL_BLANK_8   ; extra 8 blank to center 25 text lines
.endif

	.byte DL_BLANK_8   ; 8 blank scan lines
	.byte DL_BLANK_4   ;

.if DO_DIAG=1                          ; If Diag is On then
	mDL_LMS DL_TEXT_2, vsScreenDiagRam ; show first line of diagnostics.
.endif

	mDL_LMS DL_TEXT_2, vsScreenRam ; mode 2 text and init memory scan address
	.rept 24
	.byte DL_TEXT_2   ; 24 more lines of mode 2 text (memory scan is automatic)
	.endr

.if DO_DIAG=1                             ; If Diag is On then
	mDL_LMS DL_TEXT_2, vsScreenDiagRam+40 ; show last line of diagnostics.
.endif

	.byte DL_JUMP_VB    ; End.  Wait for Vertical Blank.
	.word vsDisplayList ; Restart the Display List

; ==========================================================================
; (3) Declare/define Player/Missile graphics memory 
; ==========================================================================

; For Player/Missile graphics determine the appropriate boundary
; 1K for double line resolution.
; 2k for single line resolution.

	mPmgAllocateMaps ; per value of PMG_MAPS create 1 to 4 P/M memory maps.

END_PMGRAM  ; keep track of where we ended.

; A little cheating going on here. Use the "unused" part at the beginning
; of the Player/Missile memory map for the animation images.
; This space is far larger than needed for the nine animation frames.

; ORG gymnastics like this approach a level of stupid on the border 
; of causing an assembly phase error.  Carefulness.

; Fire in the hole.  Return assembly location to first Player/Missile memory map.

	ORG PMGRAM 

; Load Player/Missile animation shapes.

vsImageBlank .ds 21,0 ; An "empty" image could be done using code, but
					  ; it is consistent to have an officially blank frame.

vsImagePlayer
	icl "chap07player.bin"

vsImageEnemy1
	icl "chap07enemyship1.bin"

vsImageEnemy2
	icl "chap07enemyship2.bin"

vsImageExplosion
	icl "chap07explosion.bin" ; 5 frames

; Return to the assembly location after the Player/Missile graphics memory map.

	ORG END_PMGRAM


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
