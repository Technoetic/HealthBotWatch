# HealthBot Watch App

Apple Watch에서 건강 데이터를 수집하여 health-care-bot 백엔드로 5분마다 자동 전송하는 watchOS 앱.

## 기능

- 심박수, HRV, 산소포화도, 걸음수, 수면시간, 활동 칼로리 수집
- 5분마다 자동 전송
- 수동 즉시 전송 버튼
- 전송 상태 및 카운트다운 표시

## 백엔드

- URL: https://health-care-bot-production.up.railway.app/health
- Token: user_479945484

## 빌드 방법

### GitHub Actions (권장 - Windows에서 개발)

1. 이 레포를 GitHub에 push
2. Actions 탭 → Build watchOS App 실행
3. macOS runner가 자동 빌드

### 실기기 배포

1. Apple Developer 계정으로 Xcode에서 서명
2. Team ID: X638Y8296Z
3. Bundle ID: com.technoetic.HealthBotWatch

## 요구사항

- watchOS 10.0+
- Apple Watch Series 4 이상
- HealthKit 권한 필요
