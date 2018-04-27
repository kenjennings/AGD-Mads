;==============================================================================
; lib_input.asm
;==============================================================================

;==============================================================================
; Data declarations and subroutine library code
; performing game controller input.

; The Atari OS solves much of the nitty-gritty providing considerable
; support for polling controllers.  The OS verical blank routine 
; conveniently separates joystick and trigger values into individual. 
; This is stored in shadow variables.


;===============================================================================
; Variables

vbGameportLastFrame .byte 0
vbGameportThisFrame .byte 0
vbGameportDiff      .byte 0
vbTriggerLastFrame  .byte 0
vbTriggerThisFrame  .byte 0
vbTriggerDiff       .byte 0
vbFireDelay         .byte 0
vbFireBlip          .byte 1 ; reversed logic to match other input


;===============================================================================
																INPUTUPDATE A
;===============================================================================
; Collect joystick and trigger information.
; Compare to identify changes.
; Store for later reference.

libInputUpdate

	lda JOYSTICKREGISTER
	sta vbGameportThisFrame
	eor vbGameportLastFrame
	sta vbGameportDiff

	lda TRIGGERREGISTER
	sta vbTriggerThisFrame
	eor vbTriggerLastFrame
	sta vbTriggerDiff
        
	lda vbFireDelay
	beq bIUDelayZero
	dec vbFireDelay
bIUDelayZero

	lda vbGameportThisFrame
	sta vbGameportLastFrame

	lda vbTriggerThisFrame
	lda vbTriggerLastFrame

	rts


;===============================================================================
														INPUT_GETFIREPRESSED  A
;===============================================================================
; Determine if Fire is pressed.  
; Adjust for timing/duration.
;
;
; The caller tests with bne on return

libInput_GetFirePresed

	lda #1
	sta vbFireBlip ; clear Fire flag

	; is fire held?
	lda vbTriggerThisFrame
	and #GAMEPORTFIREMASK
	bne bNotHeld

bHeld
	; is this 1st frame?
	lda vbTriggerDiff
	and #GAMEPORTFIREMASK
        
	beq bNotFirst
	lda #0
	sta vbFireBlip ; Fire

	; reset delay
	lda #FIREDELAYMAX
	sta vbFireDelay        
bNotFirst

	; is the delay zero?
	lda vbFireDelay
	bne bNotHeld
	lda #0
	sta vbFireBlip ; Fire

	; reset delay
	lda #FIREDELAYMAX
	sta vbFireDelay   
        
bNotHeld 
	lda vbFireBlip

	rts


