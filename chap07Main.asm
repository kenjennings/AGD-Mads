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
	; This provides a black background.
	mScreenSetMode_V 4

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
    jsr libScreenWaitFrames

    ; Update the library
    jsr libInputUpdate

    ; Update the game
    jsr gamePlayerUpdate


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
	
