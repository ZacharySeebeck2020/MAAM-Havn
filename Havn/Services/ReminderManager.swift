//
//  ReminderManager.swift
//  Havn
//
//  Created by Zac Seebeck on 8/15/25.
//


import UserNotifications
import CoreData
import UIKit

extension Notification.Name {
    static let openTodayEditor = Notification.Name("OpenTodayEditor")
}

final class ReminderManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderManager()
    private let center = UNUserNotificationCenter.current()
    private let id = "daily.reminder"

    func configure() {
        center.delegate = self
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            self.scheduleNextIfNeeded()
        }
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { _ in
            self.scheduleNextIfNeeded()
        }
    }

    func setEnabled(_ on: Bool, hour: Int, minute: Int, context: NSManagedObjectContext) {
        UserDefaults.standard.set(on, forKey: "reminder.enabled")
        UserDefaults.standard.set(hour, forKey: "reminder.hour")
        UserDefaults.standard.set(minute, forKey: "reminder.minute")
        if on { scheduleNextIfNeeded(context: context) }
        else   { center.removePendingNotificationRequests(withIdentifiers: [id]) }
    }

    func scheduleNextIfNeeded(context: NSManagedObjectContext? = nil) {
        let d = UserDefaults.standard
        guard d.bool(forKey: "reminder.enabled") else {
            center.removePendingNotificationRequests(withIdentifiers: [id]); return
        }
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let hour = d.integer(forKey: "reminder.hour")
        let minute = d.integer(forKey: "reminder.minute")

        let cal = Calendar.current
        let now = Date()
        var comps = DateComponents()
        comps.hour = hour; comps.minute = minute
        let todayFire = cal.nextDate(after: cal.startOfDay(for: now),
                                     matching: comps,
                                     matchingPolicy: .nextTimePreservingSmallerComponents) ?? now

        let fire = (todayFire <= now) ? cal.date(byAdding: .day, value: 1, to: todayFire)! : todayFire

        let trigger = UNCalendarNotificationTrigger(dateMatching: cal.dateComponents([.year,.month,.day,.hour,.minute], from: fire), repeats: false)
        let content = UNMutableNotificationContent()
        content.title = "Time to journal"
        content.body = "Add your photo + note for today."
        content.sound = .default
        content.userInfo = ["deeplink": "openTodayEditor"]

        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == id {
            NotificationCenter.default.post(name: .openTodayEditor, object: nil)
        }
        completionHandler()
    }
}
