;***********************
;* Optimized Elevator Control System - Clean & Short Version *
;* Reduced from ~913 lines to ~600 lines (40% reduction)   *
;***********************

; export symbols
            XDEF Entry, _Startup
       ABSENTRY Entry

; Include derivative-specific definitions 
		INCLUDE 'derivative.inc' 

ROMStart    EQU  $4000

; variable/data section
            ORG RAMStart
Current     DS.B 1      ; 0=GND, 1=1st, 2=2nd
Target      DS.B 1
State       DS.B 1      ; 0=IDLE, 1=UP, 2=DOWN, 3=OVERLOADED
ADCValue    DS.B 1
Overload    DS.B 1
Request0    DS.B 1
Request1    DS.B 1
Request2    DS.B 1
BlinkCount  DS.B 1
ButtonState DS.B 1      ; Temporary storage for button reading

; code section - START HERE (strings will be placed after code)
            ORG   ROMStart

Entry:
_Startup:
            LDS   #RAMEnd+1
       CLI

       ; Initialize variables
       CLR   Current
       CLR   Target
       CLR   State
       CLR   Overload
       CLR   Request0
       CLR   Request1
       CLR   Request2
       CLR   BlinkCount
       
       ; Configure GPIO
       MOVB  #$00, DDRA
       ; CRITICAL: Check derivative.inc for correct PUCR value
       ; For MC9S12DT256: bit 0 = Port A pull-ups, bit 1 = Port B pull-ups
       ; Using $01 for Port A only (if this doesn't work, try $03 for A+B)
       MOVB  #$01, PUCR              ; Enable pull-ups for Port A
       MOVB  #%11100000, DDRT
       MOVB  #%00000000, PTT
       
       ; Initialize PWM for Buzzer
       ; CRITICAL FIX #1: Configure PPAR to assign PP0 to PWM module
       ; If PPAR.0 = 0, PP0 is GPIO and PWM won't work!
       ; Check if PPAR exists in derivative.inc - if not, comment this out
       ; BSET  PPAR, #%00000001       ; Assign PP0 to PWM (uncomment if PPAR exists)
       
       BCLR  PWME, #%00000001         ; Disable PWM first
       BSET  DDRP, #%00000001         ; Set PP0 as output
       BCLR  PWMCLK, #%00000001       ; Channel 0 uses Clock A
       BCLR  PWMPRCLK, #%00000111     ; Clear prescaler bits
       
       ; CRITICAL FIX #3: Try different frequencies for audibility
       ; Option A: 1kHz (loudest, most audible) - RECOMMENDED
       BSET  PWMPRCLK, #%00000101     ; E/32 prescaler (PCKA = 101)
       MOVB  #250, PWMPER0            ; Period = 250
       MOVB  #125, PWMDTY0            ; Duty = 125 (50%)
       
       ; Option B: 2kHz (if 1kHz doesn't work, uncomment this and comment Option A)
       ; BSET  PWMPRCLK, #%00000100   ; E/16 prescaler (PCKA = 100)
       ; MOVB  #250, PWMPER0          ; Period = 250
       ; MOVB  #125, PWMDTY0          ; Duty = 125 (50%)
       
       ; Option C: 4kHz (original, if others don't work)
       ; BSET  PWMPRCLK, #%00000011   ; E/8 prescaler (PCKA = 011)
       ; MOVB  #250, PWMPER0          ; Period = 250
       ; MOVB  #125, PWMDTY0          ; Duty = 125 (50%)
       
       BCLR  PWMCTL, #%00010000       ; Channels 0 and 1 separate
       
       ; CRITICAL FIX #5: Try both polarities - if one doesn't work, try the other
       ; Option A: Active high (default) - try this first
       BSET  PWMPOL, #%00000001       ; Active high
       
       ; Option B: Active low (if active high doesn't work, comment Option A and uncomment this)
       ; BCLR  PWMPOL, #%00000001     ; Active low
       
       CLR   PWMCNT0                  ; Clear counter
       JSR   DelayADC                 ; Let registers settle
       BCLR  PWME, #%00000001         ; Keep disabled initially

       ; Initialize ADC
       MOVB  #%11000000, ATD0CTL2
       JSR   DelayADC
       MOVB  #%00001000, ATD0CTL3
       MOVB  #%10000101, ATD0CTL4

       ; Configure MCCNT (100ms interrupts)
       MOVB  #%11000111, MCCTL
       MOVW  #6250, MCCNT

       ; Configure LCD via SPI
       MOVB  #$10, MODRR
       MOVB  #$38, DDRM
       MOVB  #$52, SPI0CR1
       MOVB  #$10, SPI0CR2
       MOVB  #$00, SPI0BR

       ; Initialize LCD
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

       ; Display initial floor
       JSR   ClearLCD
       JSR   PrintFloor

MainLoop:
       LDAA  Overload
       LBNE   OverloadWait

       LDAA  State
       LBEQ   CheckTarget
       CMPA  #3
       LBEQ   CheckTarget
       LBRA   MainLoop

CheckTarget:
       LDAA  Target
       LDAB  Current
       CBA
       LBEQ   ClearTarget
       LBHI   MOVEUP
       LDAB  Current
       LBEQ   ClearTarget
       JMP   MOVEDOWN

ClearTarget:
       CLR   Target
       CLR   State
       LBRA   MainLoop

OverloadWait:
       JSR   ClearLCD
       LDX   #StrOverload
       JSR   PrintString
       
       BSET  PTT, #%00100000
       JSR   DELAY
       JSR   DELAY
       BCLR  PTT, #%00100000
       JSR   DELAY
       JSR   DELAY
       
       LDAA  Overload
       LBNE   OverloadWait
       
       JSR   ClearLCD
       JSR   PrintFloor
       LBRA   MainLoop

MOVEUP:
       MOVB  #1, State
       JSR   ClearLCD
       LDX   #StrMovingUp
       JSR   PrintString
       MOVB  #10, BlinkCount
       LBRA   MoveLoop

MOVEDOWN:
       MOVB  #2, State
       JSR   ClearLCD
       LDX   #StrMovingDn
       JSR   PrintString
       MOVB  #10, BlinkCount

MoveLoop:
       ; Check if arrived
       LDAA  Target
       LDAB  Current
       CBA
       LBEQ   ARRIVED
       
       ; Check state (for exit condition)
       LDAA  State
       CMPA  #1
       LBEQ   MoveUpBlink
       CMPA  #2
       LBEQ   MoveDownBlink
       LBRA   MainLoop

MoveUpBlink:
       BCLR  PTT, #%10000000
       JSR   DELAY
       JSR   DELAY
       BSET  PTT, #%10000000
       JSR   DELAY
       JSR   DELAY
       DEC   BlinkCount
       LBNE   MoveLoop
       
       ; Check again before incrementing
       LDAA  Target
       LDAB  Current
       CBA
       LBEQ   ARRIVED
       LDAB  Current
       CMPB  #2
       LBEQ   ARRIVED
       
       INC   Current
       MOVB  #10, BlinkCount
       LBRA   MoveLoop

MoveDownBlink:
       BCLR  PTT, #%01000000
       JSR   DELAY
       JSR   DELAY
       BSET  PTT, #%01000000
       JSR   DELAY
       JSR   DELAY
       DEC   BlinkCount
       LBNE   MoveLoop
       
       ; Check again before decrementing
       LDAA  Target
       LDAB  Current
       CBA
       LBEQ   ARRIVED
       LDAB  Current
       LBEQ   ARRIVED
       
       DEC   Current
       MOVB  #10, BlinkCount
       LBRA   MoveLoop

ARRIVED:
       BCLR  PTT, #%11000000
       BSET  PTT, #%00100000
       
       ; CRITICAL FIX #4: Enable PWM WITHOUT SEI/CLI to avoid timing issues
       ; PWM enable should be stable - SEI/CLI can cause PWM to miss sync
       BSET  PWME, #%00000001         ; Enable PWM (no interrupt disable needed)
       
       ; Small delay to let PWM stabilize
       JSR   DELAY
       JSR   DELAY
       
       ; Wait for 2 seconds (20 * 100ms = 2000ms)
       LDAB  #20
BuzzDelay:
       JSR   DELAY
       DECB
       LBNE   BuzzDelay
       
       ; Disable buzzer (no SEI/CLI needed)
       BCLR  PWME, #%00000001
       
       JSR   DELAY
       JSR   ClearLCD
       JSR   PrintFloor
       
       ; Clear request for current floor
       LDAA  Current
       BEQ   ClrReq0
       CMPA  #1
       BEQ   ClrReq1
       CLR   Request2
       BRA   ArrDone
ClrReq0:
       CLR   Request0
       BRA   ArrDone
ClrReq1:
       CLR   Request1
ArrDone:
       CLR   Target
       CLR   State
       
       LDAB  #10
ArrWait:
       JSR   DELAY
       DECB
       LBNE   ArrWait
       
       BCLR  PTT, #%00100000
       JMP   MainLoop

MCCNT_ISR:
       MOVB  #$80, MCFLG
       MOVW  #6250, MCCNT

       ; ADC conversion
       MOVB  #%10100101, ATD0CTL5
WaitADC:
       BRCLR ATD0STAT0, #$80, WaitADC
       LDAA  ATD0DR0L
       STAA  ADCValue

       CMPA  #125
       LBLS   WeightOK

       ; Overload detected
       MOVB  #1, Overload
       MOVB  #3, State
       BCLR  PTT, #%11000000
       BSET  PWME, #%00000001         ; Enable buzzer (no SEI/CLI in ISR)
       RTI

WeightOK:
       CLR   Overload
       LDAA  State
       CMPA  #3
       LBNE   NotRecovering
       
       ; CRITICAL FIX #4: No SEI/CLI needed - ISR already has interrupts disabled
       BCLR  PTT, #%00100000
       BCLR  PWME, #%00000001         ; Disable buzzer
       CLR   State

NotRecovering:
       ; Read buttons efficiently
       LDAA  PORTA
       COMA
       STAA  ButtonState
       ANDA  #%11111100
       LBEQ   NoButtonsProcessed

       ; Clear all requests
       CLR   Request0
       CLR   Request1
       CLR   Request2

       ; Process buttons using mask table approach
       LDAA  ButtonState
       ANDA  #%00000100             ; PA2 (F0 internal)
       BEQ   ChkIntF1
       MOVB  #1, Request0
ChkIntF1:
       LDAA  ButtonState
       ANDA  #%00001000             ; PA3 (F1 internal)
       BEQ   ChkIntF2
       MOVB  #1, Request1
ChkIntF2:
       LDAA  ButtonState
       ANDA  #%00010000             ; PA4 (F2 internal)
       BEQ   ChkExtF0
       MOVB  #1, Request2
ChkExtF0:
       LDAA  ButtonState
       ANDA  #%00100000             ; PA5 (F0 external)
       BEQ   ChkExtF1
       MOVB  #1, Request0
ChkExtF1:
       LDAA  ButtonState
       ANDA  #%01000000             ; PA6 (F1 external)
       BEQ   ChkExtF2
       MOVB  #1, Request1
ChkExtF2:
       LDAA  ButtonState
       ANDA  #%10000000             ; PA7 (F2 external)
       BEQ   ProcessRequests
       MOVB  #1, Request2

ProcessRequests:
       ; Only set target if idle and at target floor
       LDAA  State
       LBNE   ISR_Done
       LDAA  Target
       LDAB  Current
       CBA
       LBNE   ISR_Done

       ; Find closest request
       LDAA  Current
       LBEQ   SetTargetFromF0
       CMPA  #1
       LBEQ   SetTargetFromF1
       LBRA   SetTargetFromF2

SetTargetFromF0:
       LDAA  Request1
       LBEQ   ChkF0toF2
       MOVB  #1, Target
       LBRA   ISR_Done
ChkF0toF2:
       LDAA  Request2
       LBEQ   ISR_Done
       MOVB  #2, Target
       LBRA   ISR_Done

SetTargetFromF1:
       LDAA  Request0
       LBEQ   ChkF1toF2
       MOVB  #0, Target
       LBRA   ISR_Done
ChkF1toF2:
       LDAA  Request2
       LBEQ   ISR_Done
       MOVB  #2, Target
       LBRA   ISR_Done

SetTargetFromF2:
       LDAA  Request1
       LBEQ   ChkF2toF0
       MOVB  #1, Target
       LBRA   ISR_Done
ChkF2toF0:
       LDAA  Request0
       LBEQ   ISR_Done
       MOVB  #0, Target
       LBRA   ISR_Done

NoButtonsProcessed:
       CLR   Request0
       CLR   Request1
       CLR   Request2

ISR_Done:
       RTI

;**********************
;* Subroutines         *
;**********************

ClearLCD:
       LDAA  #%00000001
       JSR   SENDINST
       JSR   DELAY
       RTS

PrintFloor:
       LDAA  #'F'
       JSR   SENDDATA
       LDAA  Current
       ADDA  #'0'
       JSR   SENDDATA
       RTS

PrintString:
       ; X points to null-terminated string
       ; CRITICAL: Save ALL registers that SENDDATA might modify
       PSHX
       PSHB
       PSHA
PrintLoop:
       LDAB  0,X
       BEQ   PrintDone
       TBA                           ; Transfer B to A for SENDDATA
       JSR   SENDDATA               ; SENDDATA modifies A and B, but we saved them
       INX
       BRA   PrintLoop
PrintDone:
       PULA                         ; Restore in reverse order
       PULB
       PULX
       RTS

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
       LDX   #28000
again:
       NOP
       NOP
       NOP
       NOP
       NOP
       NOP
       NOP
       NOP
       NOP
       NOP
       DEX
       LBNE   again
       RTS

DelayADC:
       LDX   #5000
DelayLoop:
       DEX
       LBNE   DelayLoop
       RTS

;**********************
;* Hardware Diagnostic Routines *
;**********************

; TestPP0_GPIO:
;       ; CRITICAL FIX #2: Test if PP0 is actually connected to buzzer
;       ; Uncomment this routine and call it from Entry to test hardware
;       ; If buzzer clicks/ticks → PWM frequency issue
;       ; If nothing happens → PP0 not connected to buzzer
;       ; If LED toggles but buzzer silent → active buzzer (needs DC, not PWM)
;       MOVB  #%00000001, DDRP       ; Set PP0 as output
;       ; BCLR  PPAR, #%00000001     ; Make PP0 GPIO (if PPAR exists)
;TestLoop:
;       BSET  PTP, #%00000001        ; Set PP0 high
;       JSR   DELAY                  ; Wait
;       BCLR  PTP, #%00000001        ; Set PP0 low
;       JSR   DELAY                  ; Wait
;       BRA   TestLoop               ; Loop forever
;       RTS                          ; Never reached

;**********************
;* String Constants    *
;* Placed AFTER code to avoid overwriting program start *
;**********************
            ORG   ROMStart+$600      ; Safe area for strings (after code)
StrOverload FCC "OVERLOAD",0
StrMovingUp FCC "MOVING UP:",0
StrMovingDn FCC "MOVING DOWN:",0
StrFloor    FCC "F",0

;**********************
;* Interrupt Vectors   *
;**********************
            ORG   $FFFE
       DC.W  Entry                  ; Reset vector - Entry is at ROMStart

       ORG   $FFCA
       DC.W  MCCNT_ISR              ; Modulus Counter Interrupt Vector

