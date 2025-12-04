;***********************
;* This stationery serves as the framework for a                 *
;* user application (single file, absolute assembly application) *
;* For a more comprehensive program that                          *
;* demonstrates the more advanced functionality of this           *
;* processor, please see the demonstration applications           *
;* located in the examples subdirectory of the                    *
;* Freescale CodeWarrior for the HC12 Program directory           *
;***********************

; export symbols
            XDEF Entry, _Startup            ; export 'Entry' symbol
       ABSENTRY Entry                  ; for absolute assembly: mark this as application entry point

; Include derivative-specific definitions 
		INCLUDE 'derivative.inc' 

ROMStart    EQU  $4000  ; absolute address to place my code/constant data

; variable/data section
            ORG RAMStart
 ; Insert here your data definition.
Current     DS.B 1      ; 0=GND, 1=1st, 2=2nd
Target      DS.B 1
State       DS.B 1      ; 0=IDLE, 1=UP, 2=DOWN, 3=OVERLOADED
ADCValue    DS.B 1      ; Weight Sensor Reading
Overload    DS.B 1      ; Flag: 1=overloaded, 0=normal
Request0    DS.B 1
Request1    DS.B 1
Request2    DS.B 1
BlinkCount  DS.B 1

; code section
            ORG   ROMStart

Entry:
_Startup:
            LDS   #RAMEnd+1       ; initialize the stack pointer
       CLI                   ; enable interrupts

       ; Initialize variables
       CLR   Current         ; Start at ground floor
       CLR   Target
       CLR   State
       CLR   Overload
       CLR   Request0
       CLR   Request1
       CLR   Request2
       
       MOVB  #$00, DDRA
       MOVB  #$02, PUCR 
       MOVB  #%11100000, DDRT
       MOVB  #%00000000, PTT
       
       ; Initialize PWM for Buzzer (Channel 0 on PP0 pin)
       ; Based on Lab 9 Task 1: Create 1kHz signal with 50% duty cycle
       ; IMPORTANT: Configure PWM registers BEFORE enabling
       
       ; First disable PWM before configuring
       BCLR  PWME, #%00000001       ; Disable PWM Channel 0 first
       
       ; Configure prescaler for Clock A FIRST
       ; PCKA[2:0] = 000 means Clock A = E/1 (no prescale)
       ; PCKA[2:0] = 001 means Clock A = E/2
       ; PCKA[2:0] = 010 means Clock A = E/4
       ; For 8MHz E-clock, to get 1kHz: Period = 8,000,000 / 1000 = 8000
       ; Using E/2: Period = 4,000,000 / 1000 = 4000
       ; Using E/4: Period = 2,000,000 / 1000 = 2000 (better for 16-bit period)
       ; Set PCKA[2:0] = 010 (E/4): Clear PCKA0, Set PCKA1, Clear PCKA2
       BCLR  PWMPRCLK, #%00000101   ; Clear PCKA0 (bit 0) and PCKA2 (bit 2)
       BSET  PWMPRCLK, #%00000010   ; Set PCKA1 (bit 1) for E/4
       
       ; Configure clock source - use Clock A
       BCLR  PWMCLK, #%00000001     ; Channel 0 uses Clock A
       
       ; Configure PWM polarity (start high)
       BSET  PWMPOL, #%00000001     ; Set polarity high for Channel 0
       
       ; Set PWM period for 1kHz (as per Lab 9 Task 1)
       ; With E/4 = 2MHz, Period = 2,000,000 / 1000 = 2000
       MOVW  #2000, PWMPER0         ; Period = 2000 (for 1kHz)
       
       ; Set duty cycle to 50% for buzzer (as per Lab 9 Task 1)
       MOVW  #1000, PWMDTY0         ; Duty = 1000 (50% of period = 2000/2)
       
       ; Keep PWM disabled initially (will enable when needed)
       BCLR  PWME, #%00000001       ; Ensure buzzer is disabled

       ; Initialize ADC (Weight Sensor on channel 5)
       MOVB  #%11000000, ATD0CTL2    ; Power up ATD
       JSR   DelayADC                ; Wait for stabilization
       MOVB  #%00001000, ATD0CTL3    ; 1 conversion, right justified
       MOVB  #%10000101, ATD0CTL4    ; 8-bit resolution

       ; Configure MCCNT for periodic button checking (every 100ms)
       ; Bus clock = 8 MHz, prescaler = 128
       ; 8,000,000 / 128 = 62,500 Hz
       ; For 100ms: 62,500 / 10 = 6,250 counts
       MOVB  #%11000111, MCCTL       ; Enable MCCNT, prescaler=128, interrupt ON
       MOVW  #6250, MCCNT            ; 100ms interval

       ; Configure LCD via SPI
       MOVB  #$10, MODRR             ; Route SPI to Port M
       MOVB  #$38, DDRM              ; Set Port M pins as outputs
       MOVB  #$52, SPI0CR1           ; SPI master mode, CPOL=1, CPHA=0
       MOVB  #$10, SPI0CR2           ; SS output enabled
       MOVB  #$00, SPI0BR            ; SPI baud rate

       ; Initialize LCD with 7 commands
       LDAA  #%00110011              ; Function set
       JSR   SENDINST
       LDAA  #%00110010              ; Function set
       JSR   SENDINST
       LDAA  #%00101000              ; 4-bit mode, 2 lines
       JSR   SENDINST
       LDAA  #%00001000              ; Display off
       JSR   SENDINST
       LDAA  #%00000001              ; Clear display
       JSR   SENDINST
       LDAA  #%00000110              ; Entry mode
       JSR   SENDINST
       LDAA  #%00001110              ; Display on, cursor on
       JSR   SENDINST

       LDAA  #'F'
       JSR   SENDDATA
       LDAA  Current
       ADDA  #'0'
       JSR   SENDDATA
