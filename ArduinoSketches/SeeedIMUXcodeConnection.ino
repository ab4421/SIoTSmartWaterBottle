#include <Wire.h>
#include <ArduinoBLE.h>
#include "LSM6DS3.h"
#include "UNIT_SCALES.h"

// IMU and BLE configuration
LSM6DS3 myIMU(I2C_MODE, 0x6A); // I2C address for IMU
BLEService imuService("12345678-1234-5678-1234-56789abcdef0");
BLECharacteristic accelCharacteristic("12345678-1234-5678-1234-56789abcdef1", BLENotify, 20);
BLECharacteristic gyroCharacteristic("12345678-1234-5678-1234-56789abcdef2", BLENotify, 20);
BLECharacteristic scaleCharacteristic("12345678-1234-5678-1234-56789abcdef3", BLENotify, 20);
BLECharacteristic uprightCharacteristic("12345678-1234-5678-1234-56789abcdef4", BLENotify, 20);
BLECharacteristic calibrateCharacteristic("12345678-1234-5678-1234-56789abcdef5", BLEWrite, 1); // For calibration command

// Mini Scale configuration
UNIT_SCALES scales;
float gap = 183.3;  // Replace with your calibrated gap value

// State management
enum State {
    IDLE_STATE,
    AWAKE_STATE,
    ACTIVE_STATE
};

State currentState = IDLE_STATE;
unsigned long stateStartTime = 0;
unsigned long awakeTimeout = 30000;  // 30 seconds timeout for AWAKE_STATE

#define SIGNIFICANT_MOVEMENT_THRESHOLD 0.2  // Adjust as needed
#define STABILITY_THRESHOLD 0.02            // Adjust as needed
#define SIGNIFICANT_VOLUME_CHANGE 5.0       // in mL, adjust as needed

// Variables for IMU data
float accelX = 0, accelY = 0, accelZ = 0;
float gyroX = 0, gyroY = 0, gyroZ = 0;
float prevAccelX_move = 0, prevAccelY_move = 0, prevAccelZ_move = 0;
float prevAccelX_stable = 0, prevAccelY_stable = 0, prevAccelZ_stable = 0;

// Variables for volume tracking
float previousVolume = 0;

// Calibration flag
bool calibrationOccurred = false;

// Define LED pin mappings (using onboard LEDs)
#define LED_RED   LED_BUILTIN   // Red LED
#define LED_GREEN LED_GREEN  // Green LED
#define LED_BLUE  LED_BLUE   // Blue LED

void setup() {
    // Initialize serial communication
    Serial.begin(9600);
    //while (!Serial);

    // Initialize IMU
    if (myIMU.begin() != 0) {
        Serial.println("IMU initialization failed!");
        while (1);
    }
    Serial.println("IMU initialized successfully!");

    // Initialize BLE
    if (!BLE.begin()) {
        Serial.println("Starting BLE failed!");
        while (1);
    }
    BLE.setLocalName("Bottle Monitor");
    BLE.setAdvertisedService(imuService);

    imuService.addCharacteristic(accelCharacteristic);
    imuService.addCharacteristic(gyroCharacteristic);
    imuService.addCharacteristic(scaleCharacteristic);
    imuService.addCharacteristic(uprightCharacteristic);
    imuService.addCharacteristic(calibrateCharacteristic);

    BLE.addService(imuService);
    BLE.advertise();
    Serial.println("BLE IMU and Scale Peripheral is now advertising...");

    // Initialize Mini Scale
    Wire.begin();
    Wire.setClock(400000UL);

    while (!scales.begin(&Wire)) {
        Serial.println("Scales connect error");
        delay(1000);
    }

    scales.setLEDColor(0x001000);  // Optional: Set LED color on the scale unit
    scales.setGapValue(gap);
    Serial.println("Place the empty water bottle on the scale and press 'Calibrate' to zero the scale.");

    // Initialize LED pins as outputs
    pinMode(LED_RED, OUTPUT);
    pinMode(LED_GREEN, OUTPUT);
    pinMode(LED_BLUE, OUTPUT);

    // Turn off all LEDs initially
    digitalWrite(LED_RED, HIGH);    // HIGH turns the LED OFF
    digitalWrite(LED_GREEN, HIGH);
    digitalWrite(LED_BLUE, HIGH);
}

