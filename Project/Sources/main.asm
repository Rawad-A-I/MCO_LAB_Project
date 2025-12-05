;**************************************************************
;* Freescale HC12 Elevator System (Clean + Fixed PWM Version)
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
       LDAA #'F'
       JSR SENDDATA
       LDAA Current
       ADDA #'0'
       JSR SENDDATA

;=========================================================
; MAIN LOOP
;=========================================================
MainLoop:
       LDAA Overload
       BNE  OverloadWait

       LDAA Target
       CMPA #3
       BEQ MainLoop

       LDAB Current
       CBA
       BEQ ClearTarget
       BHI MOVEUP
       JMP MOVEDOWN

ClearTarget:
       MOVB #3, Target
       BRA MainLoop

;=========================================================
; OVERLOAD HANDLING
;=========================================================
OverloadWait:
       JSR Buzz

       LDAA #%00000001
       JSR SENDINST
       JSR DELAY

       ; Print OVERLOAD
       LDAA #'O' : JSR SENDDATA
       LDAA #'V' : JSR SENDDATA
       LDAA #'E' : JSR SENDDATA
       LDAA #'R' : JSR SENDDATA
       LDAA #'L' : JSR SENDDATA
       LDAA #'O' : JSR SENDDATA
       LDAA #'A' : JSR SENDDATA
       LDAA #'D' : JSR SENDDATA

       BSET PTT, #%00100000
       JSR DELAY
       JSR DELAY
       BCLR PTT, #%00100000
       JSR DELAY
       JSR DELAY

       LDAA Overload
       BNE OverloadWait

       JSR StopBuzz

       LDAA #%00000001
       JSR SENDINST
       JSR DELAY

       LDAA #'F'
       JSR SENDDATA
       LDAA Current
       ADDA #'0'
       JSR SENDDATA

       BRA MainLoop

;=========================================================
; MOVING UP
;=========================================================
MOVEUP:
       MOVB #1, State

       LDAA #%00000001
       JSR SENDINST
       JSR DELAY

       ; MOVING UP
       LDAA #'M' : JSR SENDDATA
       LDAA #'O' : JSR SENDDATA
       LDAA #'V' : JSR SENDDATA
       LDAA #'I' : JSR SENDDATA
       LDAA #'N' : JSR SENDDATA
       LDAA #'G' : JSR SENDDATA
       LDAA #%11000000 : JSR SENDINST
       LDAA #'U' : JSR SENDDATA
       LDAA #'P' : JSR SENDDATA
       LDAA #':' : JSR SENDDATA

       JSR Buzz

       MOVB #10, BlinkCount

UpLoop:
       BCLR PTT, #%10000000
       JSR DELAY
       JSR DELAY
       BSET PTT, #%10000000
       JSR DELAY
       JSR DELAY

       DEC BlinkCount
       LDAA BlinkCount
       BNE UpLoop

       INC Current

       LDAA Target
       LDAB Current
       CBA
       LBEQ ARRIVED

       MOVB #10, BlinkCount
       BRA UpLoop

;=========================================================
; MOVING DOWN
;=========================================================
MOVEDOWN:
       MOVB #2, State

       LDAA #%00000001
       JSR SENDINST
       JSR DELAY

       ; MOVING DOWN
       LDAA #'M' : JSR SENDDATA
       LDAA #'O' : JSR SENDDATA
       LDAA #'V' : JSR SENDDATA
       LDAA #'I' : JSR SENDDATA
       LDAA #'N' : JSR SENDDATA
       LDAA #'G' : JSR SENDDATA
       LDAA #%11000000 : JSR SENDINST
       LDAA #'D' : JSR SENDDATA
       LDAA #'O' : JSR SENDDATA
       LDAA #'W' : JSR SENDDATA
       LDAA #'N' : JSR SENDDATA
       LDAA #':' : JSR SENDDATA

       MOVB #10, BlinkCount

DownLoop:
       BCLR PTT, #%01000000
       JSR DELAY
       JSR DELAY
       BSET PTT, #%01000000
       JSR DELAY
       JSR DELAY

       DEC BlinkCount
       LDAA BlinkCount
       BNE DownLoop

       DEC Current

       LDAA Target
       LDAB Current
       CBA
       BEQ ARRIVED

       MOVB #10, BlinkCount
       BRA DownLoop

;=========================================================
; ARRIVED AT FLOOR
;=========================================================
ARRIVED:
       BCLR PTT, #%11000000
       JSR StopBuzz
       BSET PTT, #%00100000

       LDAB #20
BuzzDelay:
       JSR DELAY
       DECB
       BNE BuzzDelay

       BSET PTT, #%00100000

       LDAA #%00000001
       JSR SENDINST
       JSR DELAY

       LDAA #'F'
       JSR SENDDATA
       LDAA Current
       ADDA #'0'
       JSR SENDDATA

       ; Clear request
       LDAA Current
       BEQ ClearReq0
       CMPA #1
       BEQ ClearReq1
       CLR Request2
       BRA ArrDone
