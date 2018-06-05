DO_DIAG=0 ; Turn on/off diagnostics

; ==========================================================================
; System Includes

	icl "ANTIC.asm" 
	icl "GTIA.asm"
	icl "POKEY.asm"
	icl "PIA.asm"
	icl "OS.asm"
	icl "DOS.asm" ; This provides the LOMEM, start, and run addresses.
	
	
; ==========================================================================
; Macros (No code/data declared)

	icl "macros.asm"
	icl "macros_screen.asm"

.if DO_DIAG=1
	icl "macros_diag.asm"
.endif

; ==========================================================================
; Game Specific, Page 0 Declarations, etc.

	icl "chap06Memory.asm"


; ==========================================================================
; Inform DOS of the program's Auto-Run address...
	mDiskDPoke DOS_RUN_ADDR, PRG_START

	
; ==========================================================================
; This is not a complicated program, so losts of RAM is superfluous.  
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

	; Turn the display back on.
	lda #ENABLE_DL_DMA|PLAYFIELD_WIDTH_NORMAL
	sta SDMCTL

	; Set screen colors.  Background (border), colors 0...3.
	mScreenSetColors_V COLOR_BLUE2|$06, COLOR_RED_ORANGE|$06, COLOR_BLACK, COLOR_GREY|$0E, COLOR_GREEN|$06

	; Fill the bytes of screen memory. (40x25) display.
	mScreenFillMem 33 ; This is the internal code for 'A'


;===============================================================================
; Update

gMainLoop
 
        jmp gMainLoop


; ==========================================================================
; Library code and data.
 	
 	icl "chap06lib_screen.asm"

.if DO_DIAG=1
	icl "chap06lib_diag.asm"
.endif
	
	END


