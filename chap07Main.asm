; ==========================================================================
; System Includes

	icl "ANTIC.asm"
	icl "GTIA.asm"
	icl "POKEY.asm"
	icl "PIA.asm"
	icl "OS.asm"
	icl "DOS.asm" ; This provides the LOMEM, start, and run addresses.

; ==========================================================================
; CONDITIONAL VALUES
;
; Ordinarily these should be set by command line arguments to the
; assembler, but that can be a pain when this is managed by an IDE,
; so here are these values declared in code at Build time.
;
; Diagnostics enabled for diag macros and library.
; 0 = off (normal display, 25 lines of text),
; 1 = on (two extra lines of diagnostic texts added to display)
DO_DIAG=0

; Player/Missile resolution for pmgraphics macros/library.
; Use ANTIC PM_1LINE_RESOLUTION and PM_2LINE_RESOLUTION
; From command line this is:
; 0 = 2 line resolution. (128 vertical pixels, or 2 scan lines per byte)
; 8 = 1 line resolution (256 vertical pixels, or 1 scan lines per byte)
PMG_RES=PM_1LINE_RESOLUTION


; ==========================================================================
; Macros (No code/data declared)

	icl "macros.asm"
	icl "macros_screen.asm"
	icl "macros_math.asm"

.if DO_DIAG=1
	icl "macros_diag.asm"
.endif


; ==========================================================================
; Game Specific, Page 0 Declarations, etc.

	icl "chap07Memory.asm"


; ==========================================================================
; Inform DOS of the program's Auto-Run address...
	mDiskDPoke DOS_RUN_ADDR, PRG_START


; ==========================================================================
; This is not a complicated program, so need not be careful about RAM.
; Just set code at a convenient place after DOS, DUP, etc.

	ORG LOMEM_DOS_DUP; $3308  From DOS.asm.  First memory after DOS and DUP


;===============================================================================


PRG_START


;===============================================================================
; Initialize

	; Turn off screen
	lda #0
	sta SDMCTL ; OS Shadow for DMA control

	; Wait for frame update before touching other display configuration
	mScreenWaitFrames_V 1

	; point ANTIC to the new display.
	mLoadInt_V SDLSTL,vsDisplayList

	; Reset Display List to mode 4 (multi-color text).
	; This provides black background through the overscan area.
	mScreenSetMode_V DL_TEXT_4 ; ANTIC mode is the same as using "4"

	; Set background and playfield colors.
	mScreenSetColors_V COLOR_BLACK, COLOR_WHITE, COLOR_BLUE2|$06, COLOR_RED_ORANGE|$06, COLOR_GREEN|$06

	; Fill the bytes of screen memory. (40x25) display.
	mScreenFillMem SPACESCREENCODE ; Blank space/empty screen

.if DO_DIAG=1
	jsr libDiagWriteLabels ; write out the diagnostics labels
.endif

	; Setup Player/Missile Graphics
    jsr libPmgInit

	; Turn the display back on.
	lda #ENABLE_DL_DMA|PLAYFIELD_WIDTH_NORMAL|PM_1LINE_RESOLUTION|ENABLE_PM_DMA
	sta SDMCTL

    ; Initialize the game
	jsr libGamePlayerInit


;===============================================================================
; Update

gMainLoop

	; Wait for end of frame
	jsr libScreenWaitFrame

	; Update the library
	jsr libInputUpdate

	; Update the game
	jsr libGamePlayerUpdate

	jmp gMainLoop


; ==========================================================================
; Library code and data.

 	icl "chap07lib_screen.asm"
 	icl "chap07lib_pmgraphics.asm"
	icl "chap07lib_input.asm"

.if DO_DIAG=1
	icl "chap06lib_diag.asm"
.endif


	END

