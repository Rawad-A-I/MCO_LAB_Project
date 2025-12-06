;**************************************************************
;* Freescale HC12 Elevator System (Final Version – Red/Buzzer Linked)
;**************************************************************

       XDEF Entry, _Startup
       ABSENTRY Entry

       INCLUDE 'derivative.inc'

ROMStart   EQU   $4000

;==============================
; RAM VARIABLES
;==============================
       ORG RAMStart

Current     DS.B 1
Target      DS.B 1
State       DS.B 1
ADCValue    DS.B 1
Overload    DS.B 1
Request0    DS.B 1
Request1    DS.B 1
Request2    DS.B 1
BlinkCount  DS.B 1

;==============================================================
; CODE SECTION
;==============================================================
       ORG ROMStart

Entry:
_Startup:
       LDS   #RAMEnd+1
       CLI

;--------------------------------
; Initialize Internal Variables
;--------------------------------
       CLR   Current
       MOVB  #3, Target
       CLR   State
       CLR   Overload
       CLR   Request0
       CLR   Request1
       CLR   Request2

;--------------------------------
; I/O PORT INITIALIZATION
;--------------------------------
       MOVB  #$00, DDRA
       MOVB  #$02, PUCR
       MOVB  #%11100000, DDRT
       MOVB  #%00000000, PTT

;--------------------------------
; Initialize Buzzer PWM
;--------------------------------
       JSR init_PWM_Buzzer

;--------------------------------
; ADC INIT
;--------------------------------
       MOVB  #%11000000, ATD0CTL2
       JSR   DelayADC
       MOVB  #%00001000, ATD0CTL3
       MOVB  #%10000101, ATD0CTL4

;--------------------------------
; MODULUS COUNTER SETUP
;--------------------------------
       MOVB  #%11000111, MCCTL
       MOVW  #6250, MCCNT

;--------------------------------
; LCD SPI CONFIG
;--------------------------------
       MOVB  #$10, MODRR
       MOVB  #$38, DDRM
       MOVB  #$52, SPI0CR1
       MOVB  #$10, SPI0CR2
       MOVB  #$00, SPI0BR

;--------------------------------
; LCD INIT COMMANDS
;--------------------------------
       LDAA  #%00110011
       JSR   SENDINST
       LDAA  #%00110010
       JSR   SENDINST
       LDAA  #%00101000
       JSR   SENDINST
       LDAA  #%00001000
       JSR   SENDINST
       LDAA  #%00000001
       JSR   SENDINST
       LDAA  #%00000110
       JSR   SENDINST
       LDAA  #%00001110
       JSR   SENDINST

; Display F0
       LDAA  #'F'
       JSR   SENDDATA
       LDAA  Current
       ADDA  #'0'
       JSR   SENDDATA

;=========================================================
; MAIN LOOP
;=========================================================
MainLoop:
       LDAA  Overload
       BNE   OverloadWait

       LDAA  Target
       CMPA  #3
       BEQ   MainLoop

       LDAB  Current
       CBA
       BEQ   ClearTarget
       BHI   MOVEUP
       JMP   MOVEDOWN

ClearTarget:
       MOVB  #3, Target
       BRA   MainLoop

;=========================================================
; OVERLOAD HANDLING  (RED LED + BUZZER TOGETHER)
;=========================================================
OverloadWait:

       ; Show OVERLOAD message
       LDAA  #%00000001
       JSR   SENDINST
       JSR   DELAY

       LDAA  #'O'
       JSR   SENDDATA
       LDAA  #'V'
       JSR   SENDDATA
       LDAA  #'E'
       JSR   SENDDATA
       LDAA  #'R'
       JSR   SENDDATA
       LDAA  #'L'
       JSR   SENDDATA
       LDAA  #'O'
       JSR   SENDDATA
       LDAA  #'A'
       JSR   SENDDATA
       LDAA  #'D'
       JSR   SENDDATA

       ; Blink RED LED and sync buzzer with it
       BSET  PTT, #%00100000   ; Red ON
       JSR   Buzz              ; Buzzer ON with red

       JSR   DELAY
       JSR   DELAY

       BCLR  PTT, #%00100000   ; Red OFF
       JSR   StopBuzz          ; Buzzer OFF with red

       JSR   DELAY
       JSR   DELAY

       ; Check again if still overloaded
       LDAA  Overload
       BNE   OverloadWait

       ; Clear done in WeightOK, but be safe
       JSR   StopBuzz
       BCLR  PTT, #%00100000

       LDAA  #%00000001
       JSR   SENDINST
       JSR   DELAY

       LDAA  #'F'
       JSR   SENDDATA
       LDAA  Current
       ADDA  #'0'
       JSR   SENDDATA

       LBRA  MainLoop

