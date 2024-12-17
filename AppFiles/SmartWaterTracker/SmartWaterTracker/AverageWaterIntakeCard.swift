import SwiftUI

struct AverageWaterIntakeCard: View {
    let data: [WaterIntakeEntry]
    
    private var averageIntake: Double {
        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: now)!
        
        // Group data by day
        let dailyData = Dictionary(grouping: data) { entry in
            calendar.startOfDay(for: entry.date)
        }
        .filter { date, _ in
            date >= sevenDaysAgo && date <= now
        }
        .mapValues { entries in
            entries.reduce(0) { $0 + $1.volume }
        }
        
        // Calculate average
        let total = dailyData.values.reduce(0, +)
        return total / Double(max(dailyData.count, 1))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.blue)
                Text("Average Water Intake")
                    .font(.headline)
            }
            
            Text("The last 7 days you drank an average of")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(averageIntake))")
                    .font(.title.bold())
                Text("mL")
                    .font(.body)
                Text("a day")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 1, x: 0, y: 1)
        }
    }
}

#Preview {
    AverageWaterIntakeCard(data: WaterIntakeEntry.generateSampleData())
        .padding()
        .background(Color(.systemGray6))
} 