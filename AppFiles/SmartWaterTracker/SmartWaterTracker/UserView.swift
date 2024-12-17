//
//  UserView.swift
//  SmartWaterTracker
//
//  Created by Arnav Bhatia on 22/11/2024.
//

import SwiftUI
import UIKit

struct UserView: View {
    @StateObject private var bleManager = BLEManager.shared
    @EnvironmentObject var healthManager: HealthManager
    @State private var activeAlert: ActiveAlert?
    @State private var manualGlasses: Double = 0.0
    @State private var showingManualEntrySheet = false

    enum ActiveAlert: Identifiable {
        case refill
        case reset

        var id: Int {
            hashValue
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Display today's date
                Text(Date(), style: .date)
                    .font(.title)
                    .bold()

                // Updated Circular capacity gauge
                ZStack {
                    Circle()
                        .stroke(lineWidth: 20)
                        .opacity(0.3)
                        .foregroundColor(Color.blue)

                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(bleManager.totalIntake / Double(max(healthManager.waterIntakeGoal, 1)), 1.0)))
                        .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                        .foregroundColor(Color.blue)
                        .rotationEffect(Angle(degrees: -90))
                        .animation(.easeOut, value: bleManager.totalIntake)

                    VStack(spacing: 4) {
                        Text("\(Int(bleManager.totalIntake))/\(healthManager.waterIntakeGoal) mL")
                            .font(.title2)
                            .bold()
                        Text("\(Int((bleManager.totalIntake / Double(max(healthManager.waterIntakeGoal, 1))) * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 200, height: 200)

                // Linear capacity gauge
                VStack {
                    Text("Current Bottle Capacity")
                        .font(.headline)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(width: geometry.size.width, height: 20)
                                .opacity(0.3)
                                .foregroundColor(.blue)

                            Rectangle()
                                .frame(width: min(CGFloat(self.bleManager.currentVolume / max(self.bleManager.refillAmount, 1.0)) * geometry.size.width, geometry.size.width), height: 20)
                                .foregroundColor(.blue)
                                .animation(.easeOut, value: bleManager.currentVolume)
                        }
                        .cornerRadius(10)
                    }
                    .frame(height: 20)
                    Text("\(Int(bleManager.currentVolume))/\(Int(bleManager.refillAmount)) ml")
                }
                .padding()

                // Buttons Section
                HStack {
                    Spacer()
                    Button(action: {
                        bleManager.sendCalibrationCommand()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "scope")
                                .font(.largeTitle)
                            Text("Calibrate")
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Button(action: {
                        bleManager.sendCalculateCommand()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "gauge")
                                .font(.largeTitle)
                            Text("Calculate")
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Button(action: {
                        bleManager.sendRefillCommand()
                        // Handle refill mode toggle
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: bleManager.isRefillMode ? "waterbottle.fill" : "waterbottle")
                                .font(.largeTitle)
                            Text("Refill")
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                }
                .padding()

                // Manual Water Entry Button
                Button(action: {
                    showingManualEntrySheet = true
                }) {
                    Text("Add Water")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.bottom)

                Spacer()
            }
            .padding()
            .sheet(isPresented: $showingManualEntrySheet) {
                NavigationView {
                    ZStack {
                        Color(.systemBackground)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 40) {
                            Text("Add Water Manually")
                                .font(.largeTitle)
                                .bold()
                            
                            Text("Add water in increments of half a glass.\nHalf glass ≈ 120 mL\nFull glass ≈ 240 mL")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            
                            HStack(spacing: 40) {
                                Button(action: {
                                    if manualGlasses > 0 {
                                        manualGlasses -= 0.5
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(spacing: 8) {
                                    Text(String(format: "%.1f", manualGlasses))
                                        .font(.system(size: 60))
                                        .bold()
                                    Text("GLASSES")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Button(action: {
                                    manualGlasses += 0.5
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                let waterToAdd = manualGlasses * 240.0 // Now 240ml per glass (120ml per half glass)
                                bleManager.totalIntake += waterToAdd
                                bleManager.saveData()
                                manualGlasses = 0 // Reset the counter
                                showingManualEntrySheet = false
                            }) {
                                Text("Add \(Int(manualGlasses * 240.0)) mL to today's water intake")
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(15)
                            }
                            .padding(.bottom)
                        }
                        .padding()
                    }
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            showingManualEntrySheet = false
                        }
                    )
                }
            }
            .onAppear {
                // Fetch health data when view appears to ensure we have the latest water intake goal
                healthManager.fetchTodayExerciseMinutes()
                healthManager.fetchLatestBodyWeight()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefillAlert"))) { _ in
                self.activeAlert = .refill
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                print("App entered foreground - updating view")
            }
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .refill:
                    return Alert(
                        title: Text("Refill Detected"),
                        message: Text("The water volume has increased significantly. Have you refilled the bottle?"),
                        primaryButton: .default(Text("Yes")) {
                            // Update refill amount
                            bleManager.refillAmount = bleManager.currentVolume
                            bleManager.saveData()
                        },
                        secondaryButton: .cancel(Text("No"))
                    )
                case .reset:
                    return Alert(
                        title: Text("Reset Water Intake"),
                        message: Text("Are you sure you want to reset today's water intake? This action cannot be undone."),
                        primaryButton: .destructive(Text("Yes")) {
                            bleManager.totalIntake = 0.0
                            bleManager.saveData()
                        },
                        secondaryButton: .cancel(Text("No"))
                    )
                }
            }
            .navigationBarTitle("Water Tracker", displayMode: .inline)
            .navigationBarItems(
                leading:
                    Button(action: {
                        self.activeAlert = .reset
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                    },
                trailing:
                    NavigationLink(destination: DataView()) {
                        Image(systemName: "list.bullet")
                    }
            )
        }
    }
}

#Preview {
    UserView()
        .environmentObject(HealthManager())
}
