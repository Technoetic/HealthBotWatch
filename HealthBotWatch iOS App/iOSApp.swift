import SwiftUI
import BackgroundTasks

@main
struct HealthBotIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            IOSContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static let bgTaskID = "com.technoetic.HealthBotWatch.healthsync"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.bgTaskID, using: nil) { task in
            self.handleBackgroundTask(task as! BGAppRefreshTask)
        }
        iOSHealthManager.shared.requestAuthorization { _ in }
        scheduleNextRefresh()
        return true
    }

    func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.bgTaskID)
        request.earliestBeginDate = nextQuarterHour()
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("BG task schedule failed: \(error)")
        }
    }

    private func nextQuarterHour() -> Date {
        let cal = Calendar.current
        let now = Date()
        let minute = cal.component(.minute, from: now)
        let nextSlot = ((minute / 15) + 1) * 15
        var components = cal.dateComponents([.year, .month, .day, .hour], from: now)
        if nextSlot >= 60 {
            components.hour! += 1
            components.minute = 0
        } else {
            components.minute = nextSlot
        }
        components.second = 0
        return cal.date(from: components) ?? now.addingTimeInterval(15 * 60)
    }

    func handleBackgroundTask(_ task: BGAppRefreshTask) {
        scheduleNextRefresh()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        iOSHealthManager.shared.collectAndSend { success in
            task.setTaskCompleted(success: success)
        }
    }
}
