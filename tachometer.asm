;Init Ports/Addresses
PORTA0 EQU $1014 ; PA0 Address, Input Capture Register 0
TCTL2 EQU $1021 ; Timer Control Register
TMSK1 EQU $1022 ; Timer Interrupt Mask Register
TFLG1 EQU $1023 ; Timer Interrupt Flag Register
PORTG EQU $2200 ; Port G Address 
PORTGDDR EQU $2202 ; Port G DDR Address

;Init Utility Subroutines
OUTSTRG EQU $FFC7 ; string output Utility Subroutine
OUTA    EQU $FFB8 ; char output Utility Subroutine

; Init Constants
DELAY EQU 3333 ; Keypad debounce
RPMCOUNT EQU 32 ; RPM Sum Count (used for sum loop and average)
NUMBERS FCB $30,$31,$32,$33,$34,$35,$36,$37,$38,$39 ; 0-9 ASCII Representation
RPMMSG FCC "Average RPM: " ; Store Message
       FCB $04
POLLTABLE FCB $FE,$FD,$FB,$F7 ; PORTG polling values
KEYTABLE FCB $00,$00,$00,$00  ; first 16 bytes are the key values
         FCB $00,$00,$00,$00  
         FCB $00,$00,$00,$00
         FCB $00,$00,$00,$00


; Init Variables
T2 FCB $00,$00 ; Previous PA0 value
T1 FCB $00,$00 ; Current PA0 value
PWIDTH FCB $00,$00 ; Calculated Pulse Width
RPMVALUE FCB $00,$00 ; Calculated RPM
RPMSUM FCB $00,$00 ; Rolling RPM Sum
COUNT FCB $00 ; counter variable used in multiple places
RPMAV FCB $00,$00 ; Calculated Average RPM
PRESSED FCB $00 ; Bool: if any key is pressed - true
PREVPRESSED FCB $00 ; Previous value of pressed (last time it was checked)


; Store JMP to interrupt handler at pseudo-vector for IC3
	ORG $00E2
	JMP  CAPTURE ; Jump to our Interrupt Handler

; Main Program Entry
        ORG $D000
        LDS #$D500 ; Init SP

;both the I bit has to be cleared and local mask bit has to be set for interrupt to occur, set up during iniitialization
IC3INIT:
	CLI ;I bit cleared
	LDAA #1 ;local mask bit has to be set
	STAA TMSK1
    LDAA #1 ; Clear interrupt flag (active low)
    STAA TFLG1

MAIN:
    JSR SENSOR ; Calculate RPMAV
    JSR KEYPAD ; Set PRESSED to 1 if any key pressed

    LDAA PRESSED ; if (pressed && !prevpressed)
    LDAB PREVPRESSED 
    EORB #$FF
    STAB PREVPRESSED
    ANDA PREVPRESSED
    BEQ RPMSKIP ; branch if A is zero (condition failed)
    JSR PRINT ; Print AVRPM to screen
RPMSKIP:
    LDAA PRESSED ; after JSR, need to reload PRESSED
    STAA PREVPRESSED ; Update PREVPRESSED

    BRA MAIN ; While(1)

; Main Subroutines

; SENSOR main subroutine
SENSOR:
        WAI ; Wait for next Interrupt Signal
        JSR CALCPWIDTH ; Calculate PWIDTH
        JSR RPM ; Calculate RPM
        
        LDD RPMSUM ; Add RPM to running sum
        ADDD RPMVALUE
        STD RPMSUM
        INC COUNT
        LDAB RPMCOUNT
        CMPB COUNT
        BNE SENSOR ; Branch as long as the count has not reached 32

        LDX RPMCOUNT ; When we've taken 32 sums, divide by 32 and put into RPMAV
        LDD RPMSUM
        IDIV
        STX RPMAV

        CLR COUNT ; Reset COUNT variable to zero

        RTS ; Return

; KEYPAD main subroutine
KEYPAD: 

        JSR POLLKEYPAD ; Poll the keypad
        LDX #KEYTABLE
        LDAB #16
        CLR PRESSED ; Make sure Pressed is zero

; Check KEYTABLE [0 - 15]
CHECKKEYTABLE:
        LDAA 0,X
        BEQ PRINTSKIP ; Skip if position is 0
        LDAA #1
        STAA PRESSED

PRINTSKIP:
        INX ; increment X to check next position
        DECB
        BNE CHECKKEYTABLE

        RTS ; Return

; Helper Subroutines