void loop() {
    // Check for BLE central connection
    BLEDevice central = BLE.central();
    if (central) {
        Serial.println("Connected to central");

        while (central.connected()) {
            // Handle calibration command in all states
            if (calibrateCharacteristic.written()) {
                uint8_t command = calibrateCharacteristic.value()[0];
                if (command == 1) {
                    scales.setOffset(); // Reset the Mini Scale
                    Serial.println("Mini Scale calibrated with empty bottle.");

                    // Set calibration flag
                    calibrationOccurred = true;

                    // Switch to ACTIVE_STATE to transmit reset value
                    currentState = ACTIVE_STATE;
                    stateStartTime = millis();
                }
            }

            // Get IMU readings
            accelX = myIMU.readFloatAccelX();
            accelY = myIMU.readFloatAccelY();
            accelZ = myIMU.readFloatAccelZ();
            gyroX = myIMU.readFloatGyroX();
            gyroY = myIMU.readFloatGyroY();
            gyroZ = myIMU.readFloatGyroZ();

            // Determine if the bottle is upright
            bool isUpright = abs(accelZ - 1.0) < 0.08; // Adjust threshold as needed
            String uprightStatus = isUpright ? "Upright" : "Not Upright";

            // Send accelerometer data
            char accelData[20];
            snprintf(accelData, sizeof(accelData), "%.2f,%.2f,%.2f", accelX, accelY, accelZ);
            accelCharacteristic.writeValue((const unsigned char *)accelData, strlen(accelData));

            // Send gyroscope data
            char gyroData[20];
            snprintf(gyroData, sizeof(gyroData), "%.2f,%.2f,%.2f", gyroX, gyroY, gyroZ);
            gyroCharacteristic.writeValue((const unsigned char *)gyroData, strlen(gyroData));

            // Send upright status to BLE characteristic
            char uprightData[20];
            snprintf(uprightData, sizeof(uprightData), "%s", uprightStatus.c_str());
            uprightCharacteristic.writeValue((const unsigned char *)uprightData, strlen(uprightData));

            // Now handle state-specific code
            switch (currentState) {
                case IDLE_STATE: {
                    // Turn on the Blue LED
                    digitalWrite(LED_RED, HIGH);
                    digitalWrite(LED_GREEN, HIGH);
                    digitalWrite(LED_BLUE, LOW); // LOW turns the LED ON

                    // Monitor movement
                    if (movementDetected()) {
                        Serial.println("Movement detected! Transitioning to AWAKE_STATE.");
                        currentState = AWAKE_STATE;
                        stateStartTime = millis();
                    }

                    break;
                }
                case AWAKE_STATE: {
                    // Turn on the Red LED
                    digitalWrite(LED_RED, LOW);
                    digitalWrite(LED_GREEN, HIGH);
                    digitalWrite(LED_BLUE, HIGH);

                    // Wait for bottle to stabilize and be upright
                    if (isBottleStable() && isUpright) {
                        Serial.println("Bottle is stable and upright! Transitioning to ACTIVE_STATE.");
                        currentState = ACTIVE_STATE;
                        stateStartTime = millis();
                    } else if (millis() - stateStartTime > awakeTimeout) {
                        Serial.println("Awake timeout reached. Returning to IDLE_STATE.");
                        currentState = IDLE_STATE;
                    }

                    break;
                }
                case ACTIVE_STATE: {
                    // Turn on the Green LED
                    digitalWrite(LED_RED, HIGH);
                    digitalWrite(LED_GREEN, LOW);
                    digitalWrite(LED_BLUE, HIGH);

                    // Take a reading from the Mini Scale
                    float weight = scales.getWeight();
                    float volume = weight;  // Assuming 1g = 1mL

                    // Debugging: Print previous and current volume
                    Serial.print("Previous Volume: "); Serial.println(previousVolume);
                    Serial.print("Current Volume: "); Serial.println(volume);

                    // Compare to previous value or if calibration occurred
                    if (abs(volume - previousVolume) >= SIGNIFICANT_VOLUME_CHANGE || calibrationOccurred) {
                        // Send water volume to app
                        char scaleData[20];
                        snprintf(scaleData, sizeof(scaleData), "%.2f mL", volume);
                        scaleCharacteristic.writeValue((const unsigned char *)scaleData, strlen(scaleData));

                        Serial.print("Water volume changed significantly or calibration occurred. New volume: ");
                        Serial.println(volume);

                        previousVolume = volume;

                        // Make the active state last 5 seconds
                        unsigned long activeStateStart = millis();
                        while (millis() - activeStateStart < 5000) {
                            // Keep sending the volume data to ensure the app receives it
                            scaleCharacteristic.writeValue((const unsigned char *)scaleData, strlen(scaleData));
                            delay(500);  // Send every 0.5 seconds
                        }

                        // Reset calibration flag
                        calibrationOccurred = false;

                        currentState = IDLE_STATE;
                        Serial.println("Returning to IDLE_STATE.");
                    } else {
                        // No significant change
                        Serial.println("No significant volume change. Returning to IDLE_STATE.");

                        // Reset calibration flag if it was set but no significant change occurred
                        calibrationOccurred = false;

                        currentState = IDLE_STATE;
                    }

                    break;
                }
                default: {
                    // Should not reach here
                    break;
                }
            }

            // Print values to serial monitor for debugging
            Serial.print("Current State: ");
            switch (currentState) {
                case IDLE_STATE:
                    Serial.println("IDLE_STATE");
                    break;
                case AWAKE_STATE:
                    Serial.println("AWAKE_STATE");
                    break;
                case ACTIVE_STATE:
                    Serial.println("ACTIVE_STATE");
                    break;
                default:
                    Serial.println("UNKNOWN_STATE");
                    break;
            }

            Serial.print("Accelerometer - X: "); Serial.print(accelX);
            Serial.print(", Y: "); Serial.print(accelY);
            Serial.print(", Z: "); Serial.println(accelZ);

            Serial.print("Gyroscope - X: "); Serial.print(gyroX);
            Serial.print(", Y: "); Serial.print(gyroY);
            Serial.print(", Z: "); Serial.println(gyroZ);

            Serial.print("Upright Status: "); Serial.println(uprightStatus);

            // Add previousVolume to the constantly updating serial output
            Serial.print("Previous Volume: "); Serial.println(previousVolume);

            Serial.println("---------------------------------------------------");

            delay(100);  // Short delay for loop iteration
        }

        Serial.println("Central disconnected");
    }
}

