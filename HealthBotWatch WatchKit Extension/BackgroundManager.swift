import Foundation
import WatchKit

class BackgroundManager {
    static let shared = BackgroundManager()
    private let healthManager = HealthManager()

    func scheduleNextRefresh() {
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date(timeIntervalSinceNow: 5 * 60),
            userInfo: nil
        ) { error in
            if let error = error {
                print("Background refresh schedule failed: \(error)")
            }
        }
    }

    func handleBackgroundRefresh(completion: @escaping () -> Void) {
        // 1. HealthKit 데이터 수집 + 서버 전송
        healthManager.collectAllData { data in
            APIClient.shared.sendHealthData(data) { _ in
                // 2. pending 체크 + 추가 전송
                APIClient.shared.checkPending { pending in
                    if pending {
                        self.healthManager.collectAllData { freshData in
                            APIClient.shared.sendHealthData(freshData) { _ in
                                completion()
                            }
                        }
                    } else {
                        completion()
                    }
                }
            }
        }
    }
}
