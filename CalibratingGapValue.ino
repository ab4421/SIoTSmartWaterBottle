#include <Wire.h>
#include "UNIT_SCALES.h"

UNIT_SCALES scales;

// Declare 'gap' as a global variable
float gap = 183.3; // Replace with your current gap value or a default value

void setup() {
  Serial.begin(9600);
  // Uncomment the line below if you need to wait for the Serial Monitor to open
  // while (!Serial);

  // Initialize the scale
  Wire.begin();
  Wire.setClock(400000UL);

  while (!scales.begin(&Wire)) {
    Serial.println("Scales connect error");
    delay(1000);
  }
  scales.setLEDColor(0x001000); // Optional: Set LED color on the scale unit
  Serial.println("Scale initialized.");

  // Set initial gap value
  scales.setGapValue(gap);

  // Zero the scale
  Serial.println("Ensure the scale is empty, then type 'zero' and press Enter to zero the scale.");
}

void loop() {
  float weight = scales.getWeight();
  int adc = scales.getRawADC();

  // Display the information
  Serial.println("==================================");
  Serial.println("Unit Scale Gap Setting");
  Serial.print("WEIGHT: ");
  Serial.print(weight, 2);
  Serial.println(" g");
  Serial.print("ADC: ");
  Serial.println(adc);
  Serial.print("GAP: ");
  Serial.println(gap, 4);
  // Add current weight reading here
  Serial.print("Current Weight: ");
  Serial.print(weight, 2);
  Serial.println(" g");
  Serial.println("----------------------------------");
  Serial.println("Commands:");
  Serial.println("'+'        : Increase gap value by 0.1");
  Serial.println("'-'        : Decrease gap value by 0.1");
  Serial.println("'zero'     : Zero the scale (set offset)");
  Serial.println("'setgap'   : Set gap value manually");
  Serial.println("'calibrate': Calibrate gap using known weight");
  Serial.println("Type a command and press Enter:");
  Serial.println("==================================");

  // Check for user input
  if (Serial.available() > 0) {
    String input = Serial.readStringUntil('\n');
    input.trim(); // Remove any leading/trailing whitespace

    if (input == "+") {
      gap += 0.1;
      scales.setGapValue(gap);
      Serial.println("Gap value increased by 0.1");
    } else if (input == "-") {
      gap -= 0.1;
      scales.setGapValue(gap);
      Serial.println("Gap value decreased by 0.1");
    } else if (input.equalsIgnoreCase("zero")) {
      scales.setOffset();
      Serial.println("Scale zeroed (offset set).");
    } else if (input.equalsIgnoreCase("setgap")) {
      Serial.println("Enter the new gap value and press Enter:");
      while (Serial.available() == 0) {
        // Wait for user input
      }
      String gapInput = Serial.readStringUntil('\n');
      float newGap = gapInput.toFloat();
      scales.setGapValue(newGap);
      gap = newGap;
      Serial.print("Gap value set to: ");
      Serial.println(gap, 4);
    } else if (input.equalsIgnoreCase("calibrate")) {
      calibrateGapValue();
    } else {
      Serial.println("Invalid command.");
    }
  }

  delay(1000); // Wait for 1 second before refreshing
}

void calibrateGapValue() {
  // Function to calibrate the gap value using a known weight
  Serial.println("Calibration started.");

  // Zero the scale
  Serial.println("Ensure the scale is empty, then type 'zero' and press Enter.");
  while (Serial.available() == 0) {
    // Wait for user input
  }
  String zeroInput = Serial.readStringUntil('\n');
  zeroInput.trim();
  if (zeroInput.equalsIgnoreCase("zero")) {
    scales.setOffset();
    Serial.println("Scale zeroed (offset set).");
  } else {
    Serial.println("Calibration aborted: 'zero' not entered.");
    return;
  }

  // Ask user to place known weight
  Serial.println("Place a known weight on the scale, then type 'next' and press Enter.");
  while (Serial.available() == 0) {
    // Wait for user input
  }
  String nextInput = Serial.readStringUntil('\n');
  nextInput.trim();
  if (!nextInput.equalsIgnoreCase("next")) {
    Serial.println("Calibration aborted: 'next' not entered.");
    return;
  }

  // Read raw ADC value
  int32_t rawADC = scales.getRawADC();
  Serial.print("Raw ADC value: ");
  Serial.println(rawADC);

  // Ask for the known weight
  Serial.println("Enter the known weight in grams (e.g., 500.0) and press Enter:");
  while (Serial.available() == 0) {
    // Wait for user input
  }
  String weightInput = Serial.readStringUntil('\n');
  float knownWeight = weightInput.toFloat();

  // Check for division by zero
  if (knownWeight == 0) {
    Serial.println("Error: Known weight cannot be zero.");
    return;
  }

  // Calculate new gap value
  float newGap = (float)rawADC / knownWeight;
  scales.setGapValue(newGap);

  // Update global gap variable
  gap = newGap;

  Serial.print("Calculated gap value: ");
  Serial.println(newGap, 4);
  Serial.println("Gap value updated.");

  // Test the calibration
  Serial.println("Testing the calibration. Current weight readings:");
  for (int i = 0; i < 5; i++) {
    float weight = scales.getWeight();
    Serial.print("Weight: ");
    Serial.print(weight, 2);
    Serial.println(" g");
    delay(1000);
  }

  Serial.println("Calibration complete.");
  Serial.println("Please update your main sketch with the new gap value:");
  Serial.print("float gap = ");
  Serial.print(newGap, 4);
  Serial.println(";");
}