;Mainloop waits for the interrupt to update the target
MainLoop:
       LDAA  Overload               ; Check overload flag
       BNE   OverloadWait           ; If overloaded, wait

       LDAA  Target                 ; Check if there's a target
       BEQ   MainLoop               ; No target, keep waiting

       ; Compare current floor with target
       LDAB  Current
       CBA                          ; Compare A (Target) with B (Current)
       BEQ   ClearTarget            ; Already at target floor
       BHI   MOVEUP                 ; Target > Current, move up
       ; Target < Current, move down
       ; Additional safety check: ensure Current is not already 0
       LDAB  Current
       BEQ   ClearTarget            ; Already at F0, clear target
       ; Additional check: if Target is 0 and Current is 1, we can move down
       CMPB  #1                      ; Check if Current is 1
       BNE   DoMoveDown             ; If not 1, proceed normally
       LDAA  Target
       BEQ   DoMoveDown             ; If Target is 0, it's valid to move down
       BRA   ClearTarget            ; Otherwise, clear target
DoMoveDown:
       JMP   MOVEDOWN               ; Move down

ClearTarget:
       CLR   Target                 ; Clear target
       CLR   State                  ; Clear state to allow ISR to set new target
       BRA   MainLoop

OverloadWait:
       ; Keep blinking red LED and beeping until weight is normal
       LDAA  #%00000001             ; Clear LCD
       JSR   SENDINST
       JSR   DELAY
       
       LDAA  #'O'                   ; Write OVERLOAD on LCD
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
       
       BSET  PTT, #%00100000        ; Turn ON red LED
       JSR   DELAY
       JSR   DELAY
       BCLR  PTT, #%00100000        ; Turn OFF red LED
       JSR   DELAY
       JSR   DELAY
       
       ; Check if still overloaded
       LDAA  Overload
       BNE   OverloadWait           ; Still overloaded, continue blinking
       
       ; Overload cleared, restore display
       LDAA  #%00000001             ; Clear LCD
       JSR   SENDINST
       JSR   DELAY
       LDAA  #'F'
       JSR   SENDDATA
       LDAA  Current
       ADDA  #'0'
       JSR   SENDDATA
       BRA   MainLoop

MOVEUP:
       MOVB  #1, State              ; Declare moving up
       
       LDAA  #%00000001             ; Clear LCD
       JSR   SENDINST
       JSR   DELAY
       
       LDAA  #'M'                   ; Write MOVING UP on LCD
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
       ; Blink the Green LED continuosly 10 times
       BCLR  PTT, #%10000000
       JSR   DELAY
       JSR   DELAY
       BSET  PTT, #%10000000
       JSR   DELAY
       JSR   DELAY
       DEC   BlinkCount
       LDAA  BlinkCount
       BNE   UpLoop
       
       ; Increment the current floor
       INC   Current
       
       ; compare with requested
       LDAA  Target
       LDAB  Current
       CBA
       ; if equal, branch to ARRIVED
       LBEQ   ARRIVED
       ; else bra UpLoop
       MOVB  #10, BlinkCount
       BRA   UpLoop

