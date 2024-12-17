import SwiftUI
import Charts

struct DailyWaterIntakeChart: View {
    let date: Date
    let data: [WaterIntakeEntry]
    @State private var rawSelectedDate: Date?
    
    // Computed property to find the matching hour's data
    private var selectedData: WaterIntakeEntry? {
        guard let rawSelectedDate else { return nil }
        return data.first { entry in
            let entryHourStart = Calendar.current.startOfHour(for: entry.date)
            let entryHourEnd = Calendar.current.date(byAdding: .hour, value: 1, to: entryHourStart)!
            return (entryHourStart...entryHourEnd).contains(rawSelectedDate)
        }
    }

    var body: some View {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let xDomain = startOfDay...endOfDay
        
        let xAxisValues: [Date] = [0, 6, 12, 18].compactMap { hour in
            Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date)
        }
        
        let hourlyData = data.groupedByHour()

        Chart {
            ForEach(hourlyData) { entry in
                BarMark(
                    x: .value("Time", entry.date),
                    y: .value("Volume", entry.volume)
                )
                .foregroundStyle(.blue)
            }
            
            // Add selection indicator
            if let selectedData {
                RuleMark(
                    x: .value("Selected", selectedData.date)
                )
                .foregroundStyle(Color.gray.opacity(0.3))
                .offset(yStart: -10)
                .zIndex(-1)
                .annotation(
                    position: .top,
                    spacing: 0,
                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                ) {
                    VolumePopover(entry: selectedData)
                }
            }
        }
        .chartXScale(domain: xDomain)
        .chartXAxis {
            AxisMarks(values: xAxisValues) { value in
                if let date = value.as(Date.self) {
                    AxisGridLine()
                        .foregroundStyle(.gray)
                    AxisTick()
                    AxisValueLabel {
                        Text(date, format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                    }
                }
            }
        }
        .chartXAxisLabel("Time")
        .chartYAxis {
            AxisMarks(position: .trailing)
        }
        .chartYAxisLabel("Volume (mL)")
        .frame(height: 240)
        .chartXSelection(value: $rawSelectedDate)
    }
}

// Popover view for showing the volume details
struct VolumePopover: View {
    let entry: WaterIntakeEntry
    
    private var timeRangeString: String {
        let startDate = entry.date
        let formatter = DateFormatter()
        
        // Format like "1 Dec"
        formatter.dateFormat = "d MMM"
        let dateString = formatter.string(from: startDate)
        
        // Format hours like "11 am - 12 pm"
        let hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "h a"
        
        let startHourString = hourFormatter.string(from: startDate)
        let endHourDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate)!
        let endHourString = hourFormatter.string(from: endHourDate)
        
        return "\(dateString), \(startHourString) - \(endHourString)"
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
            
            Text(timeRangeString)
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

// Helper extension for Calendar
extension Calendar {
    func startOfHour(for date: Date) -> Date {
        let components = dateComponents([.year, .month, .day, .hour], from: date)
        return self.date(from: components) ?? date
    }
}

#Preview {
    // Generate sample data for the entire day
    let date = Date()
    let sampleData = (0...23).flatMap { hour -> [WaterIntakeEntry] in
        let entriesPerHour = Int.random(in: 1...3)
        return (0..<entriesPerHour).compactMap { _ in
            let minute = Int.random(in: 0...59)
            let volume = Double.random(in: 0...250)
            if let entryDate = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date) {
                return WaterIntakeEntry(date: entryDate, volume: volume)
            } else {
                return nil
            }
        }
    }
    return DailyWaterIntakeChart(date: date, data: sampleData)
}
