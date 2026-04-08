import Foundation
import HealthKit

class iOSHealthManager {
    static let shared = iOSHealthManager()
    let healthStore = HKHealthStore()

    let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        // 심박/순환
        let quantityIDs: [HKQuantityTypeIdentifier] = [
            .heartRate, .restingHeartRate, .walkingHeartRateAverage,
            .heartRateVariabilitySDNN, .heartRateRecoveryOneMinute,
            .oxygenSaturation, .bloodPressureSystolic, .bloodPressureDiastolic,
            // 호흡
            .respiratoryRate, .peakExpiratoryFlowRate,
            // 활동
            .stepCount, .distanceWalkingRunning, .distanceCycling, .distanceSwimming,
            .activeEnergyBurned, .basalEnergyBurned,
            .flightsClimbed, .appleExerciseTime, .appleStandTime,
            .vo2Max, .walkingSpeed, .walkingStepLength,
            .walkingAsymmetryPercentage, .walkingDoubleSupportPercentage,
            .sixMinuteWalkTestDistance, .stairAscentSpeed, .stairDescentSpeed,
            // 신체
            .bodyMass, .bodyMassIndex, .bodyFatPercentage, .leanBodyMass,
            .waistCircumference, .height,
            // 체온/대사
            .bodyTemperature, .basalBodyTemperature, .bloodGlucose,
            // 영양
            .dietaryEnergyConsumed, .dietaryWater, .dietaryProtein,
            .dietaryCarbohydrates, .dietaryFatTotal, .dietaryFiber,
            .dietaryCaffeine, .dietarySodium,
            // 환경/청각
            .environmentalAudioExposure, .headphoneAudioExposure,
            .environmentalSoundReduction,
            // UV
            .uvExposure,
            // 수분
            .numberOfTimesFallen,
        ]
        for id in quantityIDs {
            if let t = HKObjectType.quantityType(forIdentifier: id) { types.insert(t) }
        }
        // 카테고리
        let categoryIDs: [HKCategoryTypeIdentifier] = [
            .sleepAnalysis, .mindfulSession, .appleStandHour,
            .highHeartRateEvent, .lowHeartRateEvent, .irregularHeartRhythmEvent,
        ]
        for id in categoryIDs {
            if let t = HKObjectType.categoryType(forIdentifier: id) { types.insert(t) }
        }
        return types
    }()

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else { completion(false); return }
        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, _ in
            completion(success)
        }
    }

    func collectAndSend(completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var record: [String: Any] = [
            "email": "seojun@longrun.app",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        let lock = NSLock()

        func set(_ key: String, _ value: Any?) {
            guard let v = value else { return }
            lock.lock(); record[key] = v; lock.unlock()
        }

        // 심박/순환
        group.enter(); fetchLatest(.heartRate, unit: .init(from: "count/min")) { set("heart_rate", $0); group.leave() }
        group.enter(); fetchLatest(.restingHeartRate, unit: .init(from: "count/min")) { set("resting_heart_rate", $0); group.leave() }
        group.enter(); fetchLatest(.walkingHeartRateAverage, unit: .init(from: "count/min")) { set("walking_heart_rate", $0); group.leave() }
        group.enter(); fetchLatest(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli)) { set("hrv", $0); group.leave() }
        group.enter(); fetchLatest(.heartRateRecoveryOneMinute, unit: .init(from: "count/min")) { set("heart_rate_recovery", $0); group.leave() }
        group.enter(); fetchLatest(.oxygenSaturation, unit: .percent()) { set("blood_oxygen", $0.map { $0 * 100 }); group.leave() }
        group.enter(); fetchLatest(.bloodPressureSystolic, unit: .millimeterOfMercury()) { set("bp_systolic", $0); group.leave() }
        group.enter(); fetchLatest(.bloodPressureDiastolic, unit: .millimeterOfMercury()) { set("bp_diastolic", $0); group.leave() }

        // 호흡
        group.enter(); fetchLatest(.respiratoryRate, unit: .init(from: "count/min")) { set("respiratory_rate", $0); group.leave() }

        // 활동 (오늘 합계)
        group.enter(); fetchTodaySum(.stepCount, unit: .count()) { set("steps", $0.map { Int($0) }); group.leave() }
        group.enter(); fetchTodaySum(.distanceWalkingRunning, unit: .meterUnit(with: .kilo)) { set("distance_km", $0); group.leave() }
        group.enter(); fetchTodaySum(.distanceCycling, unit: .meterUnit(with: .kilo)) { set("cycling_km", $0); group.leave() }
        group.enter(); fetchTodaySum(.distanceSwimming, unit: .meter()) { set("swimming_m", $0); group.leave() }
        group.enter(); fetchTodaySum(.activeEnergyBurned, unit: .kilocalorie()) { set("active_calories", $0); group.leave() }
        group.enter(); fetchTodaySum(.basalEnergyBurned, unit: .kilocalorie()) { set("basal_calories", $0); group.leave() }
        group.enter(); fetchTodaySum(.flightsClimbed, unit: .count()) { set("flights_climbed", $0.map { Int($0) }); group.leave() }
        group.enter(); fetchTodaySum(.appleExerciseTime, unit: .minute()) { set("exercise_minutes", $0); group.leave() }
        group.enter(); fetchTodaySum(.appleStandTime, unit: .minute()) { set("stand_minutes", $0); group.leave() }

        // 체력
        group.enter(); fetchLatest(.vo2Max, unit: HKUnit(from: "ml/kg*min")) { set("vo2max", $0); group.leave() }
        group.enter(); fetchLatest(.walkingSpeed, unit: .init(from: "m/s")) { set("walking_speed", $0); group.leave() }
        group.enter(); fetchLatest(.walkingStepLength, unit: .meterUnit(with: .centi)) { set("step_length_cm", $0); group.leave() }
        group.enter(); fetchLatest(.walkingAsymmetryPercentage, unit: .percent()) { set("walking_asymmetry", $0.map { $0 * 100 }); group.leave() }
        group.enter(); fetchLatest(.walkingDoubleSupportPercentage, unit: .percent()) { set("double_support", $0.map { $0 * 100 }); group.leave() }
        group.enter(); fetchLatest(.sixMinuteWalkTestDistance, unit: .meter()) { set("six_min_walk", $0); group.leave() }

        // 신체
        group.enter(); fetchLatest(.bodyMass, unit: .gramUnit(with: .kilo)) { set("weight", $0); group.leave() }
        group.enter(); fetchLatest(.bodyMassIndex, unit: .count()) { set("bmi", $0); group.leave() }
        group.enter(); fetchLatest(.bodyFatPercentage, unit: .percent()) { set("body_fat", $0.map { $0 * 100 }); group.leave() }
        group.enter(); fetchLatest(.height, unit: .meterUnit(with: .centi)) { set("height_cm", $0); group.leave() }

        // 체온/대사
        group.enter(); fetchLatest(.bodyTemperature, unit: .degreeCelsius()) { set("body_temp_c", $0); group.leave() }
        group.enter(); fetchLatest(.bloodGlucose, unit: HKUnit(from: "mg/dL")) { set("blood_glucose", $0); group.leave() }

        // 영양 (오늘 합계)
        group.enter(); fetchTodaySum(.dietaryEnergyConsumed, unit: .kilocalorie()) { set("dietary_calories", $0); group.leave() }
        group.enter(); fetchTodaySum(.dietaryWater, unit: .literUnit(with: .milli)) { set("water_ml", $0); group.leave() }
        group.enter(); fetchTodaySum(.dietaryProtein, unit: .gram()) { set("protein_g", $0); group.leave() }
        group.enter(); fetchTodaySum(.dietaryCaffeine, unit: .gramUnit(with: .milli)) { set("caffeine_mg", $0); group.leave() }

        // 환경
        group.enter(); fetchLatest(.environmentalAudioExposure, unit: HKUnit(from: "dBASPL")) { set("env_audio_db", $0); group.leave() }
        group.enter(); fetchLatest(.headphoneAudioExposure, unit: HKUnit(from: "dBASPL")) { set("headphone_audio_db", $0); group.leave() }

        // 수면
        group.enter(); fetchTodaySleep { set("sleep_hours", $0); group.leave() }

        // 마음챙김 (오늘 합계 분)
        group.enter(); fetchTodayMindful { set("mindful_minutes", $0); group.leave() }

        // 낙상
        group.enter(); fetchTodaySum(.numberOfTimesFallen, unit: .count()) { set("falls", $0.map { Int($0) }); group.leave() }

        group.notify(queue: .global()) {
            guard let url = URL(string: "https://ravishing-grace-production.up.railway.app/api/watch-data"),
                  let jsonData = try? JSONSerialization.data(withJSONObject: record) else {
                completion(false); return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 15
            request.httpBody = jsonData

            URLSession.shared.dataTask(with: request) { _, response, error in
                completion(error == nil && (response as? HTTPURLResponse)?.statusCode == 200)
            }.resume()
        }
    }

    // MARK: - 날짜 범위 조회 (쿼리 응답용)
    func collectRange(start: Date, end: Date, completion: @escaping ([[String: Any]]) -> Void) {
        let quantityTypes: [(HKQuantityTypeIdentifier, HKUnit, String)] = [
            (.heartRate, HKUnit(from: "count/min"), "heart_rate"),
            (.restingHeartRate, HKUnit(from: "count/min"), "resting_heart_rate"),
            (.heartRateVariabilitySDNN, .secondUnit(with: .milli), "hrv"),
            (.oxygenSaturation, .percent(), "blood_oxygen"),
            (.stepCount, .count(), "steps"),
            (.activeEnergyBurned, .kilocalorie(), "active_calories"),
            (.respiratoryRate, HKUnit(from: "count/min"), "respiratory_rate"),
            (.bodyTemperature, .degreeCelsius(), "body_temp_c"),
            (.bloodGlucose, HKUnit(from: "mg/dL"), "blood_glucose"),
            (.bodyMass, .gramUnit(with: .kilo), "weight"),
        ]

        var allRecords: [[String: Any]] = []
        let lock = NSLock()
        let group = DispatchGroup()
        let formatter = ISO8601DateFormatter()

        for (typeId, unit, key) in quantityTypes {
            guard let type = HKQuantityType.quantityType(forIdentifier: typeId) else { continue }
            group.enter()
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1000, sortDescriptors: [sort]) { _, samples, _ in
                if let samples = samples as? [HKQuantitySample] {
                    for sample in samples {
                        var value = sample.quantity.doubleValue(for: unit)
                        if key == "blood_oxygen" { value *= 100 }
                        let record: [String: Any] = [
                            "type": key,
                            "value": value,
                            "timestamp": formatter.string(from: sample.endDate)
                        ]
                        lock.lock(); allRecords.append(record); lock.unlock()
                    }
                }
                group.leave()
            }
            healthStore.execute(query)
        }

        // 수면
        group.enter()
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 100, sortDescriptors: nil) { _, samples, _ in
                if let samples = samples as? [HKCategorySample] {
                    let asleep = samples.filter { $0.value != HKCategoryValueSleepAnalysis.inBed.rawValue }
                    let total = asleep.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                    if total > 0 {
                        let record: [String: Any] = [
                            "type": "sleep_hours",
                            "value": total / 3600.0,
                            "timestamp": formatter.string(from: end)
                        ]
                        lock.lock(); allRecords.append(record); lock.unlock()
                    }
                }
                group.leave()
            }
            healthStore.execute(query)
        } else {
            group.leave()
        }

        group.notify(queue: .global()) {
            completion(allRecords)
        }
    }

    // MARK: - Queries

    private func fetchLatest(_ id: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { completion(nil); return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            completion((samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit))
        }
        healthStore.execute(query)
    }

    private func fetchTodaySum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { completion(nil); return }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            completion(result?.sumQuantity()?.doubleValue(for: unit))
        }
        healthStore.execute(query)
    }

    private func fetchTodaySleep(completion: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { completion(nil); return }
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 100, sortDescriptors: [sort]) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample] else { completion(nil); return }
            let asleep = samples.filter { $0.value != HKCategoryValueSleepAnalysis.inBed.rawValue }
            let total = asleep.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            completion(total > 0 ? total / 3600.0 : nil)
        }
        healthStore.execute(query)
    }

    private func fetchTodayMindful(completion: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { completion(nil); return }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 100, sortDescriptors: nil) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample] else { completion(nil); return }
            let total = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            completion(total > 0 ? total / 60.0 : nil)
        }
        healthStore.execute(query)
    }
}
