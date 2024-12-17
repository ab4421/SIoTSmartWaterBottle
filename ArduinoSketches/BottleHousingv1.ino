#include <Wire.h>
#include <ArduinoBLE.h>
#include "LSM6DS3.h"
#include "UNIT_SCALES.h"

// IMU and BLE configuration
LSM6DS3 myIMU(I2C_MODE, 0x6A); // I2C address for IMU

BLEService imuService("12345678-1234-5678-1234-56789abcdef0");
BLECharacteristic accelCharacteristic(
    "12345678-1234-5678-1234-56789abcdef1", BLENotify, 20);
BLECharacteristic gyroCharacteristic(
    "12345678-1234-5678-1234-56789abcdef2", BLENotify, 20);
BLECharacteristic scaleCharacteristic(
    "12345678-1234-5678-1234-56789abcdef3", BLENotify, 20);
BLECharacteristic uprightCharacteristic(
    "12345678-1234-5678-1234-56789abcdef4", BLENotify, 20);
BLECharacteristic calibrateCharacteristic(
    "12345678-1234-5678-1234-56789abcdef5", BLEWrite, 1); // For commands

// Mini Scale configuration
UNIT_SCALES scales;
float gap = 140;  // Replace with your calibrated gap value

// State management
enum State {
    IDLE_STATE,
    AWAKE_STATE,
    ACTIVE_STATE,
    REFILL_STATE
};

State currentState = IDLE_STATE;
unsigned long stateStartTime = 0;
unsigned long awakeTimeout = 30000;  // 30 seconds timeout for AWAKE_STATE

#define SIGNIFICANT_MOVEMENT_THRESHOLD 0.2  // Adjust as needed
#define STABILITY_THRESHOLD 0.02            // Adjust as needed
#define SIGNIFICANT_VOLUME_CHANGE 5.0       // in mL, adjust as needed

// Command values
#define COMMAND_CALIBRATE 1
#define COMMAND_CALCULATE 2
#define COMMAND_REFILL    3

// Variables for IMU data
float accelX = 0, accelY = 0, accelZ = 0;
float gyroX = 0, gyroY = 0, gyroZ = 0;
float prevAccelX_move = 0, prevAccelY_move = 0, prevAccelZ_move = 0;
float prevAccelX_stable = 0, prevAccelY_stable = 0, prevAccelZ_stable = 0;

// Variables for volume tracking
float previousVolume = 0;

// Calibration and Calculation flags
bool calibrationOccurred = false;
bool calculationRequested = false;

// Variables for weight stability
float previousWeight = 0;
unsigned long weightStableStartTime = 0;
const unsigned long weightStabilityTimeout = 5000; // 5 seconds
const float WEIGHT_STABILITY_THRESHOLD = 2.0; // Adjust as needed

// Refill mode flag
bool refillMode = false;

// Define LED pin mappings
#define LED_RED   LED_BUILTIN   // Red LED
#define LED_GREEN LED_GREEN     // Green LED
#define LED_BLUE  LED_BLUE      // Blue LED

void setup() {
    // Initialize serial communication
    Serial.begin(9600);
    // while (!Serial); // Uncomment if needed

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

    scales.setLEDColor(0x001000);  // Optional: Set LED color on the scale
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

    // Start blinking blue LED during setup
    unsigned long setupStartTime = millis();
    unsigned long lastBlinkTime = 0;
    bool ledState = false;

    while (millis() - setupStartTime < 3000) { // Blink for 3 seconds
        if (millis() - lastBlinkTime >= 500) { // Blink every 500ms
            lastBlinkTime = millis();
            ledState = !ledState;
            digitalWrite(LED_BLUE, ledState ? LOW : HIGH); // LOW is ON
        }
        // Allow BLE events to process
        BLE.poll();
    }
}

