# 3-Stage Elevator Control System

A microcontroller-based elevator control system implemented on the Freescale HC12 (MC9S12DT256) platform. This project demonstrates real-time embedded systems programming with multi-floor elevator control, weight sensing, LCD display, and audio feedback.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Hardware Components](#hardware-components)
- [Technologies Used](#technologies-used)
- [Project Structure](#project-structure)
- [System Architecture](#system-architecture)
- [Installation & Setup](#installation--setup)
- [Usage](#usage)
- [Functionality](#functionality)
- [Development Environment](#development-environment)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

This project implements a complete 3-floor elevator control system with the following capabilities:

- **3-Floor Navigation**: Ground floor (F0), First floor (F1), and Second floor (F2)
- **Button Input System**: Internal and external call buttons for each floor
- **Weight Sensing**: Overload detection using ADC to prevent operation when overloaded
- **Visual Feedback**: RGB LED indicators (Green for up, Yellow for down, Red for arrival/overload)
- **Audio Feedback**: PWM-based buzzer system for door operations and alerts
- **LCD Display**: Real-time status display showing current floor and elevator state
- **Priority-Based Routing**: Intelligent floor selection based on proximity

## ✨ Features

### Core Functionality
- ✅ Multi-floor elevator control (F0, F1, F2)
- ✅ Internal and external call buttons
- ✅ Weight-based overload protection
- ✅ Visual status indicators (LEDs)
- ✅ Audio feedback (buzzer)
- ✅ LCD status display
- ✅ Priority-based floor selection
- ✅ Door open/close simulation with buzzer

### Safety Features
- ⚠️ Overload detection and prevention
- ⚠️ Visual and audio overload warnings
- ⚠️ State management to prevent conflicts

## 🔧 Hardware Components

### Microcontroller
- **MC9S12DT256** (Freescale HC12 family)
  - 16-bit CPU
  - 256KB Flash memory
  - 12KB RAM
  - Multiple PWM channels
  - ADC (Analog-to-Digital Converter)
  - SPI interface
  - Modulus Counter (MCCNT)

### Input Components
- **Push Buttons** (Port A)
  - 6 buttons total (3 internal + 3 external)
  - PA2-PA7: Button inputs with pull-up resistors
  - Active-low logic

- **Weight Sensor** (ADC Channel 5)
  - Potentiometer-based weight simulation
  - Threshold: 125 (8-bit ADC value)
  - Overload detection

### Output Components
- **LEDs** (Port T)
  - PT7: Green LED (Moving Up indicator)
  - PT6: Yellow LED (Moving Down indicator)
  - PT5: Red LED (Arrival/Overload indicator)

- **Buzzer** (PWM Channel 4, Port P)
  - Piezo buzzer
  - PWM frequency: ~587Hz (1ms period)
  - Duty cycle: 50%
  - Port P Pin 4 (PP4)

- **LCD Display** (SPI via Port M)
  - HD44780-compatible LCD
  - 16x2 character display
  - SPI communication interface
  - Port M: SPI data lines

### Development Board
- **LAU HC12 LAB BOARD** or compatible
- **Programmer**: P&E Multilink USB or CyclonePro USB

## 💻 Technologies Used

### Programming Languages
- **Assembly Language (HC12)**
  - Freescale HC12 instruction set
  - Absolute assembly format
  - Direct hardware register manipulation

### Development Tools
- **CodeWarrior for HC12**
  - IDE for Freescale microcontrollers
  - Assembler and linker
  - Debugger support
  - Project management

### Hardware Interfaces
- **PWM (Pulse Width Modulation)**
  - Channel 4 for buzzer control
  - 8-bit resolution
  - E/8 prescaler (1MHz clock)
  - Configurable period and duty cycle

- **ADC (Analog-to-Digital Converter)**
  - 8-bit resolution
  - Channel 5 for weight sensor
  - Single conversion mode

- **SPI (Serial Peripheral Interface)**
  - Master mode
  - CPOL=1, CPHA=0
  - LCD communication

- **MCCNT (Modulus Counter)**
  - Periodic interrupt (100ms)
  - Button polling
  - Weight sensor monitoring

- **GPIO (General Purpose I/O)**
  - Port A: Button inputs
  - Port T: LED outputs
  - Port P: Buzzer output
  - Port M: SPI interface

## 📁 Project Structure

```
Final Project/
├── Project/
│   ├── Sources/
│   │   ├── main.asm              # Main elevator control program
│   │   ├── main_optimized.asm    # Optimized version (alternative)
│   │   └── derivative.inc        # MC9S12DT256 register definitions
│   ├── bin/                      # Compiled output files
│   │   ├── Project.abs           # Absolute binary
│   │   ├── Project.abs.s19       # S19 hex file for programming
│   │   └── main.dbg              # Debug symbols
│   ├── cmd/                      # Programming command files
│   ├── Project_Data/             # IDE project data
│   ├── prm/                      # Linker parameter files
│   └── Project.mcp               # CodeWarrior project file
├── README.md                     # This file
└── .gitignore                    # Git ignore rules
```

## 🏗️ System Architecture

### State Machine
The elevator operates using a state machine with the following states:

1. **IDLE (State = 0)**: Waiting for floor requests
2. **UP (State = 1)**: Moving upward
3. **DOWN (State = 2)**: Moving downward
4. **OVERLOADED (State = 3)**: Weight limit exceeded

### Main Components

#### Main Loop
- Checks for overload condition
- Evaluates target floor
- Determines movement direction
- Manages state transitions

#### Interrupt Service Routine (MCCNT_ISR)
- Runs every 100ms
- Reads weight sensor (ADC)
- Detects overload condition
- Polls button inputs
- Sets target floor based on priority

#### Movement Routines
- **MOVEUP**: Handles upward movement with green LED blinking
- **MOVEDOWN**: Handles downward movement with yellow LED blinking
- **ARRIVED**: Handles arrival sequence with red LED and buzzer

#### Overload Handling
- **OverloadWait**: Blinks red LED and buzzer when overloaded
- Prevents elevator movement during overload
- Clears when weight returns to normal

### Priority Algorithm
When multiple floors are requested:
- From F0: Serve F1 before F2
- From F1: Serve closest floor first (F0 or F2)
- From F2: Serve F1 before F0

## 🚀 Installation & Setup

### Prerequisites
1. **CodeWarrior for HC12** (v5.x or compatible)
2. **HC12 Development Board** (LAU HC12 LAB BOARD or compatible)
3. **Programmer**: P&E Multilink USB or CyclonePro USB
4. **Hardware Components**: LEDs, buttons, buzzer, LCD, weight sensor

### Building the Project

1. **Open Project**
   ```bash
   # Open Project.mcp in CodeWarrior IDE
   ```

2. **Configure Target**
   - Select target: MC9S12DT256
   - Set clock frequency: 8MHz (E-clock)
   - Configure memory map

3. **Build Project**
   - Build → Build All (or F7)
   - Verify no compilation errors
   - Check for Unicode character issues (use ASCII spaces only)

4. **Program Device**
   - Connect programmer to board
   - Use appropriate .cmd file from `cmd/` directory
   - Load `Project.abs.s19` to microcontroller

### Hardware Connections

#### LEDs (Port T)
- PT7 → Green LED → Resistor → GND
- PT6 → Yellow LED → Resistor → GND
- PT5 → Red LED → Resistor → GND

#### Buttons (Port A)
- PA2 → Internal F0 button → GND
- PA3 → Internal F1 button → GND
- PA4 → Internal F2 button → GND
- PA5 → External F0 button → GND
- PA6 → External F1 button → GND
- PA7 → External F2 button → GND

#### Buzzer (Port P)
- PP4 → Buzzer positive terminal
- Buzzer negative → GND

#### LCD (Port M via SPI)
- SPI MOSI → LCD data line
- SPI SCK → LCD clock line
- SPI SS → LCD enable/select

#### Weight Sensor (ADC)
- ADC Channel 5 → Potentiometer wiper
- Potentiometer ends → Vref and GND

## 📖 Usage

### Normal Operation

1. **Power On**: System initializes at F0 (Ground floor)
2. **Request Floor**: Press internal or external button for desired floor
3. **Elevator Moves**: 
   - Green LED blinks when moving up
   - Yellow LED blinks when moving down
   - Buzzer sounds during door close (before movement)
4. **Arrival**: 
   - Red LED turns on
   - Buzzer sounds
   - LCD displays current floor
   - Door opens (red LED + buzzer ON)
   - Door closes (red LED + buzzer OFF)

### Overload Scenario

1. **Overload Detected**: Weight exceeds threshold (125)
2. **Warning**: Red LED blinks, buzzer sounds
3. **LCD Display**: Shows "OVERLOAD" message
4. **Movement Blocked**: Elevator cannot move until weight is reduced
5. **Recovery**: When weight normalizes, system returns to normal operation

### Button Functions

- **Internal Buttons** (PA2-PA4): Call elevator from inside
- **External Buttons** (PA5-PA7): Call elevator from outside

## 🔍 Functionality Details

### Buzzer Operation
- **Door Close**: Long beep before movement (2 seconds)
- **Arrival**: Buzzer ON with red LED when door opens
- **Overload**: Buzzer synchronized with red LED blinking
- **Frequency**: ~587Hz (1ms period, 50% duty cycle)

### LCD Display
- **Normal**: Shows "F0", "F1", or "F2" (current floor)
- **Moving**: Shows "MOVING UP:" or "MOVING DOWN:"
- **Overload**: Shows "OVERLOAD"

### LED Indicators
- **Green (PT7)**: Blinks during upward movement
- **Yellow (PT6)**: Blinks during downward movement
- **Red (PT5)**: 
  - Solid ON: Arrival (door open)
  - Blinking: Overload warning

## 🛠️ Development Environment

### CodeWarrior Settings
- **Target**: MC9S12DT256
- **Assembler**: HC12 Assembler
- **Linker**: HC12 Linker
- **Memory Model**: Absolute addressing
- **Code Start**: $4000
- **RAM Start**: As defined in derivative.inc

### Important Notes

⚠️ **Unicode Character Warning**: 
- CodeWarrior does not support Unicode characters
- Use only ASCII spaces (0x20), not non-breaking spaces (NBSP - 0xC2A0)
- If you see "illegal character" errors, check for hidden Unicode characters
- Recommended: Use a text editor that shows hidden characters

### Debugging
- Use CodeWarrior debugger
- Set breakpoints in main loop and ISR
- Monitor registers and memory
- Use simulator for initial testing

## 🤝 Contributing

This is a university project. Contributions are welcome for:
- Bug fixes
- Code optimization
- Documentation improvements
- Feature enhancements

### Code Style
- Use consistent indentation (spaces, not tabs)
- Add comments for complex logic
- Follow HC12 assembly conventions
- Keep subroutines modular

## 📄 License

This project is created for educational purposes as part of the MCO (Microcontroller) Lab course.

## 👥 Authors

- **Rawad** - Initial implementation and development

## 🙏 Acknowledgments

- Freescale (now NXP) for HC12 microcontroller documentation
- CodeWarrior IDE development team
- LAU (Lebanese American University) MCO Lab instructors

## 📚 References

- MC9S12DT256 Reference Manual
- HC12 Instruction Set Reference
- CodeWarrior for HC12 User Guide
- HD44780 LCD Controller Datasheet

---

**Note**: This project is designed for educational purposes and demonstrates embedded systems programming concepts. For production use, additional safety features and certifications would be required.

