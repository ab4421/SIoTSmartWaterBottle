//
//  HealthManager.swift
//  SmartWaterTracker
//
//  Created by Arnav Bhatia on 29/11/2024.
//

import Foundation
import HealthKit

extension Date {
    static var startOfDay: Date {
        Calendar.current.startOfDay(for: Date())
    }
}

class HealthManager: ObservableObject {
    
    let healthStore = HKHealthStore()
    
    @Published var activites: [String : Activity] = [:]
    @Published var waterIntakeGoal: Int = 0
    @Published var calculatedWaterIntakeGoal: Int = 0
    
    init() {
        if HKHealthStore.isHealthDataAvailable() {
            print("HealthKit is available")
            let exerciseMinutes = HKQuantityType(.appleExerciseTime)
            let bodyMass = HKQuantityType(.bodyMass)
            let height = HKQuantityType(.height)
            let dateOfBirth = HKCharacteristicType(.dateOfBirth)
            let healthTypes: Set = [exerciseMinutes, bodyMass, height, dateOfBirth]
            
            Task {
                do {
                    try await healthStore.requestAuthorization(toShare: [], read: healthTypes)
                    print("HealthKit authorization granted")
                    await MainActor.run {
                        fetchTodayExerciseMinutes()
                        fetchLatestBodyWeight()
                        fetchLatestHeight()
                        fetchAge()
                    }
                } catch {
                    print("Error requesting health authorization: \(error.localizedDescription)")
                }
            }
        } else {
            print("HealthKit is not available on this device")
        }
    }
    
    func calculateWaterIntakeGoal() {
        guard let weightActivity = activites["bodyWeight"],
              let exerciseActivity = activites["todayExerciseMinutes"] else {
            print("Missing required data for water intake calculation")
            return
        }
        
        // Extract weight and exercise values
        let weightString = weightActivity.amount.replacingOccurrences(of: " kg", with: "")
        let exerciseString = exerciseActivity.amount.replacingOccurrences(of: " min", with: "")
        
        guard let weight = Double(weightString),
              let exerciseTime = Double(exerciseString) else {
            print("Could not parse weight or exercise values")
            return
        }
        
        // Calculate water intake: Weight(kg) * 31.256 + Exercise time(min) * 11.34
        let waterIntake = weight * 31.256 + exerciseTime * 11.34
        
        // Round up to nearest mL
        DispatchQueue.main.async {
            self.calculatedWaterIntakeGoal = Int(ceil(waterIntake))
            if self.waterIntakeGoal == 0 {
                self.waterIntakeGoal = self.calculatedWaterIntakeGoal
            }
            print("Calculated water intake goal: \(self.calculatedWaterIntakeGoal) mL")
        }
    }
    
    func resetToCalculatedGoal() {
        waterIntakeGoal = calculatedWaterIntakeGoal
    }
    
    func fetchTodayExerciseMinutes() {
        print("Fetching exercise minutes...")
        let exerciseMinutes = HKQuantityType(.appleExerciseTime)
        let predicate = HKQuery.predicateForSamples(withStart: .startOfDay, end: Date())
        let query = HKStatisticsQuery(quantityType: exerciseMinutes, quantitySamplePredicate: predicate) { [weak self] _, result, error in
            guard let self = self else {
                print("Self is nil in query callback")
                return
            }
            
            if let error = error {
                print("Error fetching exercise minutes: \(error.localizedDescription)")
                return
            }
            
            guard let result = result else {
                print("No result returned from query")
                DispatchQueue.main.async {
                    self.activites["todayExerciseMinutes"] = Activity(id: 0, title: "Exercise Time", subtitle: "Today", image: "figure.run", amount: "0 min")
                    self.calculateWaterIntakeGoal()
                }
                return
            }
            
            let minutes = result.sumQuantity()?.doubleValue(for: .minute()) ?? 0
            print("Fetched exercise minutes: \(minutes)")
            
            DispatchQueue.main.async {
                self.activites["todayExerciseMinutes"] = Activity(id: 0, title: "Exercise Time", subtitle: "Today", image: "figure.run", amount: "\(minutes.formattedString()) min")
                self.calculateWaterIntakeGoal()
            }
        }
        
        healthStore.execute(query)
        print("Query executed")
    }
    