MOVEDOWN:
       MOVB  #2, State              ; Declare moving up

       LDAA  #%00000001             ;Clear LCD
       JSR   SENDINST
       JSR   DELAY


       LDAA  #'M'                   ; Write MOVING UP on LCD
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
       ; Blink the Yellow LED continuosly 10 times
       BCLR  PTT, #%01000000
       JSR   DELAY
       JSR   DELAY
       BSET  PTT, #%01000000
       JSR   DELAY
       JSR   DELAY
       DEC   BlinkCount
       LDAA  BlinkCount
       BNE   DownLoop
       
       ; After blinking, check if we've reached target BEFORE moving
       LDAA  Target
       LDAB  Current
       CBA
       BEQ   ARRIVED              ; Already at target, go to arrived
       
       ; Safety check: if Current is already 0, we're at F0
       LDAB  Current
       BEQ   ARRIVED              ; Already at F0, go to arrived
       
       ; Now it's safe to decrement - we know Current > 0 and Current != Target
       DEC   Current
       
       ; After decrementing, check if we've reached the target
       LDAA  Target
       LDAB  Current
       CBA
       BEQ   ARRIVED              ; Reached target, go to arrived
       
       ; Check for underflow (should never happen, but safety check)
       LDAB  Current
       CMPB  #$FF                 ; Check if underflow occurred (DEC 0 = $FF)
       BEQ   FixUnderflow         ; Fix underflow if it happened
       
       ; Not at target yet, continue moving down
       MOVB  #10, BlinkCount
       BRA   DownLoop
       
FixUnderflow:
       CLR   Current              ; Fix underflow - set to 0
       BRA   ARRIVED              ; Go to arrived since we're at F0

ARRIVED:
       ; Turn off green and yellow LEDs
       BCLR  PTT, #%11000000
       
       ; Turn ON red LED
       BSET  PTT, #%00100000
       
       ; Buzzer beeps for 2 seconds using PWM
       ; Enable PWM Channel 0 (buzzer) - PP0 pin
       ; Make sure PWM is properly configured before enabling
       BSET  PWME, #%00000001       ; Enable PWM Channel 0 (buzzer)
       
       ; Wait for 2 seconds (20 * 100ms = 2000ms)
       LDAB  #20
BuzzDelay:
       JSR   DELAY                  ; 100ms delay
       DECB
       BNE   BuzzDelay
       
       ; Turn OFF buzzer but keep red LED ON
       BCLR  PWME, #%00000001       ; Disable PWM Channel 0 (buzzer)
       
       ; Small delay to ensure PWM stops cleanly
       JSR   DELAY
       
       ; Red LED stays ON (already set above)
       
       ; Display current floor on LCD
       LDAA  #%00000001
       JSR   SENDINST
       JSR   DELAY
       
       LDAA  #'F'
       JSR   SENDDATA
       LDAA  Current
       ADDA  #'0'
       JSR   SENDDATA
       
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
       CLR   Target
       CLR   State
       
       ; Wait with red LED ON (door open)
       LDAB  #10                    ; 10 * 100ms = 1 second
ArrWait:
       JSR   DELAY
       DECB
       BNE   ArrWait
       
       BCLR  PTT, #%00100000        ; Turn OFF red LED (door closed)
       
       ; After arriving, check if there are more requests
       ; The ISR will set a new Target if there are pending requests
       JMP   MainLoop

MCCNT_ISR:
       ; Clear interrupt flag
       MOVB  #$80, MCFLG            ; Clear MCZF flag

       ; Reload counter for next 100ms
       MOVW  #6250, MCCNT

       ;CHECK IF OBESE
       MOVB  #%10100101, ATD0CTL5   ; Start ADC conversion
WaitADC:
       BRCLR ATD0STAT0, #$80, WaitADC ; Wait for conversion
       LDAA  ATD0DR0L               ; Read ADC value
       STAA  ADCValue

       CMPA  #125                   ; Check threshold
       BLS   WeightOK               ; Weight <= 125, OK

       ; Overload detected
       MOVB  #1, Overload           ; Set overload flag
       MOVB  #3, State              ; State = OVERLOAD
       BCLR  PTT, #%11000000        ; Turn off green and yellow LEDs
       BSET  PWME, #%00000001       ; Enable buzzer for overload warning
       RTI                          ; Exit ISR during overload

WeightOK:
       CLR   Overload               ; Clear overload flag (removes overload when pot drops)
       LDAA  State
       CMPA  #3                     ; Check if was in overload state
       BNE   NotRecovering
       
       ; Recovering from overload, turn off red LED and buzzer
       BCLR  PTT, #%00100000        ; Turn OFF red LED
       BCLR  PWME, #%00000001       ; Turn OFF buzzer
       CLR   State                  ; Reset state to IDLE
       
NotRecovering:
       ; Read all buttons and do what is needed
       LDAA  PORTA
       COMA
       ANDA  #%11111100
       BEQ   NoButtons              ; No buttons pressed

       ; Check each button and set Target accordingly
       LDAA  PORTA
       COMA
       ANDA  #%00000100
       BEQ   CheckPB4
       MOVB  #1, Request0
CheckPB4:
       LDAA  PORTA
       COMA
       ANDA  #%00001000
       BEQ   CheckPB5
       MOVB  #1, Request1
CheckPB5:
       LDAA  PORTA
       COMA
       ANDA  #%00010000
       BEQ   CheckPB6
       MOVB  #1, Request2
