 ; Project 1: Keypad Input

; Constants and Utility Subroutines
DELAY EQU 3333
PORTG EQU $2200
PORTGDDR EQU $2202
OUTSTRG EQU $FFC7 ; string output Utility Subroutine
OUTA    EQU $FFB8 ; char output Utility Subroutine
Message FCC "Type a character: " ; Store Message
        FCB $04
POLLTABLE FCB $FE,$FD,$FB,$F7 ; PORTG polling values

; Variables (KEYTABLE)
KEYTABLE FCB $00,$00,$00,$00  ; first 16 bytes are the key values
         FCB $00,$00,$00,$00  ; Last 16 bytes are the ASCII
         FCB $00,$00,$00,$00
         FCB $00,$00,$00,$00
         FCB $30,$34,$38,$43
         FCB $31,$35,$39,$44
         FCB $32,$36,$41,$45
         FCB $33,$37,$42,$46

        ORG $D000
        LDS #$D500 ; Init SP
        
; For telling user to type in characters
        LDX #Message
        JSR OUTSTRG

; Main Loop
MAIN:
        JSR POLLKEYPAD ; Poll the Keypad
        LDX #KEYTABLE
        LDAB #16

CHECKKEYTABLE: ; Check KEYTABLE [0 - 15]
        LDAA 0,X
        BEQ PRINTSKIP ; Skip if position is 0
        LDAA 16,X ; Add 16 to pointer, load char
        JSR OUTA ; call Utility Subroutine
        PSHX ; We need X for printing, so Push
        LDX #Message
        JSR OUTSTRG
        PULX ; and Pull
PRINTSKIP:
        INX ; increment X to check next position
        DECB
        BNE CHECKKEYTABLE ; Loop 16 times, check all positions

       BRA MAIN ; While(true)
        
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

DELAY1:                 ; Debouce Loop
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

        SWI
        END