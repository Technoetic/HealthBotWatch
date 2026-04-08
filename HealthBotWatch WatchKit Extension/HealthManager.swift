import Foundation
import HealthKit
import WatchKit

/// Watch에서 직접 HealthKit 읽고 서버로 전송하는 핵심 매니저
class HealthManager: ObservableObject {

    static let shared = HealthManager()
    private let store = HKHealthStore()

    @Published var lastUploadTime: Date? = nil
    @Published var lastUploadResult: String = "아직 전송 없음"
    @Published var isUploading: Bool = false

    // MARK: - HealthKit 권한 요청

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .appleStandTime)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
            HKObjectType.quantityType(forIdentifier: .bloodGlucose)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .vo2Max)!,
            HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        ]

        store.requestAuthorization(toShare: nil, read: readTypes) { success, _ in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    // MARK: - 데이터 수집 & 전송

    func collectAndUpload(token: String, serverURL: String) {
        guard !isUploading else { return }
        DispatchQueue.main.async { self.isUploading = true }

        let group = DispatchGroup()
        var record: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        // 오늘 날짜 범위
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()

        // --- 심박수 (최근 1시간 평균) ---
        group.enter()
        queryAverage(type: .heartRate, unit: HKUnit(from: "count/min"),
                     start: Date().addingTimeInterval(-3600), end: now) { val in
            if let v = val { record["heart_rate"] = v }
            group.leave()
        }

        // --- 안정 심박수 ---
        group.enter()
        queryLatest(type: .restingHeartRate, unit: HKUnit(from: "count/min"),
                    start: startOfDay, end: now) { val in
            if let v = val { record["resting_heart_rate"] = v }
            group.leave()
        }

        // --- HRV (SDNN) ---
        group.enter()
        queryLatest(type: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli),
                    start: startOfDay, end: now) { val in
            if let v = val { record["hrv"] = v }
            group.leave()
        }

        // --- 혈중 산소 ---
        group.enter()
        queryLatest(type: .oxygenSaturation, unit: .percent(),
                    start: startOfDay, end: now) { val in
            if let v = val { record["blood_oxygen"] = v * 100 }  // 0~1 → percentage
            group.leave()
        }

        // --- 걸음수 (오늘 합계) ---
        group.enter()
        querySum(type: .stepCount, unit: .count(),
                 start: startOfDay, end: now) { val in
            if let v = val { record["steps"] = Int(v) }
            group.leave()
        }

        // --- 활성 칼로리 ---
        group.enter()
        querySum(type: .activeEnergyBurned, unit: .kilocalorie(),
                 start: startOfDay, end: now) { val in
            if let v = val { record["active_calories"] = v }
            group.leave()
        }

        // --- 기초 칼로리 ---
        group.enter()
        querySum(type: .basalEnergyBurned, unit: .kilocalorie(),
                 start: startOfDay, end: now) { val in
            if let v = val { record["basal_calories"] = v }
            group.leave()
        }

        // --- 운동 시간 ---
        group.enter()
        querySum(type: .appleExerciseTime, unit: .minute(),
                 start: startOfDay, end: now) { val in
            if let v = val { record["exercise_minutes"] = v }
            group.leave()
        }

        // --- 기립 시간 ---
        group.enter()
        querySum(type: .appleStandTime, unit: .minute(),
                 start: startOfDay, end: now) { val in
            if let v = val { record["stand_minutes"] = v }
            group.leave()
        }

        // --- 호흡수 ---
        group.enter()
        queryLatest(type: .respiratoryRate, unit: HKUnit(from: "count/min"),
                    start: Date().addingTimeInterval(-3600), end: now) { val in
            if let v = val { record["respiratory_rate"] = v }
            group.leave()
        }

        // --- 체온 ---
        group.enter()
        queryLatest(type: .bodyTemperature, unit: .degreeCelsius(),
                    start: Date().addingTimeInterval(-86400), end: now) { val in
            if let v = val { record["body_temp_c"] = v }
            group.leave()
        }

        // --- 혈당 ---
        group.enter()
        queryLatest(type: .bloodGlucose,
                    unit: HKUnit(from: "mg/dL"),
                    start: Date().addingTimeInterval(-86400), end: now) { val in
            if let v = val { record["blood_glucose"] = v }
            group.leave()
        }

        // --- 혈압 수축기 ---
        group.enter()
        queryLatest(type: .bloodPressureSystolic, unit: .millimeterOfMercury(),
                    start: Date().addingTimeInterval(-86400), end: now) { val in
            if let v = val { record["bp_systolic"] = v }
            group.leave()
        }

        // --- 혈압 이완기 ---
        group.enter()
        queryLatest(type: .bloodPressureDiastolic, unit: .millimeterOfMercury(),
                    start: Date().addingTimeInterval(-86400), end: now) { val in
            if let v = val { record["bp_diastolic"] = v }
            group.leave()
        }

        // --- 체중 ---
        group.enter()
        queryLatest(type: .bodyMass, unit: .gramUnit(with: .kilo),
                    start: Date().addingTimeInterval(-7 * 86400), end: now) { val in
            if let v = val { record["weight"] = v }
            group.leave()
        }

        // --- VO2max ---
        group.enter()
        queryLatest(type: .vo2Max,
                    unit: HKUnit(from: "ml/kg·min"),
                    start: Date().addingTimeInterval(-7 * 86400), end: now) { val in
            if let v = val { record["vo2max"] = v }
            group.leave()
        }

        // --- 보행 심박수 ---
        group.enter()
        queryLatest(type: .walkingHeartRateAverage, unit: HKUnit(from: "count/min"),
                    start: startOfDay, end: now) { val in
            if let v = val { record["walking_heart_rate"] = v }
            group.leave()
        }

        // --- 이동 거리 ---
        group.enter()
        querySum(type: .distanceWalkingRunning, unit: .meterUnit(with: .kilo),
                 start: startOfDay, end: now) { val in
            if let v = val { record["distance_km"] = v }
            group.leave()
        }

        // --- 층수 ---
        group.enter()
        querySum(type: .flightsClimbed, unit: .count(),
                 start: startOfDay, end: now) { val in
            if let v = val { record["flights_climbed"] = Int(v) }
            group.leave()
        }

        // --- 수면 ---
        group.enter()
        querySleep(start: Date().addingTimeInterval(-24 * 3600), end: now) { hours in
            if let h = hours { record["sleep_hours"] = h }
            group.leave()
        }

        // 모든 쿼리 완료 후 전송
        group.notify(queue: .global()) {
            self.sendToServer(record: record, token: token, serverURL: serverURL)
        }
    }

    // MARK: - 서버 전송

    private func sendToServer(record: [String: Any], token: String, serverURL: String) {
        // LongRun 백엔드로 직접 전송 (token을 email로 사용)
        guard let url = URL(string: "https://ravishing-grace-production.up.railway.app/api/watch-data") else {
            DispatchQueue.main.async {
                self.isUploading = false
                self.lastUploadResult = "잘못된 서버 URL"
            }
            return
        }

        var payload = record
        payload["email"] = token  // token 필드에 이메일 입력

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            DispatchQueue.main.async {
                self.isUploading = false
                self.lastUploadResult = "JSON 직렬화 오류"
            }
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isUploading = false
                if let error = error {
                    self.lastUploadResult = "전송 실패: \(error.localizedDescription)"
                    return
                }
                if let httpResp = response as? HTTPURLResponse {
                    if httpResp.statusCode == 200 {
                        self.lastUploadTime = Date()
                        let fieldCount = record.count - 1  // timestamp 제외
                        self.lastUploadResult = "✅ 전송 완료 (\(fieldCount)개 지표)"
                    } else if httpResp.statusCode == 401 {
                        self.lastUploadResult = "❌ 토큰 오류 (401)"
                    } else {
                        self.lastUploadResult = "❌ 서버 오류 (\(httpResp.statusCode))"
                    }
                }
            }
        }.resume()
    }

    // MARK: - Background Delivery 등록

    /// watchOS에서 새 HealthKit 데이터가 생기면 백그라운드에서 깨워서 자동 전송
    @available(watchOS 8.0, *)
    func enableBackgroundDelivery(token: String, serverURL: String) {
        let types: [HKQuantityTypeIdentifier] = [
            .heartRate, .restingHeartRate, .heartRateVariabilitySDNN,
            .oxygenSaturation, .stepCount, .activeEnergyBurned,
            .respiratoryRate
        ]

        for typeID in types {
            guard let quantityType = HKObjectType.quantityType(forIdentifier: typeID) else { continue }
            store.enableBackgroundDelivery(for: quantityType, frequency: .hourly) { success, _ in
                if success {
                    let query = HKObserverQuery(sampleType: quantityType, predicate: nil) { [weak self] _, _, error in
                        guard error == nil else { return }
                        self?.collectAndUpload(token: token, serverURL: serverURL)
                    }
                    self.store.execute(query)
                }
            }
        }
    }

    // MARK: - HealthKit 쿼리 헬퍼

    private func queryLatest(type typeID: HKQuantityTypeIdentifier,
                              unit: HKUnit,
                              start: Date, end: Date,
                              completion: @escaping (Double?) -> Void) {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: typeID) else {
            completion(nil); return
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: quantityType, predicate: predicate,
                                  limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil); return
            }
            completion(sample.quantity.doubleValue(for: unit))
        }
        store.execute(query)
    }

    private func queryAverage(type typeID: HKQuantityTypeIdentifier,
                               unit: HKUnit,
                               start: Date, end: Date,
                               completion: @escaping (Double?) -> Void) {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: typeID) else {
            completion(nil); return
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let query = HKStatisticsQuery(quantityType: quantityType,
                                      quantitySamplePredicate: predicate,
                                      options: .discreteAverage) { _, stats, _ in
            let val = stats?.averageQuantity()?.doubleValue(for: unit)
            completion(val)
        }
        store.execute(query)
    }

    private func querySum(type typeID: HKQuantityTypeIdentifier,
                           unit: HKUnit,
                           start: Date, end: Date,
                           completion: @escaping (Double?) -> Void) {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: typeID) else {
            completion(nil); return
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let query = HKStatisticsQuery(quantityType: quantityType,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, _ in
            let val = stats?.sumQuantity()?.doubleValue(for: unit)
            completion(val)
        }
        store.execute(query)
    }

    private func querySleep(start: Date, end: Date,
                             completion: @escaping (Double?) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil); return
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample] else {
                completion(nil); return
            }
            // asleepUnspecified(watchOS 9+) + asleepCore/Deep/REM(watchOS 9+) 또는 inBed 합산
            var asleepValues: Set<Int> = [HKCategoryValueSleepAnalysis.asleep.rawValue]
            if #available(watchOS 9.0, *) {
                asleepValues.insert(HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue)
                asleepValues.insert(HKCategoryValueSleepAnalysis.asleepCore.rawValue)
                asleepValues.insert(HKCategoryValueSleepAnalysis.asleepDeep.rawValue)
                asleepValues.insert(HKCategoryValueSleepAnalysis.asleepREM.rawValue)
            }
            let totalSeconds = samples
                .filter { asleepValues.contains($0.value) }
                .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let hours = totalSeconds / 3600.0
            completion(hours > 0 ? hours : nil)
        }
        store.execute(query)
    }
}