CheckPB6:
       LDAA  PORTA
       COMA
       ANDA  #%00100000
       BEQ   CheckPB7
       MOVB  #1, Request0
CheckPB7:
       LDAA  PORTA
       COMA
       ANDA  #%01000000
       BEQ   CheckPB8
       MOVB  #1, Request1
CheckPB8:
       LDAA  PORTA
       COMA
       ANDA  #%10000000
       BEQ   NoButtons
       MOVB  #1, Request2

NoButtons:
       ; REMEMBER YA RAWAD W REEM: Priority: serve closest floor first
       ; Only set new Target if no current Target (elevator is idle or just arrived)
       LDAA  Target
       BNE   ISR_Done               ; Already has a target, don't change it
       
       ; Check which floor we're on and find next request
       LDAA  Current
       BEQ   CheckFromF0
       CMPA  #1
       BEQ   CheckFromF1
       BRA   CheckFromF2

CheckFromF0:
       LDAA  Request1
       BEQ   CheckF0toF2
       MOVB  #1, Target
       BRA   ISR_Done
CheckF0toF2:
       LDAA  Request2
       BEQ   ISR_Done
       MOVB  #2, Target
       BRA   ISR_Done

CheckFromF1:
       ; Check both up and down, serve closest first
       ; When on F1, check F0 first (down), then F2 (up)
       LDAA  Request0
       BEQ   CheckF1Up              ; No F0 request, check F2
       ; F0 is requested - always serve F0 first from F1 (it's closer)
       MOVB  #0, Target
       BRA   ISR_Done
CheckF1Up:
       ; No F0 request, check F2
       LDAA  Request2
       BEQ   ISR_Done               ; No requests, exit
       ; F2 is requested
       MOVB  #2, Target
       BRA   ISR_Done

CheckFromF2:
       ; When on F2, check requests in descending order: F1, then F0
       LDAA  Request1
       BEQ   CheckF2toF0            ; No F1 request, check F0
       ; F1 is requested, go to F1 first (will handle F0 after if needed)
       MOVB  #1, Target
       BRA   ISR_Done
CheckF2toF0:
       ; No F1 request, check F0
       LDAA  Request0
       BEQ   ISR_Done               ; No F0 request either, exit
       ; F0 is requested, go directly to F0
       MOVB  #0, Target
       BRA   ISR_Done

ISR_Done:
       RTI                          ; Return from interrupt

       BRA   Exit


;Subroutines
SENDINST:
       TAB                          ; Save A to B
       RORA                         ; Shift right 4 times to get high nibble
       RORA
       RORA
       RORA
       ORAA  #%10000000             ; Set RS=0 (instruction), E=1
       ANDA  #%10001111             ; Mask unwanted bits
       JSR   SENDSPI                ; Send high nibble
       ANDA  #%00001111             ; E=0 (latch data)
       JSR   SENDSPI
       JSR   DELAY

       TBA                          ; Restore A from B (low nibble)
       ORAA  #%10000000             ; Set RS=0, E=1
       ANDA  #%10001111             ; Mask unwanted bits
       JSR   SENDSPI                ; Send low nibble
       ANDA  #%00001111             ; E=0 (latch data)
       JSR   SENDSPI
       JSR   DELAY
       RTS

SENDDATA:
       TAB                          ; Save A to B
       RORA                         ; Shift right 4 times
       RORA
       RORA
       RORA
       ORAA  #%11000000             ; Set RS=1 (data), E=1
       ANDA  #%11001111             ; Mask unwanted bits
       JSR   SENDSPI                ; Send high nibble
       ANDA  #%01001111             ; E=0 (latch data)
       JSR   SENDSPI
       JSR   DELAY

       TBA                          ; Restore A from B
       ORAA  #%11000000             ; Set RS=1, E=1
       ANDA  #%11001111             ; Mask unwanted bits
       JSR   SENDSPI                ; Send low nibble
       ANDA  #%01001111             ; E=0 (latch data)
       JSR   SENDSPI
       JSR   DELAY
       RTS

SENDSPI:
       BRCLR SPI0SR, #$20, *        ; Wait for SPI ready
       STAA  SPI0DR                 ; Send data via SPI
       RTS

DELAY:
       LDX   #10000                 ; Delay counter (100ms at 2MHz)
again:
       PSHB
       PULB
       PSHB
       PULB
       PSHB
       PULB
       DEX
       BNE   again
       RTS

DelayADC:
       LDX   #5000                  ; Delay for ADC power-up
DelayLoop:
       DEX
       BNE   DelayLoop
       RTS

Exit:

;**********************
;*                 Interrupt Vectors                          *
;**********************
            ORG   $FFFE
       DC.W  Entry                  ; Reset Vector

       ORG   $FFCA
       DC.W  MCCNT_ISR              ; Modulus Counter Interrupt Vector