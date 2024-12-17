//
//  DebugView.swift
//  SmartWaterTracker
//
//  Created by Arnav Bhatia on 22/11/2024.
//


import SwiftUI

struct DebugView: View {
    @StateObject private var bleManager = BLEManager.shared

    var body: some View {
        VStack(spacing: 15) { // Increased spacing slightly
            // Connection Status
            if bleManager.isConnected {
                Text("Connected")
                    .foregroundColor(.green)
                    .bold()
            } else {
                Text("Scanning...")
                    .foregroundColor(.orange)
                    .bold()
            }

            // Bottle Position and Water Volume Section
            HStack {
                // Upright Status Section
                VStack(spacing: 5) {
                    Text("Bottle Position")
                        .font(.headline) // Adjusted font size
                        .bold()
                    Text(bleManager.uprightStatus)
                        .font(.subheadline)
                        .foregroundColor(bleManager.uprightStatus == "Upright" ? .green : .red)
                        .padding(5)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(5)
                }

                Spacer()

                // Mini Scale Section
                VStack(spacing: 5) {
                    Text("Water Volume")
                        .font(.headline)
                        .bold()
                    Text(bleManager.volume)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(5)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(5)
                }
            }
            .padding(.horizontal)
            .padding(.top, 5) // Added top padding

            // Accelerometer Section
            VStack(alignment: .leading, spacing: 10) { // Adjusted spacing
                Text("Accelerometer Readings (Tilt):")
                    .font(.headline)
                    .bold()
                HStack {
                    Spacer()
                    Text("X: \(bleManager.accelX, specifier: "%.2f")")
                    Spacer()
                    Text("Y: \(bleManager.accelY, specifier: "%.2f")")
                    Spacer()
                    Text("Z: \(bleManager.accelZ, specifier: "%.2f")")
                    Spacer()
                }
                .font(.footnote)
                .padding(5)
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(5)

                // Tilt Gauges for Accelerometer
                HStack {
                    Spacer()
                    Gauge(value: bleManager.accelX, in: -1.3...1.3) {
                        Text("Pitch")
                            .font(.caption)
                    }
                    .gaugeStyle(.accessoryCircular)
                    .frame(width: 50, height: 50)

                    Spacer()
                    Gauge(value: bleManager.accelY, in: -1.3...1.3) {
                        Text("Roll")
                            .font(.caption)
                    }
                    .gaugeStyle(.accessoryCircular)
                    .frame(width: 50, height: 50)

                    Spacer()
                    Gauge(value: bleManager.accelZ, in: -1.3...1.3) {
                        Text("Yaw")
                            .font(.caption)
                    }
                    .gaugeStyle(.accessoryCircular)
                    .frame(width: 50, height: 50)
                    Spacer()
                }
            }
            .padding(.horizontal)
            .padding(.top, 10) // Added top padding

            // Gyroscope Section
            VStack(alignment: .leading, spacing: 10) { // Adjusted spacing
                Text("Gyroscope Readings (Rotation):")
                    .font(.headline)
                    .bold()
                HStack {
                    Spacer()
                    Text("X: \(bleManager.gyroX, specifier: "%.2f")")
                    Spacer()
                    Text("Y: \(bleManager.gyroY, specifier: "%.2f")")
                    Spacer()
                    Text("Z: \(bleManager.gyroZ, specifier: "%.2f")")
                    Spacer()
                }
                .font(.footnote)
                .padding(5)
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.2))
                .cornerRadius(5)

                // Rotation Gauges for Gyroscope
                HStack {
                    Spacer()
                    Gauge(value: bleManager.gyroX, in: -1000.0...1000.0) {
                        Text("Pitch")
                            .font(.caption)
                    }
                    .gaugeStyle(.accessoryCircular)
                    .frame(width: 50, height: 50)

                    Spacer()
                    Gauge(value: bleManager.gyroY, in: -1000.0...1000.0) {
                        Text("Roll")
                            .font(.caption)
                    }
                    .gaugeStyle(.accessoryCircular)
                    .frame(width: 50, height: 50)

                    Spacer()
                    Gauge(value: bleManager.gyroZ, in: -1000.0...1000.0) {
                        Text("Yaw")
                            .font(.caption)
                    }
                    .gaugeStyle(.accessoryCircular)
                    .frame(width: 50, height: 50)
                    Spacer()
                }
            }
            .padding(.horizontal)
            .padding(.top, 10) // Added top padding

            Spacer()

            // Buttons Section (unchanged)
            HStack {
                Button(action: {
                    bleManager.sendCalibrationCommand()
                }) {
                    Text("Calibrate")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 5)

                Button(action: {
                    bleManager.sendCalculateCommand()
                }) {
                    Text("Calculate")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 5)

                Button(action: {
                    bleManager.sendRefillCommand()
                }) {
                    Text("Refill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 5)
            }
            .padding(.horizontal)
            .padding(.bottom, 10) // Adjusted padding to prevent overlap with TabView
        }
        .padding(.top, 10) // Adjusted padding to avoid notch
    }
}

#Preview {
    DebugView()
}
