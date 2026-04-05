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
    static let baseURL = "https://health-care-bot-production.up.railway.app"
    static let token = "user_479945484"
    var pollTimer: Timer?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.bgTaskID, using: nil) { task in
            self.handleBackgroundTask(task as! BGAppRefreshTask)
        }
        iOSHealthManager.shared.requestAuthorization { _ in }
        scheduleNextRefresh()
        startPolling()
        return true
    }

    // MARK: - 포그라운드 폴링 (30초마다 쿼리 체크)
    func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkPending()
        }
    }

    func checkPending() {
        guard let url = URL(string: "\(Self.baseURL)/pending?token=\(Self.token)") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pending = json["pending"] as? Bool, pending else { return }

            if let query = json["query"] as? [String: Any] {
                // 쿼리 요청 처리
                let startDate = query["start_date"] as? String ?? ""
                let endDate = query["end_date"] as? String ?? ""
                self?.handleQuery(startDate: startDate, endDate: endDate)
            } else {
                // 일반 전송 요청
                iOSHealthManager.shared.collectAndSend { _ in }
            }
        }.resume()
    }

    func handleQuery(startDate: String, endDate: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let start = formatter.date(from: startDate) ?? Calendar.current.startOfDay(for: Date())
        let end = formatter.date(from: endDate)?.addingTimeInterval(86400) ?? Date()

        iOSHealthManager.shared.collectRange(start: start, end: end) { records in
            self.sendQueryResponse(records: records)
        }
    }

    func sendQueryResponse(records: [[String: Any]]) {
        guard let url = URL(string: "\(Self.baseURL)/health/query-response") else { return }
        let body: [String: Any] = ["token": Self.token, "records": records]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = jsonData
        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }

    // MARK: - 백그라운드 정기 전송
    func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.bgTaskID)
        request.earliestBeginDate = nextQuarterHour()
        try? BGTaskScheduler.shared.submit(request)
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
        task.expirationHandler = { task.setTaskCompleted(success: false) }

        // 백그라운드에서도 pending 체크
        checkPending()

        iOSHealthManager.shared.collectAndSend { success in
            task.setTaskCompleted(success: success)
        }
    }
}
