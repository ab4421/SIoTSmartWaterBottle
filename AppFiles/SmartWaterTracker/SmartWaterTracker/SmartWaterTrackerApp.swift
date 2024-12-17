//
//  SmartWaterTrackerApp.swift
//  SmartWaterTracker
//
//  Created by Arnav Bhatia on 15/11/2024.
//

import SwiftUI

@main
struct SmartWaterTrackerApp: App {
    @StateObject var healthManager = HealthManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthManager)
        }
    }
}
