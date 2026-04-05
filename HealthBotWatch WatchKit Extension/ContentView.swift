import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = HealthViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Circle()
                        .fill(viewModel.isConnected ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(viewModel.statusText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }

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

                Button(action: { viewModel.refresh() }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("새로고침")
                    }
                    .font(.footnote.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
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
