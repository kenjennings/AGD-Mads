; ==========================================================================
; Data declarations and subroutine library code 
; performing screen operations.

; ==========================================================================
; For the sake of simplicity many of the library and supporting functions
; purposely imitate the C64 with its pre-designated locations and 
; full screen layout for playfield graphics.  
;
; In many game circumstances the screen creation is so variable
; on the Atari that it is usually sensible to put that information under
; the control of the main program, not the support library.  However,
; in keeping with the simple C64 model, this library declares the 
; screen memory for full screen of normal text.  The library supports
; a function to switch the display to other text modes that use the same 
;  number of scan lines per mode line.
;
; Because screen RAM and Display List are declared here the 
; main file including this file should align the program address 
; to the next 4K border before including the file.


; For best use of code and optimal execution the macro and library code 
; expect the following variables declared in page 0:

;screenColumn       .byte 0
;screenScrollXValue .byte 0

; If these are not added to page 0 before including this file, then 
; they should be declared here.


;===============================================================================
; Variables

; The 6502 can only multiply times 2.  Doing the math to 
; multiply screen row coordinates by 40 takes several steps.
; Rather than doing the work in code, instead we can do the work 
; in data and pre-calculate math to multiply row values by 40.
 
; Below are two tables to provide the starting address of each 
; ro of screen memory.  When a location is needed simply use the 
; Y coordinate as the lookup index into the table  ( lda table,y ).
; Since addresses require two byte, one table provides the low
; byte of the addres, and the other provides the high byte.

; Creating the tables provides another benefit of using modern
; tools for retro system programming.  

; The code to set up the table data would have looked like this:
;
;ScreenRAMRowStartLow ; SCREENRAM + 40*0, 40*1, 40*2 ... 40*26
;	byte <SCREENRAM,     <SCREENRAM+40,  <SCREENRAM+80
;	byte <SCREENRAM+120, <SCREENRAM+160, <SCREENRAM+200
;	byte <SCREENRAM+240, <SCREENRAM+280, <SCREENRAM+320
;	byte <SCREENRAM+360, <SCREENRAM+400, <SCREENRAM+440
;	byte <SCREENRAM+480, <SCREENRAM+520, <SCREENRAM+560
;	byte <SCREENRAM+600, <SCREENRAM+640, <SCREENRAM+680
;	byte <SCREENRAM+720, <SCREENRAM+760, <SCREENRAM+800
;	byte <SCREENRAM+840, <SCREENRAM+880, <SCREENRAM+920
;	byte <SCREENRAM+960, <SCREENRAM+1000

; This provides an example of the benefits of modern assemblers.
; here is the code to create a table of 26 entries containing the 
; low byte of the addresses for the first byte of screen memory
; in each row of text on screen.

ScreenRAMRowStartLow  ; SCREENRAM + 40*0, 40*1, 40*2 ... 40*26
	.rept 26,#        ; The # provides the current value of the loop
		.byte <[40*:1+SCREENRAM]  ; low byte 40 * loop + Screen mem base.
	.endr

ScreenRAMRowStartHigh  ; SCREENRAM + 40*0, 40*1, 40*2 ... 40*26
	.rept 26,#
		.byte >[40*:1+SCREENRAM] ; low byte 40 * loop + Screen mem base.
	.endr


;==============================================================================
;										ScreenFillMem                A  X  
;==============================================================================
; It is like a generic routine to clear memory, but it specifically sets 
; 1,040 sequential bytes, and it is only used to clear screen RAM.  
;
; ScreenFillMem expects  A  to contain the byte to put into all screen memory.
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
	cmp VCOUNT           ; Does A match the scanline?
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
	cmp RTCLOK60      ; Is it still the same?
	beq bLoopWaitFrame ; Yes.  Then the frame has not ended.

	rts ; No.  Clock changed means frame ended.  exit.
 
