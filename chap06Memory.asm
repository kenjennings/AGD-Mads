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

zwAddr1 = zbLow
zwAddr2 = zbLow2

;===============================================================================
; lib_screen.asm wants these values below.
; Declare here in page 0 for better performance.
; Otherwise, remember to declare elsewhere.

screenColumn       .byte 0
screenScrollXValue .byte 0


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
; This is 27 lines of Mode 2 text (aka BASIC GRAPHICS 0)
; Why 27?  Because we can. 
;
; Actually, the first and last lines are use for diagnostic
; information when the DO_DIAG value is set.  This allows
; the 25 lines between them to occupy the exact same scan 
; lines whether or not DO_DIAG is set.
;
; See ScreenSetMode to change the Display List to text modes 2, 4, or 6 
; which all share the same number of scanlines per mode line, so the 
; Display Lists are nearly identical.
;
; mDL_LMS macro requires ANTIC.asm.  That should have already been included, 
; since the program is working on a screen display..

	ORG $4000

SCREENRAM ; Imitate the C64 convention of a full-screen for a display mode.
vsScreenRam
	.ds [25*40] ; 25 lines for the screen.
	
SCREENDIAGRAM
vsScreenDiagRam
.if DO_DIAG=1 
	.ds [2*40]  ; 2 lines for diagnostics
.endif

	.align $0400 ; Go to 1K boundary  to make sure display list 
	             ; doesn't cross the 1K boundary.

vsDisplayList
.if DO_DIAG=0
	.byte DL_BLANK_8   ; extra 8 blank to center 25 text lines
.endif

	.byte DL_BLANK_8   ; 8 blank scan lines
	.byte DL_BLANK_4   ; 

.if DO_DIAG=1
	mDL_LMS DL_TEXT_2, vsScreenRam+1000 ; show from last bytes.
.endif

	mDL_LMS DL_TEXT_2, vsScreenRam ; mode 2 text and init memory scan address
	.rept 24
	.byte DL_TEXT_2   ; 24 more lines of mode 2 text (memory scan is automatic)
	.endr

.if DO_DIAG=1
	mDL_LMS DL_TEXT_2, vsScreenRam+1040 ; show from last bytes.
.endif

	.byte DL_JUMP_VB    ; End.  Wait for Vertical Blank.
	.word vsDisplayList ; Restart the Display List


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


