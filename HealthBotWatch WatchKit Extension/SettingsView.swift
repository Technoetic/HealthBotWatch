import SwiftUI

struct SettingsView: View {

    @StateObject private var settings = SettingsStore.shared
    @State private var tokenInput: String = ""
    @State private var serverInput: String = ""
    @State private var showSaved = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                // --- 서버 URL ---
                VStack(alignment: .leading, spacing: 4) {
                    Text("서버 URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("https://yourserver.com", text: $serverInput)
                        .disableAutocorrection(true)
                        .font(.caption)
                        .padding(6)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(8)
                }

                // --- 이메일 ---
                VStack(alignment: .leading, spacing: 4) {
                    Text("LongRun 이메일")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("example@longrun.app", text: $tokenInput)
                        .disableAutocorrection(true)
                        .font(.caption)
                        .padding(6)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(8)
                }

                // --- 안내 ---
                VStack(alignment: .leading, spacing: 3) {
                    Text("설정 방법")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    Text("1. LongRun 가입 이메일 입력")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("2. 저장 후 자동 전송 시작")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

                // --- 저장 버튼 ---
                Button(action: save) {
                    Text(showSaved ? "저장됨 ✓" : "저장")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(canSave ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!canSave)
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("설정")
        .onAppear {
            tokenInput = settings.token
            serverInput = settings.serverURL
        }
    }

    private var canSave: Bool {
        !tokenInput.trimmingCharacters(in: .whitespaces).isEmpty &&
        !serverInput.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        var url = serverInput.trimmingCharacters(in: .whitespaces)
        if !url.hasPrefix("http") { url = "https://" + url }
        // 트레일링 슬래시 제거
        if url.hasSuffix("/") { url = String(url.dropLast()) }

        settings.token = tokenInput.trimmingCharacters(in: .whitespaces)
        settings.serverURL = url

        withAnimation {
            showSaved = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
