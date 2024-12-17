#include <Wire.h>
#include "UNIT_SCALES.h"

UNIT_SCALES scales;
float gap = 140.0; // Use your calibrated gap value
unsigned long startTime;

void setup() {
  Serial.begin(9600);
  while(!Serial);

  Wire.begin();
  Wire.setClock(400000UL);

  while (!scales.begin(&Wire)) {
    Serial.println("Scales connect error");
    delay(1000);
  }

  scales.setGapValue(gap);
  // If you need to zero the scale with an empty bottle on it:
  // scales.setOffset();

  Serial.println("timestamp(ms),weight_g");
  startTime = millis();
}

void loop() {
  float weight = scales.getWeight(); // Assuming 1g ~ 1mL for water
  unsigned long currentTime = millis() - startTime;

  // Print in CSV format: timestamp, weight_g
  Serial.print(currentTime);
  Serial.print(",");
  Serial.println(weight, 6);

  delay(100); // Adjust as needed
}
