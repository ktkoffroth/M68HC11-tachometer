;Init variables
PORTA0 EQU $1014 ; PA0 Address, Input Capture Register 0
TCTL2 EQU $1021 ; Timer Control Register
TMSK1 EQU $1022 ; Timer Interrupt Mask Register
TFLG1 EQU $1023 ; Timer Interrupt Flag Register
T2 FCB $00, $00 ; Previous PA0 value
T1 FCB $00, $00 ; Current PA0 value
PWIDTH FCB $00, $00 ; Calculated Pulse Width

; Store JMP to interrupt handler at pseudo-vector for IC3
	ORG $00E2
	JMP  CAPTURE ; Jump to our Interrupt Handler

; Main Program Entry
    ORG $D000

;both the I bit has to be cleared and local mask bit has to be set for interrupt to occur, set up during iniitialization
IC3INIT:
	CLI ;I bit cleared
	LDAA #1
	STAA TMSK1 ;local mask bit has to be set

MAIN:
    JSR SENSOR; Calculate RPM

    BRA ; While(true)

; Main Subroutines

; SENSOR main subroutine
SENSOR:
        WAI ; Wait for next Interrupt Signal
        JSR PWIDTH ; Calculate PWIDTH

        RTS ; 

; KEYPAD main subroutine
KEYPAD: 



; Helper Subroutines

; Calculate PWIDTH Subroutine
PWIDTH: 
        LDD T1
        SUBD T2 ; PWIDTH = T1 - T2
	    BMI RECALC ; if T2 > T1
UPDATE:
	    STD PWIDTH ; else, store to PWIDTH
        LDX T1 ; and update T2
	    STX T2
        RTS ; 
RECALC:
	    LDD #$FFFF ; recalculate with PWIDTH = FFFF - T2 + T1
        SUBD T2
        ADDD T1
        BRA UPDATE ; Go back to update PWIDTH and T2

; Calculate RPM Subroutine
RPM: 
    

; Interupt Handler, Simply Capture T1
CAPTURE:
        LDD PORTA0 ; Load to X for setting T1
        STD T1
        LDAA #1 ; Clear interrupt flag (active low)
        STAA TFLG1
        RTI ; Return