    func fetchLatestBodyWeight() {
        print("Fetching body weight...")
        let bodyMass = HKQuantityType(.bodyMass)
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: bodyMass,
                                predicate: nil,
                                limit: 1,
                                sortDescriptors: [sortDescriptor]) { [weak self] (query, samples, error) in
            guard let self = self else {
                print("Self is nil in query callback")
                return
            }
            
            if let error = error {
                print("Error fetching body weight: \(error.localizedDescription)")
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                print("No body weight data available")
                DispatchQueue.main.async {
                    self.activites["bodyWeight"] = Activity(id: 1, title: "Body Weight", subtitle: "Latest", image: "figure.arms.open", amount: "No Data")
                    self.calculateWaterIntakeGoal()
                }
                return
            }
            
            let weightInKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            print("Fetched body weight: \(weightInKg) kg")
            
            DispatchQueue.main.async {
                self.activites["bodyWeight"] = Activity(id: 1, title: "Body Weight", subtitle: "Latest", image: "figure.arms.open", amount: "\(weightInKg.formattedString()) kg")
                self.calculateWaterIntakeGoal()
            }
        }
        
        healthStore.execute(query)
        print("Weight query executed")
    }
    
    func fetchLatestHeight() {
        print("Fetching height...")
        let height = HKQuantityType(.height)
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: height,
                                predicate: nil,
                                limit: 1,
                                sortDescriptors: [sortDescriptor]) { [weak self] (query, samples, error) in
            guard let self = self else {
                print("Self is nil in query callback")
                return
            }
            
            if let error = error {
                print("Error fetching height: \(error.localizedDescription)")
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                print("No height data available")
                DispatchQueue.main.async {
                    self.activites["height"] = Activity(id: 2, title: "Height", subtitle: "Latest", image: "figure.arms.open", amount: "No Data")
                }
                return
            }
            
            let heightInCm = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
            print("Fetched height: \(heightInCm) cm")
            
            DispatchQueue.main.async {
                // Format to 3 significant figures
                let formattedHeight = String(format: "%.0f", heightInCm)
                self.activites["height"] = Activity(id: 2, title: "Height", subtitle: "Latest", image: "figure.arms.open", amount: "\(formattedHeight) cm")
                print("Updated activities: \(self.activites)")
            }
        }
        
        healthStore.execute(query)
        print("Height query executed")
    }
    
    func fetchAge() {
        print("Fetching age...")
        do {
            let birthdayComponents = try healthStore.dateOfBirthComponents()
            guard let dateOfBirth = birthdayComponents.date else {
                print("No date of birth available")
                DispatchQueue.main.async {
                    self.activites["age"] = Activity(id: 3, title: "Age", subtitle: "Years", image: "person.crop.circle", amount: "No Data")
                }
                return
            }
            
            let now = Date()
            let calendar = Calendar.current
            let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: now)
            
            guard let age = ageComponents.year else {
                print("Could not calculate age")
                return
            }
            
            print("Calculated age: \(age) years")
            
            DispatchQueue.main.async {
                self.activites["age"] = Activity(id: 3, title: "Age", subtitle: "Years", image: "person.crop.circle", amount: "\(age) yrs")
            }
            
        } catch {
            print("Error fetching date of birth: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.activites["age"] = Activity(id: 3, title: "Age", subtitle: "Years", image: "person.crop.circle", amount: "No Access")
            }
        }
    }
}

extension Double {
    func formattedString() -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 0
        return numberFormatter.string(from: NSNumber(value: self)) ?? "0"
    }
}
