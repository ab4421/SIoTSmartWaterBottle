//
//  WeeklyWaterIntakeChart.swift
//  SmartWaterTracker
//
//  Created by Arnav Bhatia on 25/11/2024.
//

import SwiftUI
import Charts

struct WeeklyWaterIntakeChart: View {
    let startingFrom: Date
    let data: [WaterIntakeEntry]
    @State private var selectedDay: String?
    @EnvironmentObject var healthManager: HealthManager
    
    // Computed property to find the matching day's data
    private var selectedData: WaterIntakeEntry? {
        guard let selectedDay else { return nil }
        return data.groupedByDay(startingFrom: startingFrom).first { entry in
            shortWeekdaySymbol(for: Calendar.current.component(.weekday, from: entry.date)) == selectedDay
        }
    }

    var body: some View {
        let xAxisValues: [String] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let dailyData = data.groupedByDay(startingFrom: startingFrom)

        Chart {
            ForEach(dailyData) { entry in
                let day = shortWeekdaySymbol(for: Calendar.current.component(.weekday, from: entry.date))
                BarMark(
                    x: .value("Day", day),
                    y: .value("Volume", entry.volume)
                )
                .foregroundStyle(.blue)
            }

            RuleMark(y: .value("Goal", Double(healthManager.waterIntakeGoal)))
                .foregroundStyle(.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                .annotation(position: .top, alignment: .leading) {
                    Text("Goal: \(healthManager.waterIntakeGoal) mL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            
            // Add selection indicator
            if let selectedData {
                let day = shortWeekdaySymbol(for: Calendar.current.component(.weekday, from: selectedData.date))
                RuleMark(
                    x: .value("Selected", day)
                )
                .foregroundStyle(Color.gray.opacity(0.3))
                .offset(yStart: -10)
                .zIndex(-1)
                .annotation(
                    position: .top,
                    spacing: 0,
                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                ) {
                    WeeklyVolumePopover(entry: selectedData)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: xAxisValues) { value in
                if let day = value.as(String.self) {
                    AxisGridLine()
                        .foregroundStyle(.gray.opacity(0.5))
                    AxisTick()
                    AxisValueLabel {
                        Text(day)
                            .font(.subheadline)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing)
        }
        .chartXAxisLabel("Day of Week")
        .chartYAxisLabel("Water Intake (mL)")
        .padding()
        .frame(height: 300)
        .chartXSelection(value: $selectedDay)
    }

    func shortWeekdaySymbol(for weekday: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let index = (weekday - 1) % 7
        return symbols[index]
    }
}

// Popover view for showing the weekly volume details
struct WeeklyVolumePopover: View {
    let entry: WaterIntakeEntry
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: entry.date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("TOTAL")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(entry.volume))")
                    .font(.title.bold())
                Text("mL")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            
            Text(dateString)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.background)
                .shadow(radius: 2)
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let sampleData: [WaterIntakeEntry] = (0..<7).compactMap { offset in
        guard let date = calendar.date(byAdding: .day, value: offset, to: today) else {
            return nil
        }
        let volume = Double.random(in: 2000...4000)
        return WaterIntakeEntry(date: date, volume: volume)
    }
    return WeeklyWaterIntakeChart(startingFrom: today, data: sampleData)
        .environmentObject(HealthManager())
}
