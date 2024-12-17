#include <Wire.h>
#include "LSM6DS3.h"

// IMU configuration
LSM6DS3 myIMU(I2C_MODE, 0x6A); // I2C address for IMU
unsigned long startTime;

void setup() {
  Serial.begin(9600);
  while(!Serial);

  if (myIMU.begin() != 0) {
    Serial.println("IMU init failed");
    while (1);
  }

  Serial.println("timestamp(ms),accelX,accelY,accelZ,gyroX,gyroY,gyroZ");
  startTime = millis();
}

void loop() {
  float accelX = myIMU.readFloatAccelX();
  float accelY = myIMU.readFloatAccelY();
  float accelZ = myIMU.readFloatAccelZ();
  float gyroX  = myIMU.readFloatGyroX();
  float gyroY  = myIMU.readFloatGyroY();
  float gyroZ  = myIMU.readFloatGyroZ();

  unsigned long currentTime = millis() - startTime;

  // Print in CSV format:
  // timestamp, accelX, accelY, accelZ, gyroX, gyroY, gyroZ
  Serial.print(currentTime);
  Serial.print(",");
  Serial.print(accelX, 6);
  Serial.print(",");
  Serial.print(accelY, 6);
  Serial.print(",");
  Serial.print(accelZ, 6);
  Serial.print(",");
  Serial.print(gyroX, 6);
  Serial.print(",");
  Serial.print(gyroY, 6);
  Serial.print(",");
  Serial.println(gyroZ, 6);

  delay(100); // Adjust as needed for sampling rate
}

