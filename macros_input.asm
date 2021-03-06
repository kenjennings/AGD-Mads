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

JOYSTICKREGISTER  = STICK0  ; From PIA.asm.  Atari uses first joystick.
TRIGGERREGISTER   = STRIG0  ; From GTIA.asm. Really. Trigger is not in PIA.

GAMEPORTUPMASK    = STICK_UP ; Values from PIA.asm for joystick directions.
GAMPORTDOWNMASK   = STICK_DOWN
GAMEPORTLEFTMASK  = STICK_LEFT
GAMEPORTRIGHTMASK = STICK_RIGHT
GAMEPORTFIREMASK  = %00010001 ; Note the 16 value bit included to keep this unique.
FIREDELAYMAX      = 30


;===============================================================================
; Macros/Subroutines

;-------------------------------------------------------------------------------
																mInput_GetHeld
;-------------------------------------------------------------------------------

.macro mInput_GetHeld buttonMask
	.if :buttonMask=GAMEPORTFIREMASK ; bit in 16 value set to make this special.
		lda zbTriggerThisFrame
		and #1
	.else
		lda zbGameportThisFrame
		and #:buttonMask
	.endif
.endm  ; test with bne on return


;-------------------------------------------------------------------------------
														mInput_GetFirePressed
;-------------------------------------------------------------------------------
; The original macro this was a lot of code to drop
; in mainline repeatedly during assembly and there
; seems to be no arguments.
; So...?  It looks like this should be a library function,
; so this has moved to the libInput file.
;
; As a macro wrapping a library function there's not
; much going on here.  Unless I find a variable purpose,
; then this will  be dropped from the macros.

.macro mInput_GetFirePresed

	jsr libInput_GetFirePresed

.endm ; test with bne on return

