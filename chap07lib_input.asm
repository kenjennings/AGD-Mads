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
; Variables -- See Page 0 memory

; vbGameportLastFrame .byte 0
; vbGameportThisFrame .byte 0
; vbGameportDiff      .byte 0
; vbTriggerLastFrame  .byte 0
; vbTriggerThisFrame  .byte 0
; vbTriggerDiff       .byte 0
; vbFireDelay         .byte 0
; vbFireBlip          .byte 1 ; reversed logic to match other input


;===============================================================================
																INPUTUPDATE A
;===============================================================================
; Collect joystick and trigger information.
; Compare to prior value to identify changes.
; Store for later reference.

libInputUpdate

	lda JOYSTICKREGISTER
	sta zbGameportThisFrame
	eor zbGameportLastFrame
	sta zbGameportDiff

	lda TRIGGERREGISTER
	sta zbTriggerThisFrame
	eor zbTriggerLastFrame
	sta zbTriggerDiff
        
	lda zbFireDelay
	beq bIUDelayZero
	dec zbFireDelay

bIUDelayZero
	lda zbGameportThisFrame
	sta zbGameportLastFrame

	lda zbTriggerThisFrame
	lda zbTriggerLastFrame

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
	sta zbFireBlip ; clear Fire flag

	; is fire held?
	lda zbTriggerThisFrame
	and #GAMEPORTFIREMASK
	bne bNotHeld

bHeld
	; is this 1st frame?
	lda zbTriggerDiff
	and #GAMEPORTFIREMASK
        
	beq bNotFirst
	lda #0
	sta zbFireBlip ; Fire

	; reset delay
	lda #FIREDELAYMAX
	sta zbFireDelay 

bNotFirst
	; is the delay zero?
	lda zbFireDelay
	bne bNotHeld
	lda #0
	sta zbFireBlip ; Fire

	; reset delay
	lda #FIREDELAYMAX
	sta zbFireDelay   
        
bNotHeld 
	lda zbFireBlip

	rts


