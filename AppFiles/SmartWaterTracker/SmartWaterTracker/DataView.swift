//
//  DataView.swift
//  SmartWaterTracker
//
//  Created by Arnav Bhatia on 22/11/2024.
//


import SwiftUI
import Charts

struct DataView: View {
    @State private var timeRange: TimeRange = .day
    @State private var selectedDate = Date()
    @State private var waterIntakeData: [WaterIntakeEntry] = []
    
    var body: some View {
        List {
            VStack(alignment: .leading) {
                // Time Range Picker
                TimeRangePicker(value: $timeRange)
                    .padding(.bottom)
                
                // Total Water Intake Header
                Text("Total Water Intake")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                // Total Water Intake Value
                Text("\(Int(totalWaterIntake)) mL")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                // Date or Date Range Display
                Text(dateRangeString)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                // Chart based on Time Range
                switch timeRange {
                case .day:
                    DailyWaterIntakeChart(date: selectedDate, data: hourlyIntakeData)
                        .frame(height: 240)
                case .week:
                    WeeklyWaterIntakeChart(startingFrom: selectedDate, data: dailyIntakeData)
                        .frame(height: 240)
                }
            }
            .listRowSeparator(.hidden)
            .transaction {
                $0.animation = nil // Disable animation when switching charts
            }
            
            // Placeholder for future content
            Section("More info") {
                AverageWaterIntakeCard(data: waterIntakeData)
                    .listRowInsets(EdgeInsets())
                    .padding()
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Water Intake")
        .onAppear {
            loadData()
        }
    }
    
    // Computed property for total water intake
    var totalWaterIntake: Double {
        switch timeRange {
        case .day:
            return hourlyIntakeData.reduce(0) { $0 + $1.volume }
        case .week:
            return dailyIntakeData.reduce(0) { $0 + $1.volume }
        }
    }
    
    // Computed property for date range string
    var dateRangeString: String {
        switch timeRange {
        case .day:
            return selectedDate.formatted(.dateTime.month().day().year())
        case .week:
            let endDate = Calendar.current.date(byAdding: .day, value: 6, to: selectedDate) ?? selectedDate
            let startString = selectedDate.formatted(.dateTime.month().day())
            let endString = endDate.formatted(.dateTime.month().day().year())
            return "\(startString) – \(endString)"
        }
    }
    
    // Hourly intake data for the selected day
    var hourlyIntakeData: [WaterIntakeEntry] {
        let calendar = Calendar.current
        return waterIntakeData.filter {
            calendar.isDate($0.date, inSameDayAs: selectedDate)
        }
        .groupByHour()
    }
    
    // Daily intake data for the selected week
    // Daily intake data for the selected week
    var dailyIntakeData: [WaterIntakeEntry] {
        let calendar = Calendar.current
        _ = calendar.range(of: .weekday, in: .weekOfYear, for: selectedDate) ?? 1..<8
        return waterIntakeData.filter {
            calendar.isDate($0.date, equalTo: selectedDate, toGranularity: .weekOfYear)
        }
        .groupByDay()
    }
    
    // Load data (Replace this with actual data fetching logic)
    func loadData() {
        // Example data generation
        waterIntakeData = WaterIntakeEntry.generateSampleData()
    }
}

enum TimeRange: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    
    var id: String { self.rawValue }
}

struct TimeRangePicker: View {
    @Binding var value: TimeRange
    
    var body: some View {
        Picker("Time Range", selection: $value) {
            ForEach(TimeRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
}

#Preview {
    DataView()
        .environmentObject(HealthManager())
}
