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
; Because screen RAM and Display List is declared here the 
; main file including this file should align the program address 
; to the next 4K border before including the file.


;===============================================================================
; Variables

; Why do I like atasm?  Let me count the ways: 
; .rept, .rept, .rept, and then there's also .rept

ScreenRAMRowStartLow               ; SCREENRAM + 40*0, 40*1, 40*2 ... 40*24
	.rept 26,#
		.byte <[SCREENRAM+:1*40]
	.endr
; This is what the .rept block replaces...
;        byte <SCREENRAM,     <SCREENRAM+40,  <SCREENRAM+80
;        byte <SCREENRAM+120, <SCREENRAM+160, <SCREENRAM+200
;        byte <SCREENRAM+240, <SCREENRAM+280, <SCREENRAM+320
;        byte <SCREENRAM+360, <SCREENRAM+400, <SCREENRAM+440
;        byte <SCREENRAM+480, <SCREENRAM+520, <SCREENRAM+560
;        byte <SCREENRAM+600, <SCREENRAM+640, <SCREENRAM+680
;        byte <SCREENRAM+720, <SCREENRAM+760, <SCREENRAM+800
;        byte <SCREENRAM+840, <SCREENRAM+880, <SCREENRAM+920
;        byte <SCREENRAM+960

ScreenRAMRowStartHigh  ;  SCREENRAM + 40*0, 40*1, 40*2 ... 40*24
	.rept 26,#
		.byte >[SCREENRAM+:1*40]
	.endr


;.if .not .def screenColumn
;screenColumn       .byte 0
;screenScrollXValue .byte 0
;.endif


;==============================================================================
; Originally: LIBSCREEN_SET1000
;
; It is like a generic routine to clear memory, but it specifically sets 
; 1,000 sequential bytes, and it is only used to clear screen RAM and 
; Color RAM on the C64.  
;
; Since the Atari doesn't use color RAM, the only purpose left is screen 
; RAM, so this can be a dedicated routine.
;
;
; The code expects  A  to contain the byte to put into all screen memory.
;
; ScreenFillMem uses  A, and X

;.if DO_ScreenFillMem>0 .OR .ref ScreenFillMem
ScreenFillMem       
	ldx #208               ; Set loop value

LoopScreenFillMem
	sta SCREENRAM-1,x      ; Set +000 - +207 
	sta SCREENRAM+207,x    ; Set +208 - +415  
	sta SCREENRAM+415,x    ; Set +416 - +623 
	sta SCREENRAM+623,x    ; Set +624 - +831
	sta SCREENRAM+831,x    ; Set +832 - +1039

	dex
	bne LoopScreenFillMem ; If x<>0 loop

	rts 
;.endif


;==============================================================================
; Originally: LIBSCREEN_SETMULTICOLORMODE
; 
; On the Atari the text/graphics modes are determined by the instructions in
; the Display List.  
;
; For the purpose of convenience the library creates its own Display List for 
; a full screen of text similar to the C64.  In this case "normal" text 
; is ANTIC text mode 2. 
;
; To change the entire "screen" all the instructions in the Display List must 
; be changed.  The library supports rewriting all the instructions in the 
; Display with ANTIC modes 2, 4, and 6 which all share the same number of
; scan lines per text line and so have nearly identical Display Lists.
;
; The code will exit if  A  does not contain 2, 4, or 6
;
; ScreenSetMode uses ZeroPageTemp, A, and Y

;.if DO_ScreenSetMode>0 .OR .ref ScreenSetMode
ScreenSetMode

	cmp #2 ; Mode 2, "normal", 40 chars, 8 scan lines per mode line
	beq bDoScreenSetMode
	cmp #4 ; Mode 4, multi-color, 40 chars, 8 scan lines per mode line
	beq bDoScreenSetMode
	cmp #6 ; Mode 6, 5 color, 20 chars, 8 scan lines per mode line
	bne bExitScreenSetMode
	
bDoScreenSetMode
	sta ZeroPageTemp ; Save mode.  We need it frequently.

	; First instruction has LMS and address. Special handling.
	lda vDisplayList+2
	and #$F0           ; Remove the mode bits.  Keep current option bits.
	ora ZeroPageTemp   ; Replace the mode.
	sta vDisplayList+2 ; Restore first instruction.

	; Do similar to the regular instructions in the display list.
	ldy #24  ; 0 to 24 is 25 more mode lines.

bLoopScreenSetMode
	lda vDisplayList+5,y
	and #$F0             ; Remove the mode bits.  Keep current option bits.
	ora ZeroPageTemp     ; Replace the mode.
	sta vDisplayList+5,y ; Restore first instruction.

	dey
	bpl bLoopScreenSetMode ; Iterate through the 25 sequential instructions.

bExitScreenSetMode
	rts 
;.endif

      
; ==========================================================================
; Subroutine to wait for ANTIC to reach a specific scanline in the display.
;
; ScreenWaitScanLine expects  A  to contain the target scanline.

;.if DO_ScreenWaitScanLine>0 .OR .ref ScreenWaitScanLine
ScreenWaitScanLine

LoopWaitScanLine
	cmp VCOUNT       ; Does A match the scanline?
	bne LoopWaitScanLine ; Nop.  Then have not reached the line.
	
	rts ; Yes.  We're there.  exit.
;.endif


; ==========================================================================
; Subroutine to wait for a number of frames.
;
; ScreenWaitFrames expects Y to contain the number of frames.
;
; ScreenWaitFrame uses  A 
;
; FYI:  Calling  mScreenWaitFrames 1  is the same thing as 
;       directly calling ScreenWaitFrame.

;.if DO_ScreenWaitFrames>0 .OR .ref ScreenWaitFrames
ScreenWaitFrames
	tay
	beq ExitWaitFrames
	
LoopWaitFrames
;	DO_ScreenWaitFrame .= 1
	jsr ScreenWaitFrame
	
	dey
	bne LoopWaitFrames
	
ExitWaitFrames	
	rts ; No.  Clock changed means frame ended.  exit.
;.endif

       
; ==========================================================================
; Subroutine to wait for the current frame to finish display
;
; ScreenWaitFrame  uses A

;.if DO_ScreenWaitFrame>0 .OR .ref ScreenWaitFrame
ScreenWaitFrame
	lda RTCLOK60 ; Read the clock incremented during vertical blank.

LoopWaitFrame
	cmp RTCLOK60      ; Is it still the same?
	beq LoopWaitFrame ; Yes.  Then the frame has not ended.
	
	rts ; No.  Clock changed means frame ended.  exit.
;.endif



