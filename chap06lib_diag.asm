;==============================================================================
; lib_diag.asm
;==============================================================================

.if DO_DIAG=1
;==============================================================================
; Data declarations and subroutine library code
; performing diagnostic/debug operations.


;===============================================================================
; Variables


;==============================================================================
;														DIAGCLEAR  A  X  
;==============================================================================
; Subroutine to clear the bytes of screen memory used for the 
; diagnostic lines.
;
; ScreenFillMem uses  A and X
;
;==============================================================================

libDiagClear
	ldx #79
	lda #SPACESCREENCODE

bLoopDiagFillMem
	sta vsScreenDiagRam,x
	dex
	bpl bLoopDiagFillMem

	rts 


;==============================================================================
;														DIAGWRITELABELS  A  X
;==============================================================================
; Copy text defined for the diagnostic labels to the screen memory.
;
; This copies text describing the diagnostic values 
; into a fixed location in screen memory.
;
; DiagWriteLabels uses  A  X 
;==============================================================================

	;  Two lines, 40 characters each to label the diagnostic info	
vsDiagLabelBytes
	.byte "RTCLOK:                                 " 
	.byte "COLBAK:    COLOR1:    COLOR2:           " 
	

libDiagWriteLabels
	ldx #79
	
bLoopWriteDiagLabelChars
	lda vsDiagLabelBytes,x ; Get character from  label buffer.
	sta vsScreenDiagRam,x  ; store into screen position

	dex                           ; Decrement. It is "writing" right to left.
	bpl  bLoopWriteDiagLabelChars ; if it did not become -1, do another character

	rts


;==============================================================================
;													DIAGDISPLAYBYTE  A  X  Y
;==============================================================================
; Write a the hex pair value at a specified position in the 
; diagnostic text lines.
;
; Positions 0 to 39 are in the first line of diagnostic text.
; Positions 40 to 29 are in the second line.
;
; mDiagDisplayByte macro saves all CPU registers before calling this.
;
; DiagDisplayByte expects  A  to contain the byte value.
;
; DiagDisplayByte expects  X  to contain the position.
; 
; DiagDisplayByte uses  Y  as a temporary value.
;==============================================================================

vsNybbleToText
    .byte "0123456789ABCDEF" ; Note these are internal screen codes.

libDiagDisplayByte
	; Print the first hex digit.
	pha                   ; save the byte temporarily.
	lsr                   ; shift high nybble into low nybble (value of 0-F)
	lsr
	lsr
	lsr
	tay                   ; index into lookup table
	lda vsNybbleToText,y  ; no math.  just lookup table.
	sta vsScreenDiagRam,x ; stuff that into screen memory

	; Print the second hex digit.
	inx                   ; next screen position
	pla                   ; Get the original byte value back.
	and #$0F              ; Mask out the high nybble leaving low nybble (0 to F)
	tay                   ; index into lookup table
	lda vsNybbleToText,y  ; no math.  just lookup table.
	sta vsScreenDiagRam,x ; stuff that into screen memory

	rts	
	
 

.endif ; if DO_DIAG=1


