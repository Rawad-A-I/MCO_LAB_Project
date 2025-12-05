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
       CLR   Current         ; Start at ground floor (F0)
       CLR   Target          ; No target initially
       CLR   State           ; State = IDLE
       CLR   Overload        ; No overload initially
       CLR   Request0        ; No requests initially
       CLR   Request1        ; No requests initially
       CLR   Request2         ; No requests initially
       CLR   BlinkCount      ; Initialize blink counter
       
       MOVB  #$00, DDRA             ; PORTA all inputs
       ; CRITICAL FIX: Enable pull-ups on PA2-PA7 to prevent floating inputs
       ; PA2-PA7 are button inputs - they need pull-ups to prevent false readings
       ; PUCR bit 0 = enable pull-ups for Port A (NOT bit 1!)
       ; PUCR bit 1 = enable pull-ups for Port B
       ; On MC9S12DT256: PUCR bit 0 enables pull-ups for entire Port A
       ; This prevents floating pins from reading as "pressed" buttons
       MOVB  #$01, PUCR              ; Enable pull-ups for Port A (bit 0 = 1)
       MOVB  #%11100000, DDRT       ; PORTT: PT7, PT6, PT5 as outputs (LEDs)
       MOVB  #%00000000, PTT        ; Initialize PORTT (all LEDs off)
       
       ; Initialize PWM for Buzzer (Channel 0 on PP0 pin)
       ; Target: 4kHz signal with 50% duty cycle (audible frequency for piezo buzzers)
       ; E-clock = 8MHz (from system configuration)
       
       ; First disable PWM before configuring
       BCLR  PWME, #%00000001       ; Disable PWM Channel 0 first
       
       ; Configure Port P pin 0 as output (PP0 for PWM Channel 0)
       BSET  DDRP, #%00000001       ; Set PP0 as output
       
       ; Configure clock source - use Clock A for Channel 0
       BCLR  PWMCLK, #%00000001     ; Channel 0 uses Clock A (bit 0 = 0)
       
       ; Configure prescaler for Clock A
       ; For 4kHz with 8-bit PWM (max period = 255):
       ; E-clock = 8MHz
       ; Option: E/8 prescaler
       ;   Clock A = 8MHz / 8 = 1MHz
       ;   Period = 1,000,000 / 4,000 = 250 counts ✓ (fits in 8-bit)
       ; PWMPRCLK register: PCKA[2:0] bits control Clock A prescaler
       ; PCKA[2:0] = 011 (binary) = E/8
       ; Clear PCKA bits first, then set to 011
       BCLR  PWMPRCLK, #%00000111   ; Clear PCKA[2:0] bits
       BSET  PWMPRCLK, #%00000011   ; Set PCKA[2:0] = 011 (E/8 prescaler)
       
       ; Ensure channels 0 and 1 are NOT concatenated (for 8-bit mode)
       BCLR  PWMCTL, #%00010000     ; Clear CON01 bit (channels 0 and 1 separate)
       
       ; Configure PWM polarity (start high)
       BSET  PWMPOL, #%00000001     ; Set polarity high for Channel 0 (bit 0 = 1)
       
       ; Clear PWM counter for Channel 0 (important for proper startup)
       CLR   PWMCNT0                ; Clear PWM Channel 0 counter
       
       ; Set PWM period for 4kHz with E/8 prescaler
       ; Clock A = 8MHz / 8 = 1MHz
       ; Period = 1,000,000 / 4,000 = 250 counts
       MOVB  #250, PWMPER0          ; Period = 250 (for 4kHz with E/8 prescaler)
       
       ; Set duty cycle to 50% for buzzer
       MOVB  #125, PWMDTY0          ; Duty = 125 (50% of period = 250/2)
       
       ; Small delay to let PWM registers settle
       JSR   DelayADC
       
       ; Keep PWM disabled initially (will enable when needed)
       BCLR  PWME, #%00000001       ; Ensure buzzer is disabled

       ; Initialize ADC (Weight Sensor on channel 5)
       MOVB  #%11000000, ATD0CTL2    ; Power up ATD
       JSR   DelayADC                ; Wait for stabilization
       MOVB  #%00001000, ATD0CTL3    ; 1 conversion, right justified
       MOVB  #%10000101, ATD0CTL4    ; 8-bit resolution

       ; Configure MCCNT for periodic button checking using UNDERFLOW interrupt
       ; PDF requirement: Use MCCNT underflow interrupt to check buttons periodically
       ; Bus clock = 8 MHz, prescaler = 128
       ; 8,000,000 / 128 = 62,500 Hz
       ; For 100ms: 62,500 / 10 = 6,250 counts
       ; MCCNT counts down and generates interrupt on underflow (when it reaches 0)
       MOVB  #%11000111, MCCTL       ; Enable MCCNT, prescaler=128, interrupt ON
       MOVW  #6250, MCCNT            ; 100ms interval (reloads on underflow)

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
       LBNE   OverloadWait           ; If overloaded, wait

       ; Check if elevator is already moving (State != 0)
       LDAA  State
       LBEQ   CheckTarget            ; State is IDLE, check for new target
       CMPA  #3
       LBEQ   CheckTarget            ; State is OVERLOADED (shouldn't happen here, but check anyway)
       ; State is UP (1) or DOWN (2), elevator is moving - don't interrupt
       LBRA   MainLoop               ; Wait for movement to complete

CheckTarget:
       ; Check if there's a target
       ; Since Target can be 0 (F0), we can't use BEQ to check for "no target"
       ; Instead, check if State is IDLE - if State is IDLE and we're here, Target was set by ISR
       ; OR check if Current != Target (if they're equal, we're already there)
       LDAA  Target
       LDAB  Current
       CBA                          ; Compare Target with Current
       LBEQ   ClearTarget            ; Already at target floor, clear target
       
       ; We have a valid target (Target != Current)
       ; Compare to determine direction
       LBHI   MOVEUP                 ; Target > Current, move up
       ; Target < Current, move down
       ; Additional safety check: ensure Current is not already 0
       LDAB  Current
       LBEQ   ClearTarget            ; Already at F0, clear target (shouldn't happen)
       ; Valid to move down - Target < Current and Current > 0
       JMP   MOVEDOWN               ; Move down

ClearTarget:
       CLR   Target                 ; Clear target
       CLR   State                  ; Clear state to allow ISR to set new target
       LBRA   MainLoop

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
       LBNE   OverloadWait           ; Still overloaded, continue blinking
       
       ; Overload cleared, restore display
       LDAA  #%00000001             ; Clear LCD
       JSR   SENDINST
       JSR   DELAY
       LDAA  #'F'
       JSR   SENDDATA
       LDAA  Current
       ADDA  #'0'
       JSR   SENDDATA
       LBRA   MainLoop

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
       ; CRITICAL: Check target at the START of each loop iteration
       LDAA  Target
       LBEQ   UpLoopExit             ; Target cleared, exit immediately
       LDAB  Current
       CBA
       LBEQ   ARRIVED                ; Already at target, go to arrived immediately
       
       ; Safety check: if Current is already 2 (max floor), we're at F2
       LDAB  Current
       CMPB  #2
       LBEQ   ARRIVED                ; Already at F2, go to arrived
       
       ; Blink the Green LED continuosly 10 times
       BCLR  PTT, #%10000000
       JSR   DELAY
       JSR   DELAY
       BSET  PTT, #%10000000
       JSR   DELAY
       JSR   DELAY
       DEC   BlinkCount
       LDAA  BlinkCount
       LBNE   UpLoop                 ; Continue blinking if not done
       
       ; After blinking cycle completes, check target again BEFORE incrementing
       LDAA  Target
       LBEQ   UpLoopExit             ; Target was cleared, exit to main loop
       LDAB  Current
       CBA
       LBEQ   ARRIVED                ; Reached target during blinking, go to arrived
       
       ; Safety check: if Current is 2, we're at F2 (max floor)
       LDAB  Current
       CMPB  #2
       LBEQ   ARRIVED                ; Already at F2, go to arrived
       
       ; Now it's safe to increment - we know Current < 2 and Current != Target
       INC   Current
       
       ; After incrementing, immediately check if we've reached the target
       LDAA  Target
       LBEQ   UpLoopExit             ; Target was cleared, exit to main loop
       LDAB  Current
       CBA
       LBEQ   ARRIVED                ; Reached target, go to arrived
       
       ; Check for overflow (should never happen, but safety check)
       LDAB  Current
       CMPB  #3                     ; Check if overflow occurred (INC 2 = 3)
       LBHI   FixOverflow            ; Fix overflow if it happened
       
       ; Check if we overshot the target (Current > Target)
       LDAA  Target
       LDAB  Current
       CBA                          ; Compare Target (A) with Current (B)
       LBLO   FixOvershoot           ; Current > Target, we overshot
       
       ; Not at target yet, continue moving up
       MOVB  #10, BlinkCount
       LBRA   UpLoop
       
UpLoopExit:
       ; Target was cleared, return to main loop to get new target
       CLR   State
       JMP   MainLoop
       
FixOverflow:
       MOVB  #2, Current            ; Fix overflow - set to 2 (max floor)
       LBRA   ARRIVED                ; Go to arrived since we're at F2
       
FixOvershoot:
       ; We overshot - this shouldn't happen, but if it does, go to arrived
       ; The target should have been reached before this point
       LBRA   ARRIVED

MOVEDOWN:
       MOVB  #2, State              ; Declare moving down

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
       ; CRITICAL: Check if we've reached the target FIRST
       ; Compare Current with Target - if equal, we've arrived
       LDAA  Target
       LDAB  Current
       CBA                          ; Compare Target (A) with Current (B)
       LBEQ   ARRIVED              ; Already at target, go to arrived immediately
       
       ; Safety check: if Current is already 0, we're at F0
       ; If Target is also 0, we've arrived (handled above)
       ; If Target is not 0 but Current is 0, something is wrong - go to arrived anyway
       LDAB  Current
       LBEQ   ARRIVED              ; Already at F0, go to arrived
       
       ; Check if Target was cleared (Target = 0 AND we're not trying to go to F0)
       ; Since we're in DownLoop, if Target = 0, it means we want to go to F0
       ; So we should continue, not exit
       ; However, if State is cleared, that means we should exit
       LDAA  State
       CMPA  #2                     ; Check if State is still DOWN (2)
       LBNE   DownLoopExit         ; State changed, exit to main loop
       
       ; Blink the Yellow LED continuosly 10 times
       BCLR  PTT, #%01000000
       JSR   DELAY
       JSR   DELAY
       BSET  PTT, #%01000000
       JSR   DELAY
       JSR   DELAY
       DEC   BlinkCount
       LDAA  BlinkCount
       LBNE   DownLoop             ; Continue blinking if not done
       
       ; After blinking cycle completes, check target again BEFORE decrementing
       LDAA  Target
       LDAB  Current
       CBA                          ; Compare Target with Current
       LBEQ   ARRIVED              ; Reached target during blinking, go to arrived
       
       ; Check if State was cleared (shouldn't happen, but safety check)
       LDAA  State
       CMPA  #2                     ; Check if State is still DOWN (2)
       LBNE   DownLoopExit         ; State changed, exit to main loop
       
       ; Safety check: if Current is 0, we're at F0
       LDAB  Current
       LBEQ   ARRIVED              ; Already at F0, go to arrived
       
       ; Now it's safe to decrement - we know Current > 0 and Current != Target
       DEC   Current
       
       ; After decrementing, immediately check if we've reached the target
       LDAA  Target
       LDAB  Current
       CBA                          ; Compare Target (A) with Current (B)
       LBEQ   ARRIVED              ; Reached target, go to arrived
       
       ; Check for underflow (should never happen, but safety check)
       LDAB  Current
       CMPB  #$FF                 ; Check if underflow occurred (DEC 0 = $FF)
       LBEQ   FixUnderflow         ; Fix underflow if it happened
       
       ; Check if we undershot the target (Current < Target)
       LDAA  Target
       LDAB  Current
       CBA                          ; Compare Target (A) with Current (B)
       LBHI   FixUndershoot         ; Current < Target, we undershot
       
       ; Not at target yet, continue moving down
       MOVB  #10, BlinkCount
       LBRA   DownLoop
       
DownLoopExit:
       ; Target was cleared, return to main loop to get new target
       CLR   State
       JMP   MainLoop
       
FixUnderflow:
       CLR   Current              ; Fix underflow - set to 0
       LBRA   ARRIVED              ; Go to arrived since we're at F0
       
FixUndershoot:
       ; We undershot - this shouldn't happen, but if it does, go to arrived
       ; The target should have been reached before this point
       LBRA   ARRIVED

ARRIVED:
       ; Turn off green and yellow LEDs
       BCLR  PTT, #%11000000
       
       ; Turn ON red LED
       BSET  PTT, #%00100000
       
       ; Buzzer beeps for 2 seconds using PWM
       ; Enable PWM Channel 0 (buzzer) - PP0 pin
       ; CRITICAL: Disable interrupts briefly to prevent race condition with overload ISR
       SEI                          ; Disable interrupts to prevent race condition
       BSET  PWME, #%00000001       ; Enable PWM Channel 0 (buzzer)
       CLI                          ; Re-enable interrupts
       
       ; Small delay to let PWM start generating signal (ensure stable output)
       JSR   DELAY
       JSR   DELAY                  ; Extra delay to ensure PWM is running
       
       ; Wait for 2 seconds (20 * 100ms = 2000ms)
       LDAB  #20
BuzzDelay:
       JSR   DELAY                  ; 100ms delay
       DECB
       LBNE   BuzzDelay
       
       ; Turn OFF buzzer but keep red LED ON
       ; CRITICAL: Disable interrupts briefly to prevent race condition
       SEI                          ; Disable interrupts to prevent race condition
       BCLR  PWME, #%00000001       ; Disable PWM Channel 0 (buzzer)
       CLI                          ; Re-enable interrupts
       
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
       LBEQ   ClearReq0
       CMPA  #1
       LBEQ   ClearReq1
       CLR   Request2
       LBRA   ArrDone
ClearReq0:
       CLR   Request0
       LBRA   ArrDone
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
       LBNE   ArrWait
       
       BCLR  PTT, #%00100000        ; Turn OFF red LED (door closed)
       
       ; After arriving, check if there are more requests
       ; The ISR will set a new Target if there are pending requests
       JMP   MainLoop

MCCNT_ISR:
       ; MCCNT underflow interrupt - check buttons periodically
       ; Clear interrupt flag (MCZF = Modulus Counter Zero Flag)
       MOVB  #$80, MCFLG            ; Clear MCZF flag (bit 7)

       ; Reload counter for next 100ms interval
       MOVW  #6250, MCCNT

       ;CHECK IF OBESE
       MOVB  #%10100101, ATD0CTL5   ; Start ADC conversion
WaitADC:
       BRCLR ATD0STAT0, #$80, WaitADC ; Wait for conversion
       LDAA  ATD0DR0L               ; Read ADC value
       STAA  ADCValue

       CMPA  #125                   ; Check threshold
       LBLS   WeightOK               ; Weight <= 125, OK

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
       LBNE   NotRecovering
       
       ; Recovering from overload, turn off red LED and buzzer
       ; CRITICAL: Use atomic operation to prevent race condition with ARRIVED
       ; Disable interrupts briefly when modifying PWM register
       SEI                          ; Disable interrupts to prevent race condition
       BCLR  PTT, #%00100000        ; Turn OFF red LED
       BCLR  PWME, #%00000001       ; Turn OFF buzzer
       CLI                          ; Re-enable interrupts
       CLR   State                  ; Reset state to IDLE
       
NotRecovering:
       ; Read all buttons ONCE and process efficiently
       ; According to PDF EXACTLY:
       ; Internal buttons: PB3-PB4-PB5 on PA2-PA3-PA4 for floors 0, 1, 2
       ; External buttons: PB6-PB7-PB8 on PA5-PA6-PA7 for floors 0, 1, 2
       LDAA  PORTA
       COMA                         ; Invert (buttons are active low)
       PSHB                          ; Save B register
       TAB                           ; Copy inverted PORTA to B for processing
       
       ; Check if ANY button is pressed (PA2-PA7, bits 2-7)
       ANDA  #%11111100             ; Mask out lower 2 bits (PA0-PA1 unused)
       LBEQ   NoButtonsProcessed    ; No buttons pressed, clear all requests and exit

       ; Clear all requests first - we'll set them based on actual button presses
       ; This ensures requests only exist when buttons are actually pressed
       CLR   Request0
       CLR   Request1
       CLR   Request2

       ; Check internal buttons (PA2-PA4 for floors 0, 1, 2)
       ; PA2 (bit 2) = PB3 = Internal F0 button
       TBA                           ; Get inverted PORTA value from B
       ANDA  #%00000100             ; Check bit 2 (PA2)
       LBEQ   CheckIntF1
       MOVB  #1, Request0           ; F0 button pressed
CheckIntF1:
       ; PA3 (bit 3) = PB4 = Internal F1 button
       TBA                           ; Get inverted PORTA value from B
       ANDA  #%00001000             ; Check bit 3 (PA3)
       LBEQ   CheckIntF2
       MOVB  #1, Request1           ; F1 button pressed
CheckIntF2:
       ; PA4 (bit 4) = PB5 = Internal F2 button
       TBA                           ; Get inverted PORTA value from B
       ANDA  #%00010000             ; Check bit 4 (PA4)
       LBEQ   CheckExtF0
       MOVB  #1, Request2           ; F2 button pressed
       
       ; Check external buttons (PA5-PA7 for floors 0, 1, 2)
CheckExtF0:
       ; PA5 (bit 5) = PB6 = External F0 button
       TBA                           ; Get inverted PORTA value from B
       ANDA  #%00100000             ; Check bit 5 (PA5)
       LBEQ   CheckExtF1
       MOVB  #1, Request0           ; F0 button pressed (external)
CheckExtF1:
       ; PA6 (bit 6) = PB7 = External F1 button
       TBA                           ; Get inverted PORTA value from B
       ANDA  #%01000000             ; Check bit 6 (PA6)
       LBEQ   CheckExtF2
       MOVB  #1, Request1           ; F1 button pressed (external)
CheckExtF2:
       ; PA7 (bit 7) = PB8 = External F2 button
       TBA                           ; Get inverted PORTA value from B
       ANDA  #%10000000             ; Check bit 7 (PA7)
       LBEQ   ButtonsProcessed
       MOVB  #1, Request2           ; F2 button pressed (external)
       
ButtonsProcessed:
       PULB                          ; Restore B register
       LBRA   NoButtons

NoButtonsProcessed:
       ; No buttons are pressed - clear all request flags IMMEDIATELY
       ; This prevents stale requests from causing unwanted movement
       ; CRITICAL: Clear requests BEFORE restoring B register to ensure they're cleared
       CLR   Request0
       CLR   Request1
       CLR   Request2
       ; Double-check that requests are cleared (defensive programming)
       LDAA  Request0
       BNE   ClearAgain              ; Request0 not cleared, clear again
       LDAA  Request1
       BNE   ClearAgain              ; Request1 not cleared, clear again
       LDAA  Request2
       BNE   ClearAgain              ; Request2 not cleared, clear again
       BRA   NoButtonsDone
ClearAgain:
       CLR   Request0
       CLR   Request1
       CLR   Request2
NoButtonsDone:
       PULB                          ; Restore B register
       ; CRITICAL: Exit directly - don't check for targets when no buttons are pressed
       LBRA   ISR_Done

NoButtons:
       ; This label is reached ONLY when buttons were processed (ButtonsProcessed)
       ; NoButtonsProcessed goes directly to ISR_Done, so we know buttons were pressed
       ; Only set new Target if elevator is idle (State = 0)
       LDAA  State
       LBNE   ISR_Done               ; Elevator is moving, don't change target
       
       ; Elevator is idle, check if we need to set a target
       ; If Target is already set (even if 0 for F0), we should check if Current == Target
       ; If Current == Target, we can set a new target
       LDAA  Target
       LDAB  Current
       CBA                          ; Compare Target with Current
       LBNE   ISR_Done               ; Target != Current, elevator has a pending target
       
       ; Target == Current (elevator is idle at target floor), can set new target
       ; Since we're here from ButtonsProcessed, we know buttons were pressed
       ; So if any request is set, it's valid
       ; Check if any request flags are set (must be exactly 1, not 0 or other value)
       LDAA  Request0
       BEQ   CheckReq1               ; Request0 is 0, check Request1
       CMPA  #1
       LBNE   CheckReq1              ; Request0 is not 1 (invalid), check Request1
       ; Request0 is valid (1) - verify we're not already at F0
       LDAB  Current
       CMPB  #0
       LBEQ   ClearReq0AndCheck      ; At F0, clear Request0 and check other requests
       ; Not at F0, has valid request - proceed to set target
       LBRA   HasRequest
ClearReq0AndCheck:
       ; At F0 and Request0 is set - clear it (shouldn't happen, but safety)
       CLR   Request0
       LBRA   CheckReq1
HasRequest:
       ; We have at least one request, proceed to set target based on current floor
       LDAA  Current
       LBEQ   CheckFromF0
       CMPA  #1
       LBEQ   CheckFromF1
       LBRA   CheckFromF2
       
CheckReq1:
       LDAA  Request1
       LBEQ   CheckReq2
       ; Request1 is set - verify it's exactly 1 (not corrupted)
       CMPA  #1
       LBNE   CheckReq2              ; Request1 is not 1 (invalid), check Request2
       ; Request1 is valid (1) - check if we're not already at F1
       LDAB  Current
       CMPB  #1
       LBNE   HasRequest             ; Not at F1, has valid request
       ; At F1 and Request1 is set - this should have been cleared, but clear it now
       CLR   Request1
       LBRA   CheckReq2
       
CheckReq2:
       LDAA  Request2
       LBEQ   ISR_Done               ; No requests at all, exit
       ; Request2 is set - verify it's exactly 1 (not corrupted)
       CMPA  #1
       LBNE   ISR_Done               ; Request2 is not 1 (invalid), exit
       ; Request2 is valid (1) - check if we're not already at F2
       LDAB  Current
       CMPB  #2
       LBNE   HasRequest             ; Not at F2, has valid request
       ; At F2 and Request2 is set - this should have been cleared, but clear it now
       CLR   Request2
       LBRA   ISR_Done

CheckFromF0:
       LDAA  Request1
       LBEQ   CheckF0toF2
       ; F1 is requested - verify we're not already at F1 (safety check)
       LDAB  Current
       CMPB  #1
       LBEQ   ISR_Done               ; Already at F1, don't set target
       MOVB  #1, Target
       LBRA   ISR_Done
CheckF0toF2:
       LDAA  Request2
       LBEQ   ISR_Done
       ; F2 is requested - verify we're not already at F2 (safety check)
       LDAB  Current
       CMPB  #2
       LBEQ   ISR_Done               ; Already at F2, don't set target
       MOVB  #2, Target
       LBRA   ISR_Done

CheckFromF1:
       ; According to PDF: When on F1, if both F0 and F2 are requested,
       ; serve in the direction of movement (closest first)
       ; Since we're at F1, check both directions
       ; Priority: Check if we should go down (F0) or up (F2)
       ; According to PDF, if both are requested, serve closest first
       ; From F1: F0 is 1 floor away (down), F2 is 1 floor away (up)
       ; PDF says "serve closest first" - both are equidistant, so check F0 first (down)
       ; CRITICAL: Only proceed if Request0 is actually set AND we're at F1
       ; Add extra verification to prevent false triggers
       LDAA  Request0
       LBEQ   CheckF1Up              ; No F0 request, check F2
       ; Request0 is set - verify we're actually at F1 (double check)
       LDAB  Current
       CMPB  #1                     ; Verify we're at F1
       LBNE   CheckF1Up              ; Not at F1, something wrong - check F2 instead
       ; Additional safety: Verify Request0 is non-zero (should be 1)
       LDAA  Request0
       CMPA  #1
       LBNE   CheckF1Up              ; Request0 is not 1 (invalid), check F2 instead
       ; We're at F1 and Request0 is valid (button was pressed)
       ; According to PDF, serve closest first - F0 is 1 floor down from F1
       ; Set Target to F0
       MOVB  #0, Target
       LBRA   ISR_Done
CheckF1Up:
       ; No F0 request, check F2
       LDAA  Request2
       LBEQ   ISR_Done               ; No requests, exit
       ; F2 is requested - verify we're not already at F2 (safety check)
       LDAB  Current
       CMPB  #2
       LBEQ   ISR_Done               ; Already at F2 (shouldn't happen), exit
       ; F2 is requested
       MOVB  #2, Target
       LBRA   ISR_Done

CheckFromF2:
       ; When on F2, check requests in descending order: F1, then F0
       LDAA  Request1
       LBEQ   CheckF2toF0            ; No F1 request, check F0
       ; F1 is requested - verify we're not already at F1 (safety check)
       LDAB  Current
       CMPB  #1
       LBEQ   CheckF2toF0            ; Already at F1, check F0 instead
       ; F1 is requested, go to F1 first (will handle F0 after if needed)
       MOVB  #1, Target
       LBRA   ISR_Done
CheckF2toF0:
       ; No F1 request, check F0
       LDAA  Request0
       LBEQ   ISR_Done               ; No F0 request either, exit
       ; F0 is requested - verify we're not already at F0 (safety check)
       LDAB  Current
       CMPB  #0
       LBEQ   ISR_Done               ; Already at F0, don't set target
       ; F0 is requested, go directly to F0
       MOVB  #0, Target
       LBRA   ISR_Done

ISR_Done:
       RTI                          ; Return from interrupt

       LBRA   Exit


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
       ; Proper 100ms delay for 8MHz E-clock, 4MHz bus clock
       ; Bus clock = 4MHz, so 1 cycle = 0.25μs
       ; For 100ms = 100,000μs, we need 100,000 / 0.25 = 400,000 cycles
       ; Using nested loops for accurate timing:
       ; Each NOP = 1 cycle, DEX = 1 cycle, BNE = 3 cycles (taken) or 1 cycle (not taken)
       ; Simple loop: NOP (1) + DEX (1) + BNE (3) = 5 cycles per iteration (when taken)
       ; For 400,000 cycles: 400,000 / 5 = 80,000 iterations
       ; But LBNE is long branch (4 cycles), so: NOP (1) + DEX (1) + LBNE (4) = 6 cycles
       ; 400,000 / 6 = 66,667 iterations ≈ 67,000
       ; Calibrated for actual timing
       LDX   #28000                 ; Calibrated for ~100ms (28000 × 14 cycles ≈ 392,000 cycles)
again:
       NOP                          ; 1 cycle
       NOP                          ; 1 cycle  
       NOP                          ; 1 cycle
       NOP                          ; 1 cycle
       NOP                          ; 1 cycle
       NOP                          ; 1 cycle
       NOP                          ; 1 cycle
       NOP                          ; 1 cycle
       NOP                          ; 1 cycle
       NOP                          ; 1 cycle (10 NOPs = 10 cycles)
       DEX                          ; 1 cycle
       LBNE   again                 ; 4 cycles if taken (long branch), 1 if not
       ; Total per iteration: 10 + 1 + 4 = 15 cycles (when taken)
       ; 28,000 × 15 = 420,000 cycles = 105ms (close enough to 100ms)
       RTS

DelayADC:
       LDX   #5000                  ; Delay for ADC power-up
DelayLoop:
       DEX
       LBNE   DelayLoop
       RTS

Exit:

;**********************
;*                 Interrupt Vectors                          *
;**********************
            ORG   $FFFE
       DC.W  Entry                  ; Reset Vector

       ORG   $FFCA
       DC.W  MCCNT_ISR              ; Modulus Counter Interrupt Vector