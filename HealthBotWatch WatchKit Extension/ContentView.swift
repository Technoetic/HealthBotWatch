import SwiftUI

struct ContentView: View {

    @StateObject private var health = HealthManager.shared
    @StateObject private var settings = SettingsStore.shared
    @State private var showSettings = false
    @State private var autoTimer: Timer? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {

                    // --- 상태 헤더 ---
                    StatusHeaderView(health: health)

                    // --- 즉시 전송 버튼 ---
                    Button(action: uploadNow) {
                        HStack {
                            if health.isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                            }
                            Text(health.isUploading ? "전송 중..." : "지금 전송")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(settings.isConfigured ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(health.isUploading || !settings.isConfigured)

                    // --- 마지막 전송 결과 ---
                    if !health.lastUploadResult.isEmpty {
                        Text(health.lastUploadResult)
                            .font(.caption2)
                            .foregroundColor(health.lastUploadResult.hasPrefix("✅") ? .green : .secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let time = health.lastUploadTime {
                        Text("마지막: \(time, style: .relative) 전")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // --- 설정 버튼 ---
                    NavigationLink(destination: SettingsView(), isActive: $showSettings) {
                        EmptyView()
                    }
                    Button(action: { showSettings = true }) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text(settings.isConfigured ? "설정 변경" : "설정 필요")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.2))
                        .foregroundColor(settings.isConfigured ? .primary : .orange)
                        .cornerRadius(10)
                    }

                    // --- 자동 전송 토글 ---
                    if settings.isConfigured {
                        Toggle(isOn: $settings.autoUploadEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("자동 전송")
                                    .font(.caption)
                                Text("백그라운드에서 자동 업로드")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onChange(of: settings.autoUploadEnabled) { enabled in
                            if enabled {
                                if #available(watchOS 8.0, *) {
                                    health.enableBackgroundDelivery(
                                        token: settings.token,
                                        serverURL: settings.serverURL
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .navigationTitle("HealthBot")
        }
        .onAppear {
            health.requestAuthorization { _ in
                if settings.autoUploadEnabled && settings.isConfigured {
                    if #available(watchOS 8.0, *) {
                        health.enableBackgroundDelivery(
                            token: settings.token,
                            serverURL: settings.serverURL
                        )
                    }
                }
            }
            // 포그라운드 자동 전송 Timer (15분 간격)
            startAutoTimer()
        }
        .onDisappear {
            autoTimer?.invalidate()
            autoTimer = nil
        }
    }

    private func uploadNow() {
        guard settings.isConfigured else { return }
        health.collectAndUpload(
            token: settings.token,
            serverURL: settings.serverURL
        )
    }

    private func startAutoTimer() {
        autoTimer?.invalidate()
        guard settings.isConfigured else { return }
        // 포그라운드 15분 간격 자동 전송
        autoTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { _ in
            guard !health.isUploading && settings.isConfigured else { return }
            health.collectAndUpload(
                token: settings.token,
                serverURL: settings.serverURL
            )
        }
    }
}

// MARK: - 상태 헤더

struct StatusHeaderView: View {
    @ObservedObject var health: HealthManager

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.title2)
                .foregroundColor(.red)

            Text("건강 데이터 전송")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("iPhone 잠금 상태에서도\n자동으로 서버에 전송합니다")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
