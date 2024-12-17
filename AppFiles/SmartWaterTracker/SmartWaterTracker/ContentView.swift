//
//  ContentView.swift
//  SmartWaterTracker
//
//  Created by Arnav Bhatia on 15/11/2024.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var healthManager: HealthManager
    var body: some View {
        TabView {
            UserView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("User")
                }
            DailyGoal()
                .tabItem {
                    Image(systemName: "checkmark.seal.text.page")
                    Text("Daily Goal")
                }
                .environmentObject(healthManager)

            DebugView()
                .tabItem {
                    Image(systemName: "wrench")
                    Text("Debug")
                }
            
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthManager())
}
