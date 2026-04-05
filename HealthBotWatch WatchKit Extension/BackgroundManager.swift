import Foundation
import WatchKit

class BackgroundManager {
    static let shared = BackgroundManager()

    func scheduleNextRefresh() {
        // Watch는 더 이상 백그라운드 전송하지 않음
        // iPhone이 BGAppRefreshTask로 전송 담당
    }

    func handleBackgroundRefresh(completion: @escaping () -> Void) {
        completion()
    }
}
