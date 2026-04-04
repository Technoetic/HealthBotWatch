import Foundation
import HealthKit

class HealthManager: ObservableObject {
    let healthStore = HKHealthStore()

    // 읽기 권한 요청할 데이터 타입
    let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
    ]

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, _ in
            completion(success)
        }
    }

    // MARK: - 최근값 조회 (공통)
    private func fetchLatestQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        completion: @escaping (Double?) -> Void
    ) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion(nil); return
        }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
            completion(value)
        }
        healthStore.execute(query)
    }

    // MARK: - 오늘 합계 (걸음수, 칼로리)
    private func fetchTodaySum(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        completion: @escaping (Double?) -> Void
    ) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion(nil); return
        }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            completion(result?.sumQuantity()?.doubleValue(for: unit))
        }
        healthStore.execute(query)
    }

    // MARK: - 오늘 수면 시간
    private func fetchTodaySleep(completion: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil); return
        }
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .hour, value: -24, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample] else { completion(nil); return }
            let asleepSamples = samples.filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }
            let totalSeconds = asleepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            completion(totalSeconds > 0 ? totalSeconds / 3600.0 : nil)
        }
        healthStore.execute(query)
    }

    // MARK: - 전체 데이터 수집
    func collectAllData(completion: @escaping (HealthData) -> Void) {
        let group = DispatchGroup()
        var heartRate: Double?
        var hrv: Double?
        var spo2: Double?
        var steps: Double?
        var calories: Double?
        var restingHR: Double?
        var sleep: Double?

        group.enter()
        fetchLatestQuantity(identifier: .heartRate, unit: HKUnit(from: "count/min")) { heartRate = $0; group.leave() }

        group.enter()
        fetchLatestQuantity(identifier: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli)) { hrv = $0; group.leave() }

        group.enter()
        fetchLatestQuantity(identifier: .oxygenSaturation, unit: .percent()) { spo2 = ($0 ?? 0) * 100; group.leave() }

        group.enter()
        fetchTodaySum(identifier: .stepCount, unit: .count()) { steps = $0; group.leave() }

        group.enter()
        fetchTodaySum(identifier: .activeEnergyBurned, unit: .kilocalorie()) { calories = $0; group.leave() }

        group.enter()
        fetchLatestQuantity(identifier: .restingHeartRate, unit: HKUnit(from: "count/min")) { restingHR = $0; group.leave() }

        group.enter()
        fetchTodaySleep { sleep = $0; group.leave() }

        group.notify(queue: .main) {
            completion(HealthData(
                token: "user_479945484",
                heartRate: heartRate,
                hrv: hrv,
                bloodOxygen: spo2,
                steps: steps.map { Int($0) },
                activeCalories: calories,
                restingHeartRate: restingHR,
                sleepHours: sleep,
                timestamp: ISO8601DateFormatter().string(from: Date())
            ))
        }
    }
}
