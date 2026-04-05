import Foundation
import Combine

class HealthViewModel: ObservableObject {
    private let healthManager = HealthManager()

    @Published var heartRateText = "--"
    @Published var spo2Text = "--"
    @Published var hrvText = "--"
    @Published var stepsText = "--"
    @Published var sleepText = "--"
    @Published var statusText = "연결 중..."
    @Published var isConnected = false

    func start() {
        healthManager.requestAuthorization { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.statusText = "HealthKit 연결됨"
                    self?.isConnected = true
                    self?.refresh()
                } else {
                    self?.statusText = "권한 거부됨"
                }
            }
        }
    }

    func refresh() {
        healthManager.collectAllData { [weak self] data in
            DispatchQueue.main.async {
                self?.heartRateText = data.heartRate.map { "\(Int($0)) bpm" } ?? "--"
                self?.spo2Text = data.bloodOxygen.map { String(format: "%.1f%%", $0) } ?? "--"
                self?.hrvText = data.hrv.map { String(format: "%.0f ms", $0) } ?? "--"
                self?.stepsText = data.steps.map { "\($0) 보" } ?? "--"
                self?.sleepText = data.sleepHours.map { String(format: "%.1f h", $0) } ?? "--"
                self?.statusText = "iPhone이 데이터 전송 중"
            }
        }
    }
}