void loop() {
    // Check for BLE central connection
    BLEDevice central = BLE.central();
    if (central) {
        Serial.println("Connected to central");

        // Once connected, stop blinking blue LED
        digitalWrite(LED_BLUE, HIGH); // Turn off blue LED

        while (central.connected()) {
            // Handle commands in all states
            if (calibrateCharacteristic.written()) {
                uint8_t command = calibrateCharacteristic.value()[0];
                if (command == COMMAND_CALIBRATE) {
                    scales.setOffset(); // Reset the Mini Scale
                    Serial.println("Mini Scale calibrated with empty bottle.");

                    // Set calibration flag
                    calibrationOccurred = true;

                    // Switch to ACTIVE_STATE to transmit reset value
                    currentState = ACTIVE_STATE;
                    stateStartTime = millis();
                } else if (command == COMMAND_CALCULATE) {
                    Serial.println("Calculate command received.");

                    // Set calculation flag
                    calculationRequested = true;

                    // Switch to ACTIVE_STATE to perform calculation
                    currentState = ACTIVE_STATE;
                    stateStartTime = millis();
                } else if (command == COMMAND_REFILL) {
                    Serial.println("Refill command received.");

                    // Toggle refill mode
                    refillMode = !refillMode;

                    if (refillMode) {
                        // Enter Refill state
                        currentState = REFILL_STATE;
                        Serial.println("Entering REFILL_STATE.");
                    } else {
                        // Exit Refill state
                        currentState = IDLE_STATE;
                        Serial.println("Exiting REFILL_STATE.");
                    }
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
            bool isUpright = abs(accelX + 1.0) < 0.08; // X close to -1
            String uprightStatus = isUpright ? "Upright" : "Not Upright";

            // Send accelerometer data
            char accelData[20];
            snprintf(accelData, sizeof(accelData), "%.2f,%.2f,%.2f",
                     accelX, accelY, accelZ);
            accelCharacteristic.writeValue(
                (const unsigned char *)accelData, strlen(accelData));

            // Send gyroscope data
            char gyroData[20];
            snprintf(gyroData, sizeof(gyroData), "%.2f,%.2f,%.2f",
                     gyroX, gyroY, gyroZ);
            gyroCharacteristic.writeValue(
                (const unsigned char *)gyroData, strlen(gyroData));

            // Send upright status to BLE characteristic
            char uprightData[20];
            snprintf(uprightData, sizeof(uprightData), "%s",
                     uprightStatus.c_str());
            uprightCharacteristic.writeValue(
                (const unsigned char *)uprightData, strlen(uprightData));

            // State-specific code
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

                    Serial.println("Waiting for weight to stabilize...");

                    // Introduce a delay before starting the weight check
                    delay(3000); // Wait 3 seconds

                    // Initialize weight stability variables
                    weightStableStartTime = millis();
                    previousWeight = scales.getWeight();

                    bool weightStabilized = false;

                    while (millis() - weightStableStartTime < weightStabilityTimeout) {
                        float currentWeight = scales.getWeight();
                        float weightChange = abs(currentWeight - previousWeight);

                        // Debugging: Print weight readings
                        Serial.print("Current Weight: "); Serial.print(currentWeight);
                        Serial.print(" Previous Weight: "); Serial.print(previousWeight);
                        Serial.print(" Weight Change: "); Serial.println(weightChange);

                        if (weightChange < WEIGHT_STABILITY_THRESHOLD) {
                            // Weight is stable
                            weightStabilized = true;
                            previousWeight = currentWeight; // Update stabilized weight
                            break;
                        }

                        previousWeight = currentWeight;
                        delay(500); // Check every 0.5 seconds
                    }

                    if (weightStabilized) {
                        float volume = previousWeight; // Use stabilized weight

                        // Debugging: Print volumes
                        Serial.print("Previous Volume: "); Serial.println(previousVolume);
                        Serial.print("Current Volume: "); Serial.println(volume);

                        // Compare to previous value or if flags are set
                        if (abs(volume - previousVolume) >= SIGNIFICANT_VOLUME_CHANGE
                            || calibrationOccurred || calculationRequested) {
                            // Send water volume to app
                            char scaleData[20];
                            snprintf(scaleData, sizeof(scaleData), "%.2f mL", volume);
                            scaleCharacteristic.writeValue(
                                (const unsigned char *)scaleData, strlen(scaleData));

                            Serial.print("Water volume changed significantly or command received. New volume: ");
                            Serial.println(volume);

                            previousVolume = volume;

                            // Send the volume data multiple times
                            unsigned long activeStateStart = millis();
                            while (millis() - activeStateStart < 5000) {
                                scaleCharacteristic.writeValue(
                                    (const unsigned char *)scaleData, strlen(scaleData));
                                delay(500);  // Send every 0.5 seconds
                            }
                        } else {
                            Serial.println("No significant volume change.");
                        }
                    } else {
                        Serial.println("Weight did not stabilize in time.");
                    }

                    // Reset flags
                    calibrationOccurred = false;
                    calculationRequested = false;

                    currentState = IDLE_STATE;
                    Serial.println("Returning to IDLE_STATE.");

                    break;
                }
                case REFILL_STATE: {
                    // Turn off the Blue LED
                    digitalWrite(LED_BLUE, HIGH); // HIGH turns the LED OFF

                    // Blink Green LED to indicate refill mode
                    static unsigned long lastBlinkTime = 0;
                    static bool ledState = false;

                    if (millis() - lastBlinkTime >= 500) { // Blink every 500ms
                        lastBlinkTime = millis();
                        ledState = !ledState;
                        digitalWrite(LED_GREEN, ledState ? LOW : HIGH); // LOW is ON
                    }

                    // Continuously monitor the water volume
                    float weight = scales.getWeight();
                    float volume = weight;  // Assuming 1g = 1mL

                    // Send water volume to app
                    char scaleData[20];
                    snprintf(scaleData, sizeof(scaleData), "%.2f mL", volume);
                    scaleCharacteristic.writeValue(
                        (const unsigned char *)scaleData, strlen(scaleData));

                    // Stay in REFILL_STATE until refillMode flag is toggled off

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
                case REFILL_STATE:
                    Serial.println("REFILL_STATE");
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

            // Add previousVolume to serial output
            Serial.print("Previous Volume: "); Serial.println(previousVolume);

            Serial.println("---------------------------------------------------");

            delay(100);  // Short delay for loop iteration
        }

        Serial.println("Central disconnected");
    } else {
        // Not connected to central

        // Blink blue LED
        static unsigned long lastBlinkTime = 0;
        static bool ledState = false;

        if (millis() - lastBlinkTime >= 500) { // Blink every 500ms
            lastBlinkTime = millis();
            ledState = !ledState;
            digitalWrite(LED_BLUE, ledState ? LOW : HIGH); // LOW is ON
        }

        // Include a low-power sleep here if desired
    }
}

// Function to detect significant movement
bool movementDetected() {
    // Calculate difference between current and previous readings
    float deltaX = abs(accelX - prevAccelX_move);
    float deltaY = abs(accelY - prevAccelY_move);
    float deltaZ = abs(accelZ - prevAccelZ_move);

    // Update previous readings
    prevAccelX_move = accelX;
    prevAccelY_move = accelY;
    prevAccelZ_move = accelZ;

    // Movement detected if any difference exceeds threshold
    if (deltaX > SIGNIFICANT_MOVEMENT_THRESHOLD ||
        deltaY > SIGNIFICANT_MOVEMENT_THRESHOLD ||
        deltaZ > SIGNIFICANT_MOVEMENT_THRESHOLD) {
        return true;
    } else {
        return false;
    }
}

// Function to check if the bottle is stable
bool isBottleStable() {
    // Calculate difference between current and previous readings
    float deltaX = abs(accelX - prevAccelX_stable);
    float deltaY = abs(accelY - prevAccelY_stable);
    float deltaZ = abs(accelZ - prevAccelZ_stable);

    // Update previous readings
    prevAccelX_stable = accelX;
    prevAccelY_stable = accelY;
    prevAccelZ_stable = accelZ;

    // Bottle is stable if all differences are below threshold
    if (deltaX < STABILITY_THRESHOLD &&
        deltaY < STABILITY_THRESHOLD &&
        deltaZ < STABILITY_THRESHOLD) {
        return true;
    } else {
        return false;
    }
}