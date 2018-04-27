; ==========================================================================
; Data declarations and subroutine library code 
; performing Player/missile operations.

; ==========================================================================
; Player/Missile memory is declared in the Memory file. 

; Establish a few other immediate values relative to PMBASE

; For Single Line Resolution:

MISSILEADR = PMGRAM+$300
PLAYERADR0 = PMGRAM+$400
PLAYERADR1 = PMGRAM+$500
PLAYERADR2 = PMGRAM+$600
PLAYERADR3 = PMGRAM+$700


; For Double Line Resolution:

; MISSILEADR = PMGRAM+$180
; PLAYERADR0 = PMGRAM+$200
; PLAYERADR1 = PMGRAM+$280
; PLAYERADR2 = PMGRAM+$300
; PLAYERADR3 = PMGRAM+$380


;===============================================================================
; Variables

pmgAnimsActive     .ds , 0
pmgAnimsStartFrame .ds PmgAnimsMax, 0
pmgAnimsFrame      .ds PmgAnimsMax, 0
pmgAnimsEndFrame   .ds PmgAnimsMax, 0
pmgAnimsStopFrame  .ds PmgAnimsMax, 0
pmgAnimsSpeed      .ds PmgAnimsMax, 0
pmgAnimsDelay      .ds PmgAnimsMax, 0
pmgAnimsLoop       .ds PmgAnimsMax, 0

pmgAnimsCurrent         .byte 0
pmgAnimsFrameCurrent    .byte 0
pmgAnimsEndFrameCurrent .byte 0

pmgNumberMask  
    .byte %00000001, %00000010
    .byte %00000100, %00001000
    .byte %00010000, %00100000
    .byte %01000000, %10000000


;==============================================================================
;										PmgInit                A  X  Y
;==============================================================================

libPmgInit
	; get all Players/Missile off screen.
	jsr libPmgMoveAllZero

    ; clear all bitmap images
    jsr libPmgClearBitmaps
    
	; Tell ANTIC where P/M memory occurs for DMA to GTIA
	lda #>PLAYER_MISSILE_BASE
	sta PMBASE

	; Enable GTIA to accept DMA to the GRAFxx registers.
	lda #ENABLE_PLAYERS | ENABLE_MISSILES 
	sta GRACTL

    rts


;==============================================================================
;										PmgMoveAllZero                A  X
;==============================================================================
; Reset all Players and Missiles horizontal positions to 0, so 
; that none are visible no matter the size or bitmap contents.

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






;==============================================================================
;										ScreenFillMem                A  X  
;==============================================================================
; It is like a generic routine to clear memory, but it specifically sets 
; 1,040 sequential bytes, and it is only used to clear screen RAM.  
;
; ScreenFillMem expects  A  to contain the byte to put into all screen memory.
;
; ScreenFillMem uses  X
;==============================================================================

ScreenFillMem       
	ldx #208              ; Set loop value

LoopScreenFillMem
	sta SCREENRAM-1,x     ; Set +000 - +207 
	sta SCREENRAM+207,x   ; Set +208 - +415  
	sta SCREENRAM+415,x   ; Set +416 - +623 
	sta SCREENRAM+623,x   ; Set +624 - +831
	sta SCREENRAM+831,x   ; Set +832 - +1039

	dex
	bne LoopScreenFillMem ; If x<>0, then loop again

	rts 


;==============================================================================
;										ScreenSetMode                A  Y  
;==============================================================================
; The text/graphics modes on the Atari are determined by the 
; instructions in the Display List.  
;
; The library creates a Display List as a full screen of text similar
; to the way the C64 treats its display. (Done for the purpose of 
; convenience - the least departure from the way the C64 works). 
; In this case "normal" text is a scrren of ANTIC text mode 2. 
;
; To change the entire "screen" all the instructions in the Display List must 
; be changed.  The library supports rewriting all the instructions in the 
; Display with ANTIC modes 2, 4, and 6 which all share the same number of
; scan lines per text line and so have nearly identical Display Lists.
;
; The code will not change the display if  A  does not contain 2, 4, or 6
;
; ScreenSetMode expects  A  to contain the new graphics mode.
;
; ScreenSetMode uses  Y  
;==============================================================================

ScreenSetMode
	cmp #2       ; Mode 2, "normal", 40 chars, 8 scan lines per mode line
	beq bDoScreenSetMode
	cmp #4       ; Mode 4, multi-color, 40 chars, 8 scan lines per mode line
	beq bDoScreenSetMode
	cmp #6       ; Mode 6, 5 color, 20 chars, 8 scan lines per mode line
	bne bExitScreenSetMode ; not 2, 4, 6, so exit.

bDoScreenSetMode
	sta zbTemp   ; Save mode.  We need it frequently.

	; First instruction has LMS and address. Special handling.
	lda vaDisplayList+2
	and #$F0            ; Remove the mode bits.  Keep current option bits.
	ora zbTemp          ; Replace the mode.
	sta vaDisplayList+2 ; Restore first instruction.

	; Do similar to the regular instructions in the display list.
	ldy #24  ; 0 to 24 is 25 more mode lines.

bLoopScreenSetMode
	lda vaDisplayList+5,y
	and #$F0              ; Remove the mode bits.  Keep current option bits.
	ora zbTemp            ; Replace the mode.
	sta vaDisplayList+5,y ; Restore first instruction.

	dey
	bpl bLoopScreenSetMode ; Iterate through the 25 sequential instructions.

bExitScreenSetMode
	rts 


;==============================================================================
;										ScreenWaitScanLine                A  
;==============================================================================
; Subroutine to wait for ANTIC to reach a specific scanline in the display.
;
; ScreenWaitScanLine expects  A  to contain the target scanline.
;==============================================================================

ScreenWaitScanLine

bLoopWaitScanLine
	cmp VCOUNT            ; Does A match the scanline?
	bne bLoopWaitScanLine ; No. Then have not reached the line.

	rts ; Yes.  We're there.  exit.


;==============================================================================
;										ScreenWaitFrames                A  Y
;==============================================================================
; Subroutine to wait for a number of frames.
;
; FYI:
; Calling  mScreenWaitFrames 1  is the same thing as 
; directly calling ScreenWaitFrame.
;
; ScreenWaitFrames expects Y to contain the number of frames.
;
; ScreenWaitFrame uses  A  
;==============================================================================

ScreenWaitFrames
	tay
	beq ExitWaitFrames
	
bLoopWaitFrames
	jsr ScreenWaitFrame
	
	dey
	bne bLoopWaitFrames
	
ExitWaitFrames
	rts ; No.  Clock changed means frame ended.  exit.


;==============================================================================
;										ScreenWaitFrame                A  
;==============================================================================
; Subroutine to wait for the current frame to finish display.
;
; ScreenWaitFrame  uses A
;==============================================================================

ScreenWaitFrame
	lda RTCLOK60  ; Read the jiffy clock incremented during vertical blank.

bLoopWaitFrame
	cmp RTCLOK60       ; Is it still the same?
	beq bLoopWaitFrame ; Yes.  Then the frame has not ended.

	rts ; No.  Clock changed means frame ended.  exit.

