# Retrofit IoT Water Bottle Tracker

This repository contains the code and documentation for a compact, retrofit IoT device that transforms any conventional water bottle into a smart hydration tracker. By integrating a load cell, IMU, BLE communication, and HealthKit APIs, this system dynamically measures water volume, correlates intake with exercise data, and provides personalised daily hydration goals and reminders.


## License and Contributions
This project is licensed under the [Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)](https://creativecommons.org/licenses/by-nc/4.0/) license.

**Key points:**
- **Attribution Required:** You must give appropriate credit to the original author(s) and clearly indicate any changes made.
- **Non-Commercial:** You may not use the material for commercial purposes.
- **No Additional Restrictions:** You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.


Contributions are welcome! Feel free to open issues, suggest features, or submit pull requests. 

**Acknowledgement:** Large Language Models (LLMs) such as ChatGPT (GPT-4), Sonnet 3.5, and related tools were used to assist with syntax, code snippet generation, and refining implementations. These tools helped streamline development, clarify code logic, and improve documentation quality.

## Key Features

- **External Sensing for Water Volume:**  
  Attaches to any bottle’s base. A load cell sensor and calibration logic convert weight into volume (1 g ≈ 1 mL).
  
- **IMU-Based Stability Checks:**  
  Uses an onboard 6-axis IMU to ensure accurate measurements only when the bottle is upright and stable.
  
- **BLE Connectivity:**  
  Communicates with an iOS application in real-time via Bluetooth Low Energy. Sensor data, state machine updates, and commands are all exchanged wirelessly.

- **HealthKit Integration:**  
  Dynamically adjusts daily hydration goals based on the user’s personal health metrics (height, weight, age) and exercise time sourced from Apple Watch via HealthKit.

- **User-Centred UI/UX:**  
  The accompanying iOS app displays daily intake progress, water levels, and allows manual entry of off-bottle consumption. Day/week data views and statistical insights help users understand and improve their hydration habits.

- **Actuation and Interventions:**  
  Sends notifications if no water intake is logged within an hour, prompting the user to drink or refill. On-board LED indicators reflect device states and assist in debugging.

## Repository Structure

- **/Arduino**  
  Contains Arduino/C++ source code for the SeeedStudio XIAO nrf52840 Sense board. This includes:
  - Load cell sensor calibration and reading code.
  - IMU data collection and stability logic.
  - BLE services and characteristics for data transmission.
  - State machine logic for IDLE → AWAKE → ACTIVE → REFILL states.
 - The final final code for the entire project is in BottleHousingv1.ino

- **/AppFiles**  
  Swift/SwiftUI code for the iOS application:
  - BLEManager implementation for scanning, connecting, and receiving data from the device.
  - Views for daily/weekly intake data, goal calculation, and user interactions.
  - Integration with HealthKit to fetch activity and body metrics.
  - Notification scheduling for hydration reminders.

- **/3d_printed_housing**  
  CAD files and STL models of the custom 3D-printed housing designed to fit the sensor assembly onto various bottles.

- **/RawSensorDataPlots**  
  Sample CSV data (IMU and scale readings), calibration logs, and scripts/notebooks for offline data analysis and plotting.

- **/AppFiles/AppScreenshots**  
  All screenshots of app features and screens. 

## Getting Started

1. **Hardware Setup:**
   - Assemble the load cell (MUS) and connect it to the XIAO Sense board as per the wiring diagrams.
   - Modify the housing onto your chosen bottle, ensuring minimal interference and stable contact.
   
2. **Firmware Upload:**
   - Install the Arduino IDE and required board packages.
   - Open `ArduinoSketches/BottleHousingv1` in Arduino IDE.
   - Update any BLE UUIDs, gap values, or thresholds if needed.
   - Upload the code to the XIAO nrf52840 Sense board.

3. **iOS App Setup:**
   - Open `AppFiles/SmartWaterTracker` project in Xcode.
   - Connect an iOS device with BLE and HealthKit access.
   - Build and run the app on your device.
   - Grant necessary HealthKit permissions and pair with the IoT device.

4. **Calibration and Tuning:**
   - Use the app’s calibration function (tare) to set the empty bottle weight.
   - Perform test readings and compare to known reference weights to fine-tune the gap value if necessary.

## Dependencies and Requirements

- **Hardware:**
  - SeeedStudio XIAO nrf52840 Sense microcontroller.
  - M5Stack mini unit scale (MUS) or compatible load cell assembly.
  - BLE-compatible iOS device (iPhone/iPad running iOS 14+).
  
- **Software:**
  - Arduino IDE (v1.8.13 or newer).
  - Xcode (for iOS development).
  - Swift 5.0+ and iOS 14+ SDK.
  - HealthKit and Core Bluetooth frameworks.




## Contact and Support

For questions, issues, or support, please contact [ab4421@ic.ac.uk] or open an issue in this repository.

---
**Stay Hydrated!** This project aims to encourage healthier habits through unobtrusive IoT interventions and personalised guidance.
