# Design and Implementation of a 3-Floor Elevator Control System Using Freescale HC12 Microcontroller

**Course:** COE324 - Microcontroller Laboratory  
**Project:** Final Project  
**Platform:** Freescale HC12 (MC9S12DT256)  
**Date:** [Insert Date]

---

## Abstract

This report presents the design, implementation, and analysis of a three-floor elevator control system developed for the Freescale HC12 microcontroller platform. The system demonstrates real-time embedded systems programming principles through the integration of multiple hardware peripherals including analog-to-digital conversion (ADC), pulse-width modulation (PWM), serial peripheral interface (SPI), and general-purpose input/output (GPIO) ports. The elevator system features floor navigation, weight-based overload protection, visual and audio feedback mechanisms, and an intelligent priority-based routing algorithm. The implementation utilizes interrupt-driven architecture with a 100ms periodic interrupt for sensor monitoring and button polling. The system successfully demonstrates the application of embedded systems concepts including state machine design, hardware interfacing, and real-time control algorithms.

**Keywords:** Embedded Systems, Microcontroller, HC12, Elevator Control, Real-Time Systems, State Machine

---

## 1. Introduction

### 1.1 Background

Elevator control systems represent a classic application of embedded systems engineering, requiring real-time response, safety-critical operation, and integration of multiple hardware peripherals. Modern elevator systems must handle multiple floor requests, prioritize operations efficiently, and provide user feedback through visual and audio indicators. This project implements a simplified but functionally complete elevator control system on the Freescale HC12 microcontroller platform.

### 1.2 Objectives

The primary objectives of this project are:

1. **System Design**: Develop a complete 3-floor elevator control system with floor navigation capabilities
2. **Hardware Integration**: Interface multiple peripherals including ADC, PWM, SPI, and GPIO
3. **Safety Implementation**: Implement weight-based overload detection and prevention mechanisms
4. **User Interface**: Provide visual (LEDs, LCD) and audio (buzzer) feedback to users
5. **Algorithm Development**: Design and implement an intelligent floor selection algorithm
6. **Real-Time Operation**: Ensure responsive system behavior through interrupt-driven architecture

### 1.3 Scope

This project focuses on the software implementation of elevator control logic using assembly language for the HC12 microcontroller. The system supports three floors (F0, F1, F2), handles both internal and external call buttons, monitors weight through ADC, and provides comprehensive user feedback. The implementation demonstrates embedded systems programming principles including interrupt handling, state machine design, and hardware register manipulation.

---

## 2. System Overview

### 2.1 System Architecture

The elevator control system follows a hierarchical architecture consisting of:

- **Main Control Loop**: Manages high-level state transitions and movement decisions
- **Interrupt Service Routine (ISR)**: Handles periodic tasks including sensor reading and button polling
- **Hardware Abstraction Layer**: Subroutines for LCD, buzzer, and delay operations
- **State Machine**: Defines system states (IDLE, UP, DOWN, OVERLOADED)

### 2.2 Functional Requirements

The system must satisfy the following functional requirements:

1. **Floor Navigation**: Move between three floors (F0, F1, F2) based on user requests
2. **Button Handling**: Process both internal (inside elevator) and external (hallway) call buttons
3. **Overload Detection**: Monitor weight sensor and prevent operation when overloaded
4. **Visual Feedback**: Display current floor and movement status on LCD
5. **LED Indicators**: Use colored LEDs to indicate movement direction and system state
6. **Audio Feedback**: Provide buzzer alerts for door operations and overload conditions
7. **Priority Routing**: Select destination floor based on proximity and request priority

### 2.3 Non-Functional Requirements

- **Real-Time Response**: System must respond to button presses within 100ms
- **Safety**: Overload condition must immediately halt elevator movement
- **Reliability**: System must handle multiple simultaneous requests correctly
- **User Experience**: Clear visual and audio feedback for all operations

---

## 3. Hardware Design

### 3.1 Microcontroller Platform

The system is implemented on the **MC9S12DT256** microcontroller, a member of the Freescale HC12 family with the following specifications:

