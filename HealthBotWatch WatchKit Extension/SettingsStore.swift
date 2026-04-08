import Foundation
import Combine

/// 앱 설정 (서버 URL, 토큰) UserDefaults 저장
class SettingsStore: ObservableObject {

    static let shared = SettingsStore()

    private let keyToken = "hb_token"
    private let keyServerURL = "hb_server_url"
    private let keyAutoUpload = "hb_auto_upload"
    private let keyUploadInterval = "hb_upload_interval"

    @Published var token: String {
        didSet { UserDefaults.standard.set(token, forKey: keyToken) }
    }

    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: keyServerURL) }
    }

    /// 자동 업로드 활성화 여부 (Background Delivery 연동)
    @Published var autoUploadEnabled: Bool {
        didSet { UserDefaults.standard.set(autoUploadEnabled, forKey: keyAutoUpload) }
    }

    /// 수동 업로드 간격 (분) — BackgroundTask 스케줄 주기
    @Published var uploadIntervalMinutes: Int {
        didSet { UserDefaults.standard.set(uploadIntervalMinutes, forKey: keyUploadInterval) }
    }

    var isConfigured: Bool {
        true
    }

    private init() {
        token = UserDefaults.standard.string(forKey: "hb_token") ?? ""
        serverURL = UserDefaults.standard.string(forKey: "hb_server_url") ?? ""
        autoUploadEnabled = UserDefaults.standard.bool(forKey: "hb_auto_upload")
        uploadIntervalMinutes = UserDefaults.standard.integer(forKey: "hb_upload_interval")
        if uploadIntervalMinutes == 0 { uploadIntervalMinutes = 30 }
    }
}
