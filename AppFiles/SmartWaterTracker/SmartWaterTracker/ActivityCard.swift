//
//  ActivityCard.swift
//  SmartWaterTracker
//
//  Created by Arnav Bhatia on 29/11/2024.
//

import SwiftUI

struct Activity {
    let id: Int
    let title: String
    let subtitle: String
    let image: String
    let amount: String
}

struct ActivityCard: View {
    @State var activity: Activity
    var body: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text(activity.title)
                        .font(.headline)
                    Text(activity.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                    
                Spacer()
                
                Image(systemName: activity.image)
                    .font(.title)
                    .foregroundColor(.green)
                
            }
            .padding()
            
            Text(activity.amount)
                .font(.title)
                .padding(.bottom)
                
        }
        
        .background(.tertiary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        
    }
}

#Preview {
    ActivityCard(activity: Activity(id: 0, title: "Exercise Minutes", subtitle: "Today", image: "figure.run", amount: "100"))
}
