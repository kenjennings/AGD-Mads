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



;==============================================================================
;										ScreenBanner                A  X  Y
;==============================================================================
; Copy text block to the screen memeory.
;
; This copies a block of text describing the features of the Modifications
; into a fixed location in screen memory.
;
; ScreenBanner uses  A  X  and  Y
;==============================================================================

	; The only bad thing about modern computers is how difficult it is to
	; type those special graphics characters....

	; This is intentionally done using internal screen codes, so the data
	; can be copied directly without using Operating System print functions.

BannerBytes
	.byte $51 ; ctrl-q, upper left box corner
	.rept 30
		.byte $52 ; ctrl-R, horizontal line
	.endr
	.byte $45 ; ctrl-e, upper right box corner

	.byte $7C,"This modification of the      ",$7C ; $7C is vertical bar.
	.byte $7C,"Chapter 6 introductory program",$7C
	.byte $7C,"waits for 256 frames, which is",$7C
	.byte $7C,"about 4 seconds, and then it  ",$7C
	.byte $7C,"changes the screen colors.    ",$7C

	.byte $5A ; ctrl-z, lower left box corner
	.rept 30
		.byte $52 ; ctrl-R, horizontal line
	.endr
	.byte $43 ; ctrl-c, lower right box corner

ScreenBanner
	lda #<BannerBytes   ; Setup zero page pointer to the banner
	sta screenAddress1
	lda #>BannerBytes
	sta screenAddress1+1

	lda #<[SCREENRAM+84] ; Setup the Zero page pointer to the screen position
	sta screenAddress2
	lda #>[SCREENRAM+84]
	sta screenAddress2+1

	ldx #7 ; count the lines

bLoopWriteScreenBannerLine
	ldy #31

bLoopWriteScreenBannerChars
	lda (screenAddress1),y ; Get character from banner buffer.
	sta (screenAddress2),y ; store into screen position

	dey                              ; Decrement. It is actually "writing" right to left.
	bpl  bLoopWriteScreenBannerChars ; if it did not become -1, do another character

	dex   ; decrement line counter..  At 0 we are done.
	beq bExitScreenBanner

	; Adjust starting positions for next line.

	; Add 32 to the banner pointer.
	clc
	lda #32
	adc screenAddress1
	sta screenAddress1
	bcc bOverAddress1High
	inc screenAddress1+1 ; increment of 32 means this only ever changes by 1
bOverAddress1High

	; Add 40 to the screen memory
	clc
	lda #40
	adc screenAddress2
	sta screenAddress2
	bcc bDoNextBannerLine
	inc screenAddress2+1 ; increment of 40 means this only ever changes by 1

bDoNextBannerLine
	jmp bLoopWriteScreenBannerLine ; next line.  no clever branch.  Just goto.

bExitScreenBanner
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

