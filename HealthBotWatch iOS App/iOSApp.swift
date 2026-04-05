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
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("BG task schedule failed: \(error)")
        }
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
