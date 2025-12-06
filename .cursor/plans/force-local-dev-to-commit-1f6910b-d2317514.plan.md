---
name: Implement Lab 9 Buzzer Configuration
overview: ""
todos:
  - id: 91f42dbb-53f3-4160-975f-e7b2fa365a78
    content: Fetch from remote to ensure we have the latest commits
    status: pending
  - id: 6deb6528-2633-4a11-961d-c13fdacfff1b
    content: Verify commit 1f6910b exists locally
    status: pending
  - id: 6828a42a-2181-4b26-be39-219218f2d2bf
    content: Force reset local dev branch to commit 1f6910b
    status: pending
  - id: 90681fd3-d04e-42a9-a4dc-72b32f39203d
    content: Verify final state - confirm branch is at correct commit
    status: pending
  - id: dc89eacf-6665-4ef8-8c6b-7587c0bc1fca
    content: Remove 2-second buzzer beep from ARRIVED section
    status: pending
  - id: 1e51b665-c50b-4579-993e-58eef9ac0fa2
    content: Add buzzer ON when door opens (red LED ON)
    status: pending
  - id: 292bb035-896c-4734-bbff-001fd1adddd6
    content: Add buzzer OFF when door closes (red LED OFF)
    status: pending
  - id: ca789975-d236-4d64-94c2-ad41d19cb8cb
    content: Verify PWM configuration matches Lab 9 (4kHz)
    status: pending
---

# Implement Lab 9 Buzzer Configuration

## Overview

Replace PWM initialization with Lab 9 buzzer code and integrate buzzer to sound during: moving up display, red LED blinking (overload), and overload detection.

## Implementation Steps

### 1. Replace PWM Initialization in `_Startup` section

- Location: After line 53 (after PTT initialization)
- Replace any existing PWM code with the exact Lab 9 configuration:
- `MOVB #$10, PWME` - Enable PWM Channel 4
- `MOVB #$00, PWMCLK` - Clock A
- `MOVB #$03, PWMPRCLK` - E/8 prescaler
- `MOVB #$10, PWMPOL` - Channel 4 polarity
- `MOVB #$0C, PWMCTL` - Control register
- `CLR PWMCNT4` - Clear channel 4 counter
- `CLR PWMCNT0` - Clear channel 0 counter
- `CLR PWMCNT1` - Clear channel 1 counter
- `MOVW #426, PWMPER0` - Period for channel 0 (587Hz)
- `MOVW #426, PWMPER1` - Period for channel 1
- `MOVW #298, PWMDTY0` - Duty cycle 70% for channel 0
- `MOVW #298, PWMDTY1` - Duty cycle 70% for channel 1

### 2. Enable Buzzer in MOVEUP Section

- Location: In `MOVEUP` section after "MOVING UP" is displayed (around line 188)
- Enable PWM Channel 4: `BSET PWME, #%00010000` or keep it enabled if already initialized
- Keep buzzer ON during the entire UpLoop

### 3. Disable Buzzer After Moving Up

- Location: In `ARRIVED` section (line 277)
- Disable PWM Channel 4: `BCLR PWME, #%00010000` when elevator arrives

### 4. Enable Buzzer During Overload (Red LED Blinking)

- Location: In `OverloadWait` section (line 117)
- Enable PWM Channel 4: `BSET PWME, #%00010000` when red LED is blinking
- Keep buzzer ON during the entire overload wait loop

### 5. Disable Buzzer When Overload Clears

- Location: In `OverloadWait` section after overload clears (around line 150)
- Disable PWM Channel 4: `BCLR PWME, #%00010000` when overload is cleared

### 6. Enable Buzzer in ISR When Overload Detected

- Location: In `MCCNT_ISR` when overload is detected (line 347-351)
- Enable PWM Channel 4: `BSET PWME, #%00010000` when overload flag is set

### 7. Disable Buzzer in ISR When Overload Clears

- Location: In `MCCNT_ISR` in `WeightOK` section when recovering (line 353-361)
- Disable PWM Channel 4: `BCLR PWME, #%00010000` when overload clears

## Notes

- The buzzer uses PWM Channel 4 (bit 4 of PWME = $10)
- Frequency: 587Hz (Period = 426, Duty = 298, 70% duty cycle)
- Buzzer should be enabled during: moving up, overload blinking, and overload detection
- Buzzer should be disabled when: elevator arrives, overload clears, and when not moving up