- **CPU**: 16-bit HCS12 core running at 8MHz (E-clock)
- **Memory**: 256KB Flash, 12KB RAM
- **Peripherals**: 
  - 8-channel 8/10-bit ADC
  - 8-channel PWM module
  - SPI interface
  - Modulus Counter (MCCNT)
  - Multiple GPIO ports

### 3.2 Input Components

#### 3.2.1 Push Buttons (Port A)
- **Configuration**: 6 buttons total (3 internal + 3 external)
- **Port**: PORTA, bits 2-7 (PA2-PA7)
- **Logic**: Active-low with pull-up resistors enabled via PUCR register
- **Mapping**:
  - PA2 (PB4): Internal F0 request
  - PA3 (PB5): Internal F1 request
  - PA4 (PB6): Internal F2 request
  - PA5 (PB7): External F0 request
  - PA6 (PB8): External F1 request
  - PA7 (PB9): External F2 request

#### 3.2.2 Weight Sensor (ADC Channel 5)
- **Type**: Potentiometer-based weight simulation
- **ADC Channel**: Channel 5 (ATD0DR0L)
- **Resolution**: 8-bit (0-255)
- **Threshold**: 125 (overload condition)
- **Configuration**: Single conversion mode, right-justified result

### 3.3 Output Components

#### 3.3.1 LED Indicators (Port T)
- **Green LED (PT7)**: Indicates upward movement
- **Yellow LED (PT6)**: Indicates downward movement
- **Red LED (PT5)**: Indicates arrival or overload condition
- **Configuration**: Output mode via DDRT register, active-high logic

#### 3.3.2 Buzzer (PWM Channel 4)
- **Port**: Port P, Pin 4 (PP4)
- **PWM Channel**: Channel 4
- **Frequency**: ~587Hz (period = 250 clock cycles, prescaler = E/8)
- **Duty Cycle**: 50% (125/250)
- **Control**: Enabled/disabled via PWME register

#### 3.3.3 LCD Display (SPI Interface)
- **Type**: HD44780-compatible 16x2 character LCD
- **Interface**: SPI (Serial Peripheral Interface)
- **Port**: Port M (SPI data lines)
- **Configuration**: Master mode, CPOL=1, CPHA=0
- **Display Modes**: 
  - Current floor (F0, F1, F2)
  - Movement status (MOVING UP:, MOVING DOWN:)
  - Overload warning (OVERLOAD)

### 3.4 Interrupt System

#### 3.4.1 Modulus Counter (MCCNT)
- **Purpose**: Generate periodic interrupts for system monitoring
- **Period**: 100ms (6250 clock cycles at 8MHz with prescaler)
- **Interrupt Vector**: $FFCA
- **Function**: Triggers ISR for ADC reading and button polling

---

## 4. Software Architecture

### 4.1 Program Structure

The software is organized into the following sections:

1. **Initialization Section**: Hardware setup and variable initialization
2. **Main Loop**: Primary control logic and state management
3. **Interrupt Service Routine**: Periodic sensor reading and button handling
4. **Movement Routines**: Up and down movement control
5. **Subroutines**: LCD, buzzer, and delay functions

### 4.2 Memory Organization

```
ROMStart: $4000          ; Code section start
RAMStart: (from derivative.inc)  ; Variable section

Variables:
- Current:    Current floor (0, 1, or 2)
- Target:     Target floor (0, 1, 2, or 3 for idle)
- State:      System state (0=idle, 1=up, 2=down, 3=overload)
- ADCValue:   Latest ADC reading
- Overload:   Overload flag (0=normal, 1=overloaded)
- Request0-2: Floor request flags
- BlinkCount: LED blink counter
```

### 4.3 State Machine Design

The system operates as a finite state machine with four primary states:

#### State 0: IDLE
- **Description**: Waiting for floor requests
- **Actions**: Monitor buttons, select target floor
- **Transitions**: 
  - → State 1 (UP): When target > current
  - → State 2 (DOWN): When target < current
  - → State 3 (OVERLOADED): When weight exceeds threshold

