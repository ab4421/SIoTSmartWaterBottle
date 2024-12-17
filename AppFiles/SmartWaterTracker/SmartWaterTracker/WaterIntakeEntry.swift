//
//  WaterIntakeEntry.swift
//  SmartWaterTracker
//
//  Created by Arnav Bhatia on 25/11/2024.
//


import Foundation

struct WaterIntakeEntry: Identifiable {
    let id = UUID()
    let date: Date
    let volume: Double // in milliliters
}

extension Array where Element == WaterIntakeEntry {
    // Group entries by hour and sum the volumes
    func groupByHour() -> [WaterIntakeEntry] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: self) { entry in
            calendar.dateInterval(of: .hour, for: entry.date)?.start ?? entry.date
        }
        return grouped.map { (key, entries) in
            WaterIntakeEntry(date: key, volume: entries.reduce(0) { $0 + $1.volume })
        }
        .sorted { $0.date < $1.date }
    }
    
    // Group entries by day and sum the volumes
    func groupByDay() -> [WaterIntakeEntry] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: self) { entry in
            calendar.startOfDay(for: entry.date)
        }
        return grouped.map { (key, entries) in
            WaterIntakeEntry(date: key, volume: entries.reduce(0) { $0 + $1.volume })
        }
        .sorted { $0.date < $1.date }
    }
}

extension WaterIntakeEntry {
    // Generate sample data for testing
    static func generateSampleData() -> [WaterIntakeEntry] {
        var entries: [WaterIntakeEntry] = []
        let calendar = Calendar.current
        let now = Date()
        
        // Generate data for the past 7 days
        for dayOffset in 0..<7 {
            let dayDate = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            for hour in 0..<24 {
                let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayDate)!
                let volume = Double.random(in: 0...200) // Random volume between 0 and 200 mL
                let entry = WaterIntakeEntry(date: date, volume: volume)
                entries.append(entry)
            }
        }
        return entries
    }
}

extension Array where Element == WaterIntakeEntry {
    func totalVolumeByHour() -> [WaterIntakeEntry] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: self) { entry in
            calendar.component(.hour, from: entry.date)
        }
        return grouped.map { (hour, entries) in
            let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
            let totalVolume = entries.reduce(0) { $0 + $1.volume }
            return WaterIntakeEntry(date: date, volume: totalVolume)
        }
        .sorted { $0.date < $1.date }
    }
}

extension Array where Element == WaterIntakeEntry {
    func groupedByHour() -> [WaterIntakeEntry] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: self) { entry in
            calendar.date(bySetting: .minute, value: 0, of: entry.date)!
        }
        return grouped.map { (date, entries) in
            WaterIntakeEntry(date: date, volume: entries.reduce(0) { $0 + $1.volume })
        }
        .sorted { $0.date < $1.date }
    }
}

extension Array where Element == WaterIntakeEntry {
    func groupedByDay(startingFrom startDate: Date) -> [WaterIntakeEntry] {
        let calendar = Calendar.current
        // Define the start and end dates for the week
        let startOfWeek = calendar.startOfDay(for: startDate)
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
        
        // Filter data within the week range
        let weekData = self.filter { entry in
            calendar.isDate(entry.date, inSameDayAs: startOfWeek) ||
            (entry.date > startOfWeek && entry.date < endOfWeek)
        }
        
        // Group by weekday component
        let grouped = Dictionary(grouping: weekData) { entry in
            calendar.component(.weekday, from: entry.date)
        }
        
        // Sum volumes for each day
        return (1...7).map { weekday in
            let totalVolume = grouped[weekday]?.reduce(0) { $0 + $1.volume } ?? 0
            let date = calendar.date(byAdding: .day, value: weekday - calendar.component(.weekday, from: startOfWeek), to: startOfWeek)!
            return WaterIntakeEntry(date: date, volume: totalVolume)
        }
    }
}
