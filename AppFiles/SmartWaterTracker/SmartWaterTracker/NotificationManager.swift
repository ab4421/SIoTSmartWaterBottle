import Foundation
import UserNotifications

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    @Published var lastIntakeHour: Int = -1
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private let encouragingMessages = [
        "Time for a water break! Stay hydrated, stay healthy! 💧",
        "Your body needs water to function at its best. Take a sip! 🌊",
        "Hydration check! Keep up with your water intake goals! 🎯",
        "A glass of water keeps the doctor away! Time to drink! 🏥",
        "Stay on track with your hydration goals - have some water! 🌟",
        "Your future self will thank you for staying hydrated! 🙏",
        "Water is life! Don't forget your hourly intake! ✨",
        "Quick reminder: Hydration leads to better performance! 💪",
        "Take a moment to refresh with some water! 🌿",
        "Keep that energy flowing with proper hydration! ⚡️"
    ]
    
    override init() {
        super.init()
        notificationCenter.delegate = self
        requestPermissions()
        setupHourlyNotifications()
    }
    
    func requestPermissions() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permissions: \(error.localizedDescription)")
            }
        }
    }
    
    func updateLastIntakeHour() {
        lastIntakeHour = Calendar.current.component(.hour, from: Date())
    }
    
    func setupHourlyNotifications() {
        // Remove any existing notifications
        notificationCenter.removeAllPendingNotificationRequests()
        
        // Create notifications for each hour
        for hour in 0..<24 {
            scheduleNotification(for: hour)
        }
    }
    
    private func scheduleNotification(for hour: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Water Reminder"
        content.body = encouragingMessages[hour % encouragingMessages.count]
        content.sound = .default
        
        // Set up date components for 55 minutes past the hour
        var components = DateComponents()
        components.hour = hour
        components.minute = 55
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "waterReminder-\(hour)", content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    // UNUserNotificationCenterDelegate method
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Check if there was water intake in the current hour
        let currentHour = Calendar.current.component(.hour, from: Date())
        if currentHour != lastIntakeHour {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([])
        }
    }
} 