#### State 1: MOVING UP
- **Description**: Elevator moving upward
- **Actions**: 
  - Blink green LED
  - Display "MOVING UP:" on LCD
  - Increment current floor counter
- **Transitions**:
  - → State 0 (IDLE): When current == target
  - → State 3 (OVERLOADED): If overload detected

#### State 2: MOVING DOWN
- **Description**: Elevator moving downward
- **Actions**:
  - Blink yellow LED
  - Display "MOVING DOWN:" on LCD
  - Decrement current floor counter
- **Transitions**:
  - → State 0 (IDLE): When current == target
  - → State 3 (OVERLOADED): If overload detected

#### State 3: OVERLOADED
- **Description**: Weight limit exceeded
- **Actions**:
  - Blink red LED and buzzer
  - Display "OVERLOAD" on LCD
  - Prevent all movement
- **Transitions**:
  - → State 0 (IDLE): When weight returns to normal

### 4.4 Priority Algorithm

The system implements a proximity-based priority algorithm for floor selection:

**From Floor 0 (F0):**
- Priority 1: Floor 1 (if requested)
- Priority 2: Floor 2 (if requested)

**From Floor 1 (F1):**
- Priority 1: Closest requested floor (F0 or F2)
- If both requested: Serve F0 first (downward priority)

**From Floor 2 (F2):**
- Priority 1: Floor 1 (if requested)
- Priority 2: Floor 0 (if requested)

This algorithm minimizes travel distance and provides efficient service to multiple requests.

---

## 5. Implementation Details

### 5.1 Initialization Sequence

The system initialization follows this sequence:

1. **Stack Pointer Setup**: Initialize stack to RAMEnd+1
2. **Variable Initialization**: Clear all state variables, set initial floor to F0
3. **Port Configuration**:
   - Port A: Input mode for buttons
   - Port T: Output mode for LEDs
   - Port P: Output mode for buzzer
   - Port M: SPI interface configuration
4. **PWM Initialization**: Configure buzzer PWM channel
5. **ADC Initialization**: Setup ADC for weight sensor reading
6. **MCCNT Setup**: Configure modulus counter for 100ms interrupts
7. **SPI Configuration**: Setup SPI for LCD communication
8. **LCD Initialization**: Send initialization commands to LCD

### 5.2 Main Control Loop

The main loop implements the following logic:

```assembly
MainLoop:
1. Check overload condition
   - If overloaded → goto OverloadWait
2. Check if target is set (Target != 3)
   - If no target → loop back
3. Compare current and target floors
   - If equal → clear target, loop back
   - If target > current → goto MOVEUP
   - If target < current → goto MOVEDOWN
```

### 5.3 Interrupt Service Routine (MCCNT_ISR)

The ISR executes every 100ms and performs:

1. **ADC Reading**:
   - Trigger ADC conversion on channel 5
   - Wait for conversion complete
   - Read result and store in ADCValue
   - Compare with threshold (125)
   - Set/clear Overload flag

2. **Button Polling**:
   - Read PORTA register
   - Invert logic (active-low)
   - Check each button bit
   - Set corresponding Request flag

3. **Target Selection**:
   - If target is idle (Target == 3)
   - Based on current floor, select highest priority requested floor
   - Set Target variable

### 5.4 Movement Routines

#### 5.4.1 MOVEUP Routine
1. Set State = 1
2. Play door closing beep (long beep)
3. Display "MOVING UP:" on LCD
4. Loop:
   - Blink green LED (10 cycles)
   - Increment Current floor
   - Check if arrived at target
   - If not, repeat loop
5. When arrived → goto ARRIVED

#### 5.4.2 MOVEDOWN Routine
1. Set State = 2
2. Play door closing beep (long beep)
3. Display "MOVING DOWN:" on LCD
4. Loop:
   - Blink yellow LED (10 cycles)
   - Decrement Current floor
   - Check if arrived at target
   - If not, repeat loop
5. When arrived → goto ARRIVED

