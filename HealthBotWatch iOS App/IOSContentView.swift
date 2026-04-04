import SwiftUI

struct IOSContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "applewatch.watchface")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            Text("HealthBot Watch")
                .font(.title.bold())
            Text("Apple Watch 앱을 사용하세요.\n건강 데이터가 5분마다 자동 전송됩니다.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.body)
        }
        .padding()
    }
}