;=========================================================
; MOVING UP  (LONG BEEP BEFORE, NO BUZZ WHILE MOVING)
;=========================================================
MOVEUP:
       MOVB  #1, State

       ; Long door closing beep BEFORE LCD message
       JSR   DoorCloseBeep    ; ~Option C (longer beep)

       ; Then display MOVING UP
       LDAA  #%00000001
       JSR   SENDINST
       JSR   DELAY

       LDAA  #'M'
       JSR   SENDDATA
       LDAA  #'O'
       JSR   SENDDATA
       LDAA  #'V'
       JSR   SENDDATA
       LDAA  #'I'
       JSR   SENDDATA
       LDAA  #'N'
       JSR   SENDDATA
       LDAA  #'G'
       JSR   SENDDATA
       LDAA  #%11000000
       JSR   SENDINST
       LDAA  #'U'
       JSR   SENDDATA
       LDAA  #'P'
       JSR   SENDDATA
       LDAA  #':'
       JSR   SENDDATA

       MOVB  #10, BlinkCount

UpLoop:
       BCLR  PTT, #%10000000
       JSR   DELAY
       JSR   DELAY
       BSET  PTT, #%10000000
       JSR   DELAY
       JSR   DELAY

       DEC   BlinkCount
       LDAA  BlinkCount
       BNE   UpLoop

       INC   Current

       LDAA  Target
       LDAB  Current
       CBA
       LBEQ  ARRIVED

       MOVB  #10, BlinkCount
       BRA   UpLoop

;=========================================================
; MOVING DOWN  (LONG BEEP BEFORE, NO BUZZ WHILE MOVING)
;=========================================================
MOVEDOWN:
       MOVB  #2, State

       ; Long door closing beep BEFORE LCD message
       JSR   DoorCloseBeep

       ; Display MOVING DOWN
       LDAA  #%00000001
       JSR   SENDINST
       JSR   DELAY

       LDAA  #'M'
       JSR   SENDDATA
       LDAA  #'O'
       JSR   SENDDATA
       LDAA  #'V'
       JSR   SENDDATA
       LDAA  #'I'
       JSR   SENDDATA
       LDAA  #'N'
       JSR   SENDDATA
       LDAA  #'G'
       JSR   SENDDATA

       LDAA  #%11000000
       JSR   SENDINST

       LDAA  #'D'
       JSR   SENDDATA
       LDAA  #'O'
       JSR   SENDDATA
       LDAA  #'W'
       JSR   SENDDATA
       LDAA  #'N'
       JSR   SENDDATA
       LDAA  #':'
       JSR   SENDDATA

       MOVB  #10, BlinkCount

DownLoop:
       BCLR  PTT, #%01000000
       JSR   DELAY
       JSR   DELAY
       BSET  PTT, #%01000000
       JSR   DELAY
       JSR   DELAY

       DEC   BlinkCount
       LDAA  BlinkCount
       BNE   DownLoop

       DEC   Current

       LDAA  Target
       LDAB  Current
       CBA
       BEQ   ARRIVED

       MOVB  #10, BlinkCount
       BRA   DownLoop

;=========================================================
; ARRIVED — RED LED + BUZZER LOCKED TOGETHER
;=========================================================
ARRIVED:
       ; Turn off movement LEDs
       BCLR  PTT, #%11000000   ; clear green & yellow

       ; Turn ON red LED and buzzer immediately together
       BSET  PTT, #%00100000
       JSR   Buzz

       ; Door-open wait (red + buzzer ON)
       LDAB  #20
ArrDoorDelay:
       JSR   DELAY
       DECB
       BNE   ArrDoorDelay

       ; Update LCD with current floor while red/buzzer still ON (optional)
       LDAA  #%00000001
       JSR   SENDINST
       JSR   DELAY

       LDAA  #'F'
       JSR   SENDDATA
       LDAA  Current
       ADDA  #'0'
       JSR   SENDDATA

       ; Clear request for this floor
       LDAA  Current
       BEQ   ClearReq0
       CMPA  #1
       BEQ   ClearReq1
       CLR   Request2
       BRA   ArrDone

ClearReq0:
       CLR   Request0
       BRA   ArrDone

ClearReq1:
       CLR   Request1

ArrDone:
       MOVB  #3, Target
       CLR   State

       ; Red LED + buzzer OFF together when done
       BCLR  PTT, #%00100000
       JSR   StopBuzz

       JMP   MainLoop

;=========================================================
; INTERRUPT SERVICE ROUTINE
;=========================================================
MCCNT_ISR:
       MOVB  #$80, MCFLG
       MOVW  #6250, MCCNT

       MOVB  #%10100101, ATD0CTL5

WaitADC:
       BRCLR ATD0STAT0, #$80, WaitADC
       LDAA  ATD0DR0L
       STAA  ADCValue

       CMPA  #125
       BLS   WeightOK

       MOVB  #1, Overload
       MOVB  #3, State
       BCLR  PTT, #%11000000
       ; Overload logic handled in main loop (OverloadWait)
       RTI

WeightOK:
       CLR   Overload
       LDAA  State
       CMPA  #3
       BNE   NotRecovering

       ; Recovering from overload: turn red & buzzer OFF
       BCLR  PTT, #%00100000
       JSR   StopBuzz
       CLR   State

NotRecovering:
       ; Check if any buttons pressed at all
       LDAA  PORTA
       COMA
       ANDA  #%11111100
       BEQ   NoButtons

; -------------------------
; Button Decode (Correct Syntax, mapping unchanged)
; -------------------------

; PB4  (bit 2) ? Request0
       LDAA  PORTA
       COMA
       ANDA  #%00000100
       BEQ   PB4_Done
       MOVB  #1, Request0
PB4_Done:

; PB5  (bit 3) ? Request1
       LDAA  PORTA
       COMA
       ANDA  #%00001000
       BEQ   PB5_Done
       MOVB  #1, Request1
PB5_Done:

; PB6  (bit 4) ? Request2
       LDAA  PORTA
       COMA
       ANDA  #%00010000
       BEQ   PB6_Done
       MOVB  #1, Request2
PB6_Done:

; PB7  (bit 5) ? Request0
       LDAA  PORTA
       COMA
       ANDA  #%00100000
       BEQ   PB7_Done
       MOVB  #1, Request0
PB7_Done:

; PB8  (bit 6) ? Request1
       LDAA  PORTA
       COMA
       ANDA  #%01000000
       BEQ   PB8_Done
       MOVB  #1, Request1
PB8_Done:

; PB9  (bit 7) ? Request2
       LDAA  PORTA
       COMA
       ANDA  #%10000000
       BEQ   NoButtons
       MOVB  #1, Request2

NoButtons:
       LDAA  Target
       CMPA  #3
       BNE   ISR_Done

       LDAA  Current
       BEQ   FromF0
       CMPA  #1
       BEQ   FromF1
       BRA   FromF2

FromF0:
       LDAA  Request1
       BEQ   F0_F2
       MOVB  #1, Target
       BRA   ISR_Done

F0_F2:
       LDAA  Request2
       BEQ   ISR_Done
       MOVB  #2, Target
       BRA   ISR_Done

FromF1:
       LDAA  Request0
       BEQ   F1_Up
       LDAB  Request2
       BEQ   ServeF0
       MOVB  #0, Target
       BRA   ISR_Done

ServeF0:
       MOVB  #0, Target
       BRA   ISR_Done

F1_Up:
       LDAA  Request2
       BEQ   ISR_Done
       MOVB  #2, Target
       BRA   ISR_Done

FromF2:
       LDAA  Request1
       BEQ   F2_F0
       MOVB  #1, Target
       BRA   ISR_Done

F2_F0:
       LDAA  Request0
       BEQ   ISR_Done
       MOVB  #0, Target

ISR_Done:
       RTI

;=========================================================
; SUBROUTINES
;=========================================================

;---------------------------------------
; PWM BUZZER INITIALIZATION
;---------------------------------------
init_PWM_Buzzer:
       BSET   DDRP, #$10
       BCLR   PTP,  #$10

       BCLR   PWME,   #$10
       BSET   PWMPOL, #$10
       BCLR   PWMCLK, #$10

       MOVB   #$03, PWMPRCLK
       MOVB   #$00, PWMCTL

       CLR    PWMCNT4
       MOVB   #250, PWMPER4
       MOVB   #125, PWMDTY4

       RTS

;---------------------------------------
; ENABLE BUZZER
;---------------------------------------
Buzz:
       BSET  PWME, #$10
       RTS

;---------------------------------------
; DISABLE BUZZER
;---------------------------------------
StopBuzz:
       BCLR  PWME, #$10
       RTS

;---------------------------------------
; LONG DOOR-CLOSING BEEP (~Option C)
;---------------------------------------
DoorCloseBeep:
       JSR   Buzz
       LDAB  #20           ; increase for even longer beep if needed
DCB_Loop:
       JSR   DELAY
       DECB
       BNE   DCB_Loop
       JSR   StopBuzz
       RTS

;---------------------------------------
; LCD/SPI ROUTINES
;---------------------------------------
SENDINST:
       TAB
       RORA
       RORA
       RORA
       RORA
       ORAA  #%10000000
       ANDA  #%10001111
       JSR   SENDSPI
       ANDA  #%00001111
       JSR   SENDSPI
       JSR   DELAY

       TBA
       ORAA  #%10000000
       ANDA  #%10001111
       JSR   SENDSPI
       ANDA  #%00001111
       JSR   SENDSPI
       JSR   DELAY
       RTS

SENDDATA:
       TAB
       RORA
       RORA
       RORA
       RORA
       ORAA  #%11000000
       ANDA  #%11001111
       JSR   SENDSPI
       ANDA  #%01001111
       JSR   SENDSPI
       JSR   DELAY

       TBA
       ORAA  #%11000000
       ANDA  #%11001111
       JSR   SENDSPI
       ANDA  #%01001111
       JSR   SENDSPI
       JSR   DELAY
       RTS

SENDSPI:
       BRCLR SPI0SR, #$20, *
       STAA  SPI0DR
       RTS

DELAY:
       LDX   #10000
D1:
       PSHB
       PULB
       PSHB
       PULB
       PSHB
       PULB
       DEX
       BNE   D1
       RTS

DelayADC:
       LDX   #5000
D2:
       DEX
       BNE   D2
       RTS

;=========================================================
; INTERRUPT VECTORS
;=========================================================
       ORG   $FFFE
       DC.W  Entry

       ORG   $FFCA
       DC.W  MCCNT_ISR