#### 5.4.3 ARRIVED Routine
1. Turn off movement LEDs
2. Turn on red LED and buzzer (door open signal)
3. Wait for door open delay (2 seconds)
4. Update LCD with current floor
5. Clear request for current floor
6. Reset Target and State
7. Turn off red LED and buzzer
8. Return to MainLoop

### 5.5 Overload Handling

The overload handling routine (OverloadWait) performs:

1. Display "OVERLOAD" message on LCD
2. Blink red LED and buzzer synchronously
3. Continuously check Overload flag
4. When weight normalizes:
   - Turn off red LED and buzzer
   - Clear overload state
   - Restore normal floor display
   - Return to MainLoop

### 5.6 Buzzer Control

The buzzer system provides three distinct audio signals:

1. **Door Closing Beep**: Long beep (~2 seconds) before movement
2. **Arrival Signal**: Buzzer ON with red LED when door opens
3. **Overload Warning**: Synchronized blinking with red LED

PWM Configuration:
- Period: 250 clock cycles (~587Hz)
- Duty Cycle: 50% (125/250)
- Prescaler: E/8 (1MHz clock)

### 5.7 LCD Communication

LCD communication uses SPI interface with the following protocol:

1. **Instruction Mode**: RS=0, sends control commands
2. **Data Mode**: RS=1, sends character data
3. **4-bit Mode**: Data sent in two 4-bit nibbles
4. **Timing**: Delay between commands for LCD processing

Key LCD operations:
- Clear display
- Set cursor position
- Send character data
- Display status messages

---

## 6. Testing and Results

### 6.1 Test Scenarios

#### Test 1: Basic Floor Navigation
**Objective**: Verify elevator moves correctly between floors

**Procedure**:
1. Start at F0
2. Press button for F2
3. Observe movement sequence

**Expected Results**:
- Green LED blinks during upward movement
- LCD displays "MOVING UP:"
- Elevator arrives at F2
- Red LED and buzzer activate on arrival
- LCD displays "F2"

**Result**: ✅ **PASS** - All expected behaviors observed

#### Test 2: Priority Algorithm
**Objective**: Verify floor selection prioritizes closest floor

**Procedure**:
1. Start at F0
2. Press buttons for both F1 and F2
3. Observe which floor is served first

**Expected Results**:
- Elevator serves F1 first (closer)
- Then proceeds to F2

**Result**: ✅ **PASS** - Priority algorithm functions correctly

#### Test 3: Overload Detection
**Objective**: Verify overload protection prevents movement

**Procedure**:
1. Set weight sensor above threshold (125)
2. Attempt to request floor
3. Observe system response

**Expected Results**:
- Red LED blinks
- Buzzer sounds
- LCD displays "OVERLOAD"
- Elevator does not move
- When weight reduced, system returns to normal

**Result**: ✅ **PASS** - Overload protection works as designed

#### Test 4: Button Handling
**Objective**: Verify both internal and external buttons function

**Procedure**:
1. Test each internal button (PA2-PA4)
2. Test each external button (PA5-PA7)
3. Verify requests are registered

**Expected Results**:
- All buttons register requests correctly
- No false triggers observed

**Result**: ✅ **PASS** - All buttons function correctly

#### Test 5: Simultaneous Requests
**Objective**: Verify system handles multiple requests correctly

**Procedure**:
1. Press multiple floor buttons
2. Observe elevator serves requests in priority order

**Expected Results**:
- System queues requests
- Serves floors based on priority algorithm
- Clears requests after service

**Result**: ✅ **PASS** - Multiple requests handled correctly

### 6.2 Performance Metrics

- **Interrupt Response Time**: < 100ms (deterministic)
- **Button Response Time**: < 100ms (polled in ISR)
- **Overload Detection Time**: < 100ms (checked every interrupt)
- **LCD Update Time**: ~50ms per character
- **Movement Simulation**: 10 blink cycles per floor (~2 seconds)

### 6.3 System Limitations

1. **No Emergency Stop**: System lacks emergency stop functionality
2. **Fixed Timing**: Movement timing is fixed, not based on actual position
3. **Simple Priority**: Priority algorithm is basic; could be enhanced
4. **No Door Sensor**: Door open/close is simulated with delays
5. **Single Elevator**: System designed for single elevator only