// Function to detect significant movement
bool movementDetected() {
    // Calculate the difference between current and previous accelerometer readings
    float deltaX = abs(accelX - prevAccelX_move);
    float deltaY = abs(accelY - prevAccelY_move);
    float deltaZ = abs(accelZ - prevAccelZ_move);

    // Update previous readings
    prevAccelX_move = accelX;
    prevAccelY_move = accelY;
    prevAccelZ_move = accelZ;

    // If any of the differences exceed the threshold, movement is detected
    if (deltaX > SIGNIFICANT_MOVEMENT_THRESHOLD || deltaY > SIGNIFICANT_MOVEMENT_THRESHOLD || deltaZ > SIGNIFICANT_MOVEMENT_THRESHOLD) {
        return true;
    } else {
        return false;
    }
}

// Function to check if the bottle is stable
bool isBottleStable() {
    // Calculate the difference between current and previous accelerometer readings
    float deltaX = abs(accelX - prevAccelX_stable);
    float deltaY = abs(accelY - prevAccelY_stable);
    float deltaZ = abs(accelZ - prevAccelZ_stable);

    // Update previous readings
    prevAccelX_stable = accelX;
    prevAccelY_stable = accelY;
    prevAccelZ_stable = accelZ;

    // If all differences are below the stability threshold, consider bottle stable
    if (deltaX < STABILITY_THRESHOLD && deltaY < STABILITY_THRESHOLD && deltaZ < STABILITY_THRESHOLD) {
        return true;
    } else {
        return false;
    }
}