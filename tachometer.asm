        ORG $D500

;Init Ports/Addresses
TIC3 EQU $1014 ; PA0 Address, Input Capture Register 0
TCTL2 EQU $1021 ; Timer Control Register
TMSK1 EQU $1022 ; Timer Interrupt Mask Register
TFLG1 EQU $1023 ; Timer Interrupt Flag Register
PORTG EQU $2200 ; Port G Address
PORTGDDR EQU $2202 ; Port G DDR Address

;Init Utility Subroutines
OUTSTRG EQU $FFC7 ; string output Utility Subroutine
OUTA    EQU $FFB8 ; char output Utility Subroutine
OUTCRL  EQU $FFC4 ; output carriage return
RHLF    EQU $FFB5 ; bin to ASCII from AA

; Init Constants
DELAY EQU 3333 ; Keypad debounce
RPMMSG FCC "Average RPM: " ; Store Message
       FCB $04
POLLTABLE FCB $FE,$FD,$FB,$F7 ; PORTG polling values

; Init Variables
KEYTABLE RMB 16 ; Reserve 16 Bytes for Keypad Buttons
T2 RMB 2 ; Previous PA0 value
T1 RMB 2 ; Current PA0 value
PWIDTH RMB 2 ; Calculated Pulse Width
RPMVALUE RMB 2 ; Calculated RPM
RPMSUM RMB 2 ; Rolling RPM Sum
COUNT FCB $20 ; counter variable used in multiple places
RPMAV RMB 2 ; Calculated Average RPM
PRESSED RMB 1 ; Bool: if any key is pressed - true
PREVPRESSED RMB 1 ; Previous value of pressed (last time it was checked)


; Store JMP to interrupt handler at pseudo-vector for IC3
        ORG $00E2
        JMP  CAPTURE ; Jump to our Interrupt Handler

; Main Program Entry
        ORG $D000
        LDS #$D800 ; Init SP

;both the I bit has to be cleared and local mask bit has to be set for interrupt to occur, set up during iniitialization
IC3INIT:
        CLI ;I bit cleared
        LDAA #1
        STAA TCTL2 ; Setup to capture on rising edges
        LDAA #1
        STAA TMSK1 ; local mask bit has to be set
        LDAA #1
        STAA TFLG1 ; Clear interrupt flag (active low)

MAIN:
    JSR KEYPAD ; Set PRESSED to 1 if any key pressed
    JSR SENSOR ; Calculate RPMAV
    LDAB PREVPRESSED
    EORB #$FF
    STAB PREVPRESSED
    LDAA PRESSED
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
        JSR RPM ; Calculate RPM

        LDD RPMSUM ; Add RPM to running sum
        ADDD RPMVALUE
        STD RPMSUM
        LDAA COUNT ; Decrement Count Explicitly
        SUBA #1
        STAA COUNT
        BNE SENSOR ; Branch as long as the count has not reached 32

        LDX #32 ; When we've taken 32 sums, divide by 32 and put into RPMAV
        LDD RPMSUM
        IDIV
        STX RPMAV

        LDAA #32
        STAA COUNT ; Reset Count
        LDD #0     ; and RPMSUM
        STD RPMSUM

        RTS ; Return

; KEYPAD main subroutine
KEYPAD:

        JSR POLLKEYPAD ; Poll the keypad
        LDX #KEYTABLE
        LDAB #16
        LDAA #0
        STAA PRESSED ; Make sure Pressed is zero

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
        LDD T2
        SUBD T1 ; PWIDTH = T2 - T1
        BMI RECALC ; if T1 > T2
UPDATE:
        STD PWIDTH ; else, store to PWIDTH
        RTS
RECALC:
        LDD #$FFFF ; recalculate with PWIDTH = FFFF - T1 + T2
        SUBD T1
        ADDD T2
        BRA UPDATE ; Go back to update PWIDTH

; Calculate RPM Subroutine
RPM:
        LDD PWIDTH ; Load Delta T
        LDX #31 ; Common Factor Divide
        IDIV
        LDD #64516
        IDIV ; Result in X
        STX RPMVALUE
        RTS

; Convert Average RPM Value to ASCII and print to Buffalo Terminal (PRINT Subroutine)
PRINT:
        LDX #RPMMSG
        JSR OUTSTRG ; Print RPMMSG onto Buffalo Terminal
        LDX #1000 ; bin to decimal conversion
        LDD RPMAV
; Calculate remainder and use RHLF subroutine to output it to screen
        IDIV ; Value in X, remainder in D
        XGDX
        TBA ; Print Character
        JSR RHLF
        CLRA ; Reset A to not mess with D
        XGDX
        LDX #100 ; Reload X with 10
        IDIV
        XGDX
        TBA
        JSR RHLF
        CLRA
        XGDX
        LDX #10
        IDIV
        XGDX
        TBA
        JSR RHLF
        XGDX
        TBA
        JSR RHLF
        RTS ; Return

; Convert RPM SUM Value to ASCII and print to Buffalo Terminal (PRINT Subroutine)
PRINTSUM:
        LDX #RPMMSG
        JSR OUTSTRG ; Print RPMMSG onto Buffalo Terminal
        LDX #10000 ; bin to decimal conversion
        LDD RPMSUM
; Calculate remainder and use RHLF subroutine to output it to screen
        IDIV ; Value in X, remainder in D
        XGDX
        TBA ; Print Character
        JSR RHLF
        CLRA ; Reset A to not mess with D
        XGDX
        LDX #1000 ; Reload X with 10
        IDIV
        XGDX
        TBA
        JSR RHLF
        CLRA
        XGDX
        LDX #100
        IDIV
        XGDX
        TBA
        JSR RHLF
        CLRA
        XGDX
        LDX #10
        IDIV
        XGDX
        TBA
        JSR RHLF
        XGDX
        TBA
        JSR RHLF
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
        LDAA #0        ; Set value in KEYTABLE to 0 by default
        STAA 0,Y
        LDAA #$10  ; Bit Mask 0b00010000
        ANDA PORTG ; Check first Row Bit
        BNE SKIP1  ; Skip if input is non-zero (no press) yu
        INC 0,Y         ; increment button value in KEYTABLE
        LDX #DELAY      ; Setup DELAY for debounce
; Debouce Loop
DELAY1:
       DEX
       BNE DELAY1
SKIP1:
       INY        ; Move KEYTABLE pointer to next row
       LDAA #0
       STAA 0,Y
       LDAA #$20  ; Bit Mask 0b00100000
        ANDA PORTG ; Check first Row Bit
        BNE SKIP2  ; Skip if input is non-zero (no press)
       INC 0,Y
       LDX #DELAY

DELAY2:
       DEX
       BNE DELAY2

SKIP2:
       INY
       LDAA #0
       STAA 0,Y
       LDAA #$40 ; Bit Mask 0b01000000
        ANDA PORTG ; Check first Row Bit
        BNE SKIP3  ; Skip if input is non-zero (no press)
       INC 0,Y
       LDX #DELAY

DELAY3:
       DEX
       BNE DELAY3

SKIP3:
       INY
       LDAA #0
       STAA 0,Y
       LDAA #$80 ; Bit Mask 0b10000000
        ANDA PORTG ; Check first Row Bit
        BNE SKIP4  ; Skip if input is non-zero (no press)
       INC 0,Y
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
        LDD T2 ; Update T1
        STD T1
        LDD TIC3 ; Load to X for setting T1
        STD T2
        JSR CALCPWIDTH ; Calculate PWIDTH
        LDAA #1 ; Clear interrupt flag (active low)
        STAA TFLG1
        RTI ; Return