---

## 7. Discussion

### 7.1 Design Decisions

#### 7.1.1 Interrupt-Driven Architecture
The choice to use periodic interrupts (MCCNT) rather than polling in the main loop provides several advantages:
- **Deterministic Timing**: Sensor readings occur at fixed intervals
- **Efficiency**: Main loop can focus on high-level control
- **Responsiveness**: Button presses detected within 100ms

#### 7.1.2 State Machine Design
The state machine approach provides:
- **Clear Logic Flow**: Easy to understand and debug
- **Predictable Behavior**: Each state has well-defined transitions
- **Maintainability**: Easy to add new states or modify behavior

#### 7.1.3 Assembly Language Implementation
Using assembly language offers:
- **Direct Hardware Control**: Precise register manipulation
- **Performance**: No compiler overhead
- **Educational Value**: Deep understanding of microcontroller operation

### 7.2 Challenges Encountered

1. **Timing Synchronization**: Coordinating LED blinking, buzzer, and LCD updates required careful delay management
2. **Button Debouncing**: Active-low logic with pull-up resistors required proper inversion
3. **LCD Communication**: SPI protocol implementation required understanding of 4-bit mode
4. **State Management**: Ensuring state transitions occur correctly without conflicts
5. **Overload Recovery**: Properly clearing overload state when weight normalizes

### 7.3 Future Enhancements

Potential improvements to the system:

1. **Emergency Stop Button**: Add hardware emergency stop functionality
2. **Position Feedback**: Integrate encoder or position sensor for accurate floor detection
3. **Advanced Scheduling**: Implement SCAN or LOOK algorithms for multiple requests
4. **Door Control**: Add actual door motor control with position feedback
5. **Display Enhancements**: Show queue of pending requests on LCD
6. **Energy Efficiency**: Implement power-saving modes during idle periods
7. **Multi-Elevator Support**: Extend to control multiple elevators
8. **Network Communication**: Add serial communication for remote monitoring

### 7.4 Educational Value

This project successfully demonstrates:

- **Embedded Systems Concepts**: Real-time control, interrupt handling, hardware interfacing
- **Microcontroller Programming**: Direct register manipulation, peripheral configuration
- **System Design**: State machines, modular programming, algorithm design
- **Hardware Integration**: Multiple peripheral interfaces (ADC, PWM, SPI, GPIO)
- **Safety Engineering**: Overload protection, state validation

---

## 8. Conclusion

This project successfully implements a functional 3-floor elevator control system on the Freescale HC12 microcontroller platform. The system demonstrates proficiency in embedded systems programming through the integration of multiple hardware peripherals, implementation of a state machine-based control algorithm, and development of safety mechanisms including overload protection.

Key achievements include:

1. **Complete System Integration**: Successfully interfaced ADC, PWM, SPI, and GPIO peripherals
2. **Robust Control Logic**: Implemented reliable state machine with proper transitions
3. **User Interface**: Provided comprehensive visual and audio feedback
4. **Safety Features**: Implemented weight-based overload detection and prevention
5. **Efficient Algorithm**: Developed priority-based floor selection algorithm

The system meets all specified functional requirements and demonstrates the application of fundamental embedded systems engineering principles. The interrupt-driven architecture ensures responsive operation, while the state machine design provides clear and maintainable code structure.

This project serves as an excellent example of real-world embedded systems application, combining hardware interfacing, real-time control, and user interface design in a cohesive system.

---

## 9. References

1. Freescale Semiconductor. (2005). *MC9S12DT256 Device User Guide*. NXP Semiconductors.

2. Freescale Semiconductor. (2003). *HCS12 Microcontrollers Reference Manual*. NXP Semiconductors.

3. Hitachi. (1999). *HD44780U (LCD-II) Dot Matrix Liquid Crystal Display Controller/Driver Datasheet*.

4. CodeWarrior Development Studio for HC12/S12(X) V5.1 User Guide. (2007). Freescale Semiconductor.

