import SwiftUI

struct IOSContentView: View {
    @State private var lastSent: Date? = nil
    @State private var status: String = "대기 중..."
    @State private var timer: Timer? = nil

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            Text("HealthBot")
                .font(.title.bold())
            Text("건강 데이터를 LongRun에 자동 전송합니다.\n매 0, 15, 30, 45분에 전송됩니다.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.body)

            Text(status)
                .font(.caption)
                .foregroundColor(status.hasPrefix("✅") ? .green : .secondary)

            if let t = lastSent {
                Text("마지막 전송: \(t, style: .relative) 전")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Button("지금 전송") {
                sendNow()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear {
            iOSHealthManager.shared.requestAuthorization { _ in
                sendNow()
            }
            startQuarterHourTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func sendNow() {
        status = "전송 중..."
        iOSHealthManager.shared.collectAndSend { success in
            DispatchQueue.main.async {
                if success {
                    lastSent = Date()
                    status = "✅ 전송 완료"
                } else {
                    status = "❌ 전송 실패"
                }
            }
        }
    }

    private func startQuarterHourTimer() {
        timer?.invalidate()
        let now = Date()
        let cal = Calendar.current
        let minute = cal.component(.minute, from: now)
        let nextSlot = (minute / 15 + 1) * 15
        var nextFire = cal.date(bySetting: .minute, value: nextSlot % 60, of: now)!
        nextFire = cal.date(bySetting: .second, value: 0, of: nextFire)!
        if nextSlot >= 60 {
            nextFire = cal.date(byAdding: .hour, value: 1, to: nextFire)!
        }
        if nextFire <= now { nextFire = cal.date(byAdding: .minute, value: 15, to: nextFire)! }
        let delay = nextFire.timeIntervalSince(now)

        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            self.sendNow()
            self.timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { _ in
                self.sendNow()
            }
        }
    }
}
