import Foundation
import Combine

class HealthViewModel: ObservableObject {
    private let healthManager = HealthManager()
    private var timer: Timer?
    private let interval: TimeInterval = 5 * 60 // 5분

    @Published var heartRateText = "--"
    @Published var spo2Text = "--"
    @Published var hrvText = "--"
    @Published var stepsText = "--"
    @Published var sleepText = "--"
    @Published var statusText = "연결 중..."
    @Published var isConnected = false
    @Published var isSending = false
    @Published var lastSentTime: String?
    @Published var nextAutoSendText = "5:00"

    private var countdown: Int = 300
    private var countdownTimer: Timer?

    func start() {
        healthManager.requestAuthorization { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.statusText = "HealthKit 연결됨"
                    self?.isConnected = true
                    self?.sendNow()
                    self?.startAutoTimer()
                } else {
                    self?.statusText = "권한 거부됨"
                }
            }
        }
    }

    func sendNow() {
        guard !isSending else { return }
        isSending = true
        healthManager.collectAllData { [weak self] data in
            self?.updateDisplay(data: data)
            APIClient.shared.sendHealthData(data) { result in
                DispatchQueue.main.async {
                    self?.isSending = false
                    switch result {
                    case .success:
                        self?.isConnected = true
                        self?.statusText = "전송 완료"
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        self?.lastSentTime = formatter.string(from: Date())
                        self?.resetCountdown()
                    case .failure:
                        self?.isConnected = false
                        self?.statusText = "전송 실패"
                    }
                }
            }
        }
    }

    private func updateDisplay(data: HealthData) {
        DispatchQueue.main.async {
            self.heartRateText = data.heartRate.map { "\(Int($0)) bpm" } ?? "--"
            self.spo2Text = data.bloodOxygen.map { String(format: "%.1f%%", $0) } ?? "--"
            self.hrvText = data.hrv.map { String(format: "%.0f ms", $0) } ?? "--"
            self.stepsText = data.steps.map { "\($0) 보" } ?? "--"
            self.sleepText = data.sleepHours.map { String(format: "%.1f h", $0) } ?? "--"
        }
    }

    private func startAutoTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sendNow()
        }
        startCountdown()
    }

    private func startCountdown() {
        countdown = Int(interval)
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.countdown -= 1
            let m = self.countdown / 60
            let s = self.countdown % 60
            self.nextAutoSendText = String(format: "%d:%02d", m, s)
            if self.countdown <= 0 { self.resetCountdown() }
        }
    }

    private func resetCountdown() {
        countdown = Int(interval)
        countdownTimer?.invalidate()
        startCountdown()
    }
}
