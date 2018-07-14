;===============================================================================
;       INPUT MACROS - MADS syntax
;===============================================================================

;===============================================================================
; MACROS
;===============================================================================
; mInput_GetHeld ; (buttonMask)
; mInput_GetFirePressed
;
;===============================================================================

;==============================================================================
; Data declarations and subroutine library code
; performing game controller input.

; The Atari OS solves much of the nitty-gritty providing considerable
; support for polling controllers.  The OS verical blank routine 
; conveniently separates joystick and trigger values into individual 
; shadow variables.

;===============================================================================
; Constants

 ; use joystick 2, change to CIAPRB for joystick 1
 
JOYSTICKREGISTER  = STICK0  ; Atari use first stick.
TRIGGERREGISTER   = STRIG0

GAMEPORTUPMASK    = %00000001
GAMPORTDOWNMASK   = %00000010
GAMEPORTLEFTMASK  = %00000100
GAMEPORTRIGHTMASK = %00001000
GAMEPORTFIREMASK  = %00010001 ; Note the 16 bit is kept to keep it unique.
FIREDELAYMAX      = 30


;===============================================================================
; Macros/Subroutines

;-------------------------------------------------------------------------------
																mInput_GetHeld 
;-------------------------------------------------------------------------------

.macro mInput_GetHeld buttonMask 
	.if :buttonMask=GAMEPORTFIREMASK
		lda vbTriggerThisFrame
		and #1
	.else
		lda vbGameportThisFrame
		and #:buttonMask
	.endif
.endm  ; test with bne on return


;-------------------------------------------------------------------------------
														mInput_GetFirePressed
;-------------------------------------------------------------------------------
; As a macro this was a lot of code to drop in mainline 
; during assembly and there seems to be no arguments.
; So...?  It looks like this should be a library function,
; so this has moved to the libInput file.
; 
; As a macro wrapping a library function there's not 
; much going on here.  Unless I find a variable purpose,
; then this will  be dropped from the macros.

.macro mInput_GetFirePresed

	jsr libInput_GetFirePresed

.endm ; test with bne on return
