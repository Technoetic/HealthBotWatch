import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = HealthViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 상태 헤더
                HStack {
                    Circle()
                        .fill(viewModel.isConnected ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(viewModel.statusText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                // 건강 데이터 카드
                VStack(spacing: 6) {
                    HealthRow(icon: "❤️", label: "심박수", value: viewModel.heartRateText)
                    HealthRow(icon: "💧", label: "산소포화도", value: viewModel.spo2Text)
                    HealthRow(icon: "🧠", label: "HRV", value: viewModel.hrvText)
                    HealthRow(icon: "👟", label: "걸음수", value: viewModel.stepsText)
                    HealthRow(icon: "😴", label: "수면", value: viewModel.sleepText)
                }
                .padding(10)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(10)

                // 마지막 전송 시간
                if let lastSent = viewModel.lastSentTime {
                    Text("마지막 전송: \(lastSent)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // 수동 전송 버튼
                Button(action: { viewModel.sendNow() }) {
                    HStack {
                        if viewModel.isSending {
                            ProgressView().progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                        }
                        Text(viewModel.isSending ? "전송 중..." : "지금 전송")
                    }
                    .font(.footnote.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(viewModel.isSending)

                // 다음 자동 전송까지
                Text("다음 자동 전송: \(viewModel.nextAutoSendText)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
        }
        .onAppear { viewModel.start() }
    }
}

struct HealthRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(icon).font(.caption)
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption.bold())
        }
    }
}