; Calculate PWIDTH Subroutine
CALCPWIDTH: 
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
        LDD PWIDTH ; Load Delta T
        LDX #32 ; Common Factor Divide
        IDIV
        LDD #62500
        IDIV ; Result in X
        STX RPMVALUE
        RTS

; Convert Average RPM Value to ASCII and print to Buffalo Terminal (PRINT Subroutine)
PRINT:
        LDX #RPMMSG
        JSR OUTSTRG ; Print RPMMSG onto Buffalo Terminal
        LDX #10 ; bin to decimal conversion
        LDD RPMAV
; Calculate remainder and push it's ASCII to the stack
REMAINDER:
        LDY NUMBERS
        IDIV ; Value in X, remainder in D
        ABY ; Move to Correct ASCII Character
        LDAB 0,Y ; Load ASCII Character
        PSHB ; Push the ASCII to the Stack
        INC COUNT ; Increment Character Count
        XGDX
        CPD #0
        BNE REMAINDER
; Display ASCII from stack
DISPLAY:
        PULA
        JSR OUTA ; Print Character
        DEC COUNT
        BNE DISPLAY
        CLR COUNT ; Reset COUNT variable to zero

        RTS ; Return

; POLL KEYPAD SUBROUTINE
POLLKEYPAD:
        LDAA #$0F   ;SET PORT G
        STAA PORTGDDR ;FOR I/O
        LDAB #4
        LDX #POLLTABLE ; Load POLLTABlE and KEYTABLE pointers
        LDY #KEYTABLE
COLUMN:
        LDAA 0,X       ; Turn off correct column to poll
        STAA PORTG
        PSHX           ; Save POLLTABLE pointer, Need X
ROW:
        LDAA #$10       ; Bit Mask 0b00010000
        ANDA PORTG      ; Check first Row Bit
        LSRA            ; Shift the bit to b0
        LSRA
        LSRA
        LSRA
        EORA #$FF       ; Flip A (0 is pressed normally, we want 1 to be pressed)
        CMPA 0,Y        ; compare A with KEYTABLE
        BEQ SKIP1       ; Skip if input is same as KEYTABLE
        STAA 0,Y        ; Store A to KEYTABLE
        LDX #DELAY      ; Setup DELAY for debounce

DELAY1:
       DEX
       BNE DELAY1
SKIP1:
       INY        ; Move KEYTABLE pointer to next row
       LDAA #$20  ; Bit Mask 0b00100000
       ANDA PORTG ; Check first Row Bit
       LSRA       ; Shift the bit to b0
       LSRA
       LSRA
       LSRA
       LSRA
       EORA #$FF       ; Flip A (0 is pressed normally, we want 1 to be pressed)
       CMPA 0,Y        ; compare A with KEYTABLE
       BEQ SKIP2       ; Skip if input is non-zero (no press)
       STAA 0,Y        ; Store A to KEYTABLE
       LDX #DELAY

DELAY2:
       DEX
       BNE DELAY2

SKIP2:
       INY
       LDAA #$40 ; Bit Mask 0b01000000
       ANDA PORTG ; Check first Row Bit
       LSRA       ; Shift the bit to b0
       LSRA
       LSRA
       LSRA
       LSRA
       LSRA
       EORA #$FF       ; Flip A (0 is pressed normally, we want 1 to be pressed)
       CMPA 0,Y        ; compare A with KEYTABLE              
       BEQ SKIP3  ; Skip if input is non-zero (no press)
       STAA 0,Y
       LDX #DELAY

DELAY3:
       DEX
       BNE DELAY3

SKIP3:
       INY
       LDAA #$80 ; Bit Mask 0b10000000
       ANDA PORTG ; Check first Row Bit
       LSRA       ; Shift the bit to b0
       LSRA
       LSRA
       LSRA
       LSRA
       LSRA
       LSRA
       EORA #$FF       ; Flip A (0 is pressed normally, we want 1 to be pressed)
       CMPA 0,Y        ; compare A with KEYTABLE       
       BEQ SKIP4  ; Skip if input is non-zero (no press)
       STAA 0,Y
       LDX #DELAY

DELAY4:
       DEX
       BNE DELAY4
       
SKIP4:
        INY ; increment Y, setup KEYTABLE pointer
            ; for next loop iteration

        PULX
        INX
        DECB
        BNE COLUMN
        RTS
; END POLL KEYPAD SUBROUTINE


; Interupt Handler, Simply Capture T1
CAPTURE:
        LDD PORTA0 ; Load to X for setting T1
        STD T1
        LDAA #1 ; Clear interrupt flag (active low)
        STAA TFLG1
        RTI ; Return