ClearReq0:
       CLR Request0
       BRA ArrDone
ClearReq1:
       CLR Request1

ArrDone:
       MOVB #3, Target
       CLR State

       LDAB #10
ArrWait:
       JSR DELAY
       DECB
       BNE ArrWait

       BCLR PTT, #%00100000
       JMP MainLoop

;=========================================================
; INTERRUPT SERVICE ROUTINE
;=========================================================
MCCNT_ISR:
       MOVB #$80, MCFLG
       MOVW #6250, MCCNT

       MOVB #%10100101, ATD0CTL5

WaitADC:
       BRCLR ATD0STAT0, #$80, WaitADC
       LDAA ATD0DR0L
       STAA ADCValue

       CMPA #125
       BLS WeightOK

       MOVB #1, Overload
       MOVB #3, State
       BCLR PTT, #%11000000
       JSR Buzz
       RTI

WeightOK:
       CLR Overload
       LDAA State
       CMPA #3
       BNE NotRecovering

       BCLR PTT, #%00100000
       JSR StopBuzz
       CLR State

NotRecovering:
       LDAA PORTA
       COMA
       ANDA #%11111100
       BEQ NoButtons

       ; Button decode
       LDAA PORTA : COMA : ANDA #%00000100 : BEQ PB4 : MOVB #1,Request0
PB4:
       LDAA PORTA : COMA : ANDA #%00001000 : BEQ PB5 : MOVB #1,Request1
PB5:
       LDAA PORTA : COMA : ANDA #%00010000 : BEQ PB6 : MOVB #1,Request2
PB6:
       LDAA PORTA : COMA : ANDA #%00100000 : BEQ PB7 : MOVB #1,Request0
PB7:
       LDAA PORTA : COMA : ANDA #%01000000 : BEQ PB8 : MOVB #1,Request1
PB8:
       LDAA PORTA : COMA : ANDA #%10000000 : BEQ NoButtons : MOVB #1,Request2

NoButtons:
       LDAA Target
       CMPA #3
       BNE ISR_Done

       LDAA Current
       BEQ FromF0
       CMPA #1
       BEQ FromF1
       BRA FromF2

FromF0:
       LDAA Request1
       BEQ F0_F2
       MOVB #1, Target
       BRA ISR_Done
F0_F2:
       LDAA Request2
       BEQ ISR_Done
       MOVB #2, Target
       BRA ISR_Done

FromF1:
       LDAA Request0
       BEQ F1_Up
       LDAB Request2
       BEQ ServeF0
       MOVB #0, Target
       BRA ISR_Done
ServeF0:
       MOVB #0, Target
       BRA ISR_Done
F1_Up:
       LDAA Request2
       BEQ ISR_Done
       MOVB #2, Target
       BRA ISR_Done

FromF2:
       LDAA Request1
       BEQ F2_F0
       MOVB #1, Target
       BRA ISR_Done
F2_F0:
       LDAA Request0
       BEQ ISR_Done
       MOVB #0, Target

ISR_Done:
       RTI

;=========================================================
; SUBROUTINES
;=========================================================

;---------------------------------------
; PWM BUZZER INITIALIZATION (RAWAD’S VERSION)
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
       BSET PWME, #$10
       RTS

;---------------------------------------
; DISABLE BUZZER
;---------------------------------------
StopBuzz:
       BCLR PWME, #$10
       RTS

;---------------------------------------
; LCD/SPI ROUTINES (unchanged)
;---------------------------------------
SENDINST:
       TAB
       RORA:RORA:RORA:RORA
       ORAA #%10000000
       ANDA #%10001111
       JSR SENDSPI
       ANDA #%00001111
       JSR SENDSPI
       JSR DELAY

       TBA
       ORAA #%10000000
       ANDA #%10001111
       JSR SENDSPI
       ANDA #%00001111
       JSR SENDSPI
       JSR DELAY
       RTS

SENDDATA:
       TAB
       RORA:RORA:RORA:RORA
       ORAA #%11000000
       ANDA #%11001111
       JSR SENDSPI
       ANDA #%01001111
       JSR SENDSPI
       JSR DELAY

       TBA
       ORAA #%11000000
       ANDA #%11001111
       JSR SENDSPI
       ANDA #%01001111
       JSR SENDSPI
       JSR DELAY
       RTS

SENDSPI:
       BRCLR SPI0SR, #$20, *
       STAA SPI0DR
       RTS

DELAY:
       LDX #10000
D1:
       PSHB:PULB:PSHB:PULB:PSHB:PULB
       DEX
       BNE D1
       RTS

DelayADC:
       LDX #5000
D2:
       DEX
       BNE D2
       RTS

;=========================================================
; INTERRUPT VECTORS
;=========================================================
       ORG $FFFE
       DC.W Entry

       ORG $FFCA
       DC.W MCCNT_ISR
