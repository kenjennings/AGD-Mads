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


; ==========================================================================
; Game Specific, Page 0 Declarations, etc.

	icl "chap06Memory.asm"


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
	mScreenWaitFrames 1
	
	; point ANTIC to the new display.
	lda #<vaDisplayList
	sta SDLSTL
	lda #>vaDisplayList
	sta SDLSTH
	
	; Turn the display back on.
	lda #ENABLE_DL_DMA|PLAYFIELD_WIDTH_NORMAL
	sta SDMCTL

	; Set border and background colors.  On the C64 was:
	;     LIBSCREEN_SETCOLORS Blue, White, Black, Black, Black
	; Given the Atari color register order use:
	;     mScreenSetColors Blue, N/A, Black, White, N/A

	mScreenSetColors COLOR_BLUE2|$06, COLOR_RED_ORANGE|$06, COLOR_BLACK, COLOR_GREY|$0E, COLOR_GREEN|$06

    ; Fill the bytes of screen memory. (40x26) display.

	mScreenFillMem 33 ; This is the internal code for 'A'

	; ===== Modifications =====

	; Display a text banner on screen explaining this modification.

	jsr ScreenBanner 

	jsr gClearTime ; reset jiffy clock

;===============================================================================
; Update

gMainLoop

	lda RTCLOK+1     ; Get current 255 frame counter. 

bLoopToDelay         ; 255 frames is about 4.27 second on an NTSC Atari.
	cmp RTCLOK+1 
	beq bLoopToDelay ; When it changes, then we've paused long enough.

	jsr gRandomize   ; choose new colors for screen
	
	mScreenSetColors_M 0,1,2,3,4 ; Set New colors for screen

	jmp gMainLoop


;===============================================================================
; clearTime
;
; Zero the system jiffy clock updated during the vertical blank.

gClearTime
	lda #$00
	sta RTCLOK60 ; $14 ; jiffy clock
	sta RTCLOK+1 ; $13
	sta RTCLOK   ; $12 ; Highest byte

	rts


; ==========================================================================
; Library code and data.

;	mAlign $1000 ; if screen memory is in the library then must align code.
 	
 	icl "lib_screen.asm"


; ==========================================================================
; Inform DOS of the program's Auto-Run address...
	mDiskDPoke DOS_RUN_ADDR, PRG_START
	
	
	END
	