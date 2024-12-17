//
//  DailyGoal.swift
//  SmartWaterTracker
//
//  Created by Arnav Bhatia on 29/11/2024.
//

import SwiftUI

struct DailyGoal: View {
    @EnvironmentObject var healthManager: HealthManager
    @State private var showingEditSheet = false
    @State private var temporaryGoal: Int = 0
    
    func refreshHealthData() {
        print("Refreshing health data...")
        healthManager.fetchTodayExerciseMinutes()
        healthManager.fetchLatestBodyWeight()
        healthManager.fetchLatestHeight()
        healthManager.fetchAge()
    }
    
    var body: some View {
        VStack(spacing: 30) {
            if healthManager.activites.isEmpty {
                VStack {
                    Text("Loading health data...")
                        .foregroundStyle(.secondary)
                    ProgressView()
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 2), spacing: 20) {
                    ForEach(healthManager.activites.sorted(by: { $0.value.id < $1.value.id }), id: \.key) { item in
                        ActivityCard(activity: item.value)
                    }
                }
                .padding()
                
                VStack(spacing: 8) {
                    Text("Daily Water Intake Goal")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("\(healthManager.waterIntakeGoal) mL")
                        .font(.title)
                        .bold()
                    
                    Button(action: {
                        temporaryGoal = healthManager.waterIntakeGoal
                        showingEditSheet = true
                    }) {
                        Text("Edit Goal")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.top)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationView {
                ZStack {
                    Color(.systemBackground)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 40) {
                        Text("Today's Water Goal")
                            .font(.largeTitle)
                            .bold()
                        
                        Text("Set a temporary water intake goal just for today based on your needs. This does not affect your calculated goal schedule.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        HStack(spacing: 40) {
                            Button(action: {
                                if temporaryGoal >= 50 {
                                    temporaryGoal -= 50
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(spacing: 8) {
                                Text("\(temporaryGoal)")
                                    .font(.system(size: 60))
                                    .bold()
                                Text("MILLILITERS/DAY")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Button(action: {
                                temporaryGoal += 50
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            healthManager.waterIntakeGoal = temporaryGoal
                            showingEditSheet = false
                        }) {
                            Text("Change Water Intake Goal for Today")
                                .font(.headline)
                                .foregroundStyle(.green)
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
                        showingEditSheet = false
                    },
                    trailing: Button(action: {
                        temporaryGoal = healthManager.calculatedWaterIntakeGoal
                    }) {
                        Text("Revert")
                            .foregroundColor(.blue)
                    }
                )
            }
        }
        .onAppear {
            print("DailyGoal view appeared")
            refreshHealthData()
        }
        .refreshable {
            refreshHealthData()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            print("App will enter foreground - refreshing DailyGoal view")
            refreshHealthData()
        }
    }
}

#Preview {
    DailyGoal()
        .environmentObject(HealthManager())
}
