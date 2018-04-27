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

	icl "chap06MemoryMod.asm"


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
	mScreenWaitFrames 1
	
	; point ANTIC to the new display.
	lda #<vaDisplayList
	sta SDLSTL
	lda #>vaDisplayList
	sta SDLSTH
	
	; Turn the display back on.
	lda #ENABLE_DL_DMA|PLAYFIELD_WIDTH_NORMAL
	sta SDMCTL

	jsr gResetColors ; Set colors for screen (the values already in memeory variables.)

    ; Fill the bytes of screen memory. (40x26) display.
	mScreenFillMem 33 ; This is the internal code for 'A'

	; Display a text banner on screen explaining this modification. 
	jsr ScreenBanner 

	jsr gClearTime ; reset jiffy clock


;===============================================================================
; Update

gMainLoop

	lda RTCLOK+1     ; Get current value of clock incremented after 256 frames. 

bLoopToDelay         ; 256 frames is about 4.27 second on an NTSC Atari.
	cmp RTCLOK+1 
	beq bLoopToDelay ; When it changes, then we've paused long enough.

	jsr gRandomize   ; choose new colors for screen
	
	jsr gResetColors ; Set New colors for screen

	lda #$00 ; Turn off the OS color cycling/anti-screen burn-in
	sta ATRACT
	
	jmp gMainLoop 


;===============================================================================
; Randomize
;
; Choose new colors for background and screen, but selectively filter
; values to insure readable text at all times.
; 
; Bright text backgrounds need dark text.
; Dark backgound needs light text.

gRandomize
	lda RANDOM
	sta zbColbak  ; Border color can be anything.

	lda RANDOM
	sta zbColor2  ; Text background

	and #$08      ; Is luminance 8 (or more)?  Then the background is "bright."
	bne bDarkText ; therefore, we need dark text.

	; "Light" Text.  Guarantee the text is 8 brightness or greater.
	lda RANDOM
	ora #$08           ; Force minimum brightness dialed up to 8. 
	bne bExitRandomize ; Guaranteed that the Z flag is not set now.

bDarkText ; Dark text.  Force off the highest luminance bit.
	lda RANDOM
	and #$06          ; Turn off bit $08.  Allow only $04 and $02 to be on.
	
bExitRandomize
	sta zbColor1      ; set text brightness 
	rts


;===============================================================================
; clearTime
;
; Zero the system jiffy clock updated during the vertical blank.

gClearTime
	lda #$00
	sta RTCLOK60 ; $14 ; jiffy clock, one tick per frame.  approx 1/60th/sec NTSC
	sta RTCLOK+1 ; $13 ; 256 frame counter
	sta RTCLOK   ; $12 ; 65,536 frame counter, Highest byte

	rts


;===============================================================================
; resetColors
;
; Reload the OS shadow color registers from the values in the page 0 variables.

gResetColors
	mScreenSetColors_M zbColBak,zbColor0,zbColor1,zbColor2,zbColor3

	rts
	
; ==========================================================================
; Library code and data.
 	
 	icl "chap06lib_screenMod.asm"


; ==========================================================================
; Inform DOS of the program's Auto-Run address...
	mDiskDPoke DOS_RUN_ADDR, PRG_START
	
	
	END
	