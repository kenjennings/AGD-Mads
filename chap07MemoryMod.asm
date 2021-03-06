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


; Default colors.  Modifiable later to change the screen....

zbColBak .byte COLOR_BLUE2|$06      ; Border
zbColor0 .byte COLOR_RED_ORANGE|$06 ; COLPF0 (not used in Mode 2 text)
zbColor1 .byte COLOR_BLACK          ; COLPF1 Text brightness
zbColor2 .byte COLOR_GREY|$0E       ; COLPF2 Text background color.
zbColor3 .byte COLOR_GREEN|$06      ; COLPF3 (not used in Mode 2 text)


;===============================================================================
; lib_screen.asm wants these values below.
; Declare here in page 0 for better performance.
; Otherwise, remember to declare elsewhere.

screenColumn       .byte 0
screenScrollXValue .byte 0

screenAddress1     .word 0
screenAddress2     .word 0

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
; This is 26 lines of Mode 2 text (aka BASIC GRAPHICS 0)
; Why 26?  Because we can.
;
; See ScreenSetMode to change the Display List to text modes 2, 4, or 6 
; which all share the same number of scanlines per mode line, so the 
; Display Lists are nearly identical.
;
; mDL_LMS macro requires ANTIC.asm.  That should have already been included, 
; since the program is working on a screen display..

	ORG $4000

SCREENRAM ; Imitate the C64 convention of a full-screen for a display mode.
vaScreenRam
	.ds [26*40]

vaDisplayList
	.byte DL_BLANK_8   ; 8 blank scan lines
	.byte DL_BLANK_8   ; 8 blank scan lines
	mDL_LMS DL_TEXT_2, vaScreenRam ; mode 2 text and init memory scan address
	.rept 25
	.byte DL_TEXT_2    ; 25 more lines of mode 2 text (memory scan is automatic)
	.endr
	.byte DL_JUMP_VB   ; End.  Wait for Vertical Blank.
	.word vaDisplayList ; Restart the Display List


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