5. Mazidi, M. A., & Mazidi, J. G. (2006). *The 8051 Microcontroller and Embedded Systems Using Assembly and C*. Pearson Education.

6. Valvano, J. W. (2011). *Embedded Systems: Introduction to ARM Cortex-M Microcontrollers*. Jonathan Valvano.

7. LaMothe, A. (2003). *Tricks of the Windows Game Programming Gurus*. Sams Publishing.

---

## Appendix A: Code Structure

### A.1 Main Program Flow

```
Entry → Initialization → MainLoop
                              ↓
                    ┌─────────┴─────────┐
                    ↓                 ↓
            OverloadWait         Movement Check
                    ↓                 ↓
            (Handle Overload)    MOVEUP/MOVEDOWN
                                        ↓
                                   ARRIVED
                                        ↓
                                   MainLoop
```

### A.2 Interrupt Flow

```
MCCNT_ISR (every 100ms)
    ↓
Read ADC → Check Overload
    ↓
Poll Buttons → Set Requests
    ↓
Select Target (if idle)
    ↓
RTI
```

### A.3 Key Subroutines

- `init_PWM_Buzzer`: Initialize PWM for buzzer control
- `Buzz`: Enable buzzer (set PWME bit)
- `StopBuzz`: Disable buzzer (clear PWME bit)
- `DoorCloseBeep`: Play long beep before movement
- `SENDINST`: Send instruction to LCD
- `SENDDATA`: Send data character to LCD
- `SENDSPI`: Low-level SPI transmission
- `DELAY`: Software delay loop
- `DelayADC`: Delay for ADC stabilization

---

## Appendix B: Hardware Connections

### B.1 Port Mapping Summary

| Port | Pin | Function | Direction |
|------|-----|----------|-----------|
| A    | 2   | Internal F0 Button | Input |
| A    | 3   | Internal F1 Button | Input |
| A    | 4   | Internal F2 Button | Input |
| A    | 5   | External F0 Button | Input |
| A    | 6   | External F1 Button | Input |
| A    | 7   | External F2 Button | Input |
| T    | 5   | Red LED | Output |
| T    | 6   | Yellow LED | Output |
| T    | 7   | Green LED | Output |
| P    | 4   | Buzzer (PWM) | Output |
| M    | -   | SPI Interface (LCD) | Output |
| ADC  | 5   | Weight Sensor | Input |

### B.2 Register Configuration Summary

**Port A (Buttons)**:
- DDRA = $00 (all inputs)
- PUCR = $02 (pull-up enabled)

**Port T (LEDs)**:
- DDRT = %11100000 (PT5-PT7 outputs)
- PTT = %00000000 (all LEDs off initially)

**PWM (Buzzer)**:
- PWMPRCLK = $03 (prescaler E/8)
- PWMPER4 = 250 (period)
- PWMDTY4 = 125 (duty cycle 50%)
- PWME bit 4 = enable/disable

**ADC (Weight Sensor)**:
- ATD0CTL2 = %11000000 (enable, fast flag clear)
- ATD0CTL3 = %00001000 (single conversion)
- ATD0CTL4 = %10000101 (8-bit, prescaler)
- ATD0CTL5 = %10100101 (channel 5, right-justified)

**SPI (LCD)**:
- SPI0CR1 = $52 (master mode, CPOL=1, CPHA=0)
- SPI0CR2 = $10 (mode fault enable)
- SPI0BR = $00 (baud rate)

**MCCNT (Interrupt)**:
- MCCTL = %11000111 (enable, interrupt enable)
- MCCNT = 6250 (100ms period)

---

## Appendix C: State Transition Diagram

```
        [IDLE]
         /  |  \
        /   |   \
       /    |    \
      /     |     \
     /      |      \
    /       |       \
[UP]    [DOWN]  [OVERLOADED]
  |       |          |
  |       |          |
  └───→ [ARRIVED] ←──┘
         |
         └──→ [IDLE]
```

**Legend**:
- Solid arrows: Normal transitions
- Dashed arrows: Overload transitions
- [ARRIVED] is a temporary state that always returns to [IDLE]

---

**End of Report**

