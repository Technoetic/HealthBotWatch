import Foundation
import HealthKit

class iOSHealthManager {
    static let shared = iOSHealthManager()
    let healthStore = HKHealthStore()

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
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false); return
        }
        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, _ in
            completion(success)
        }
    }

    func collectAndSend(completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var heartRate: Double?
        var hrv: Double?
        var spo2: Double?
        var steps: Double?
        var calories: Double?
        var restingHR: Double?
        var sleep: Double?

        group.enter()
        fetchLatest(.heartRate, unit: HKUnit(from: "count/min")) { heartRate = $0; group.leave() }
        group.enter()
        fetchLatest(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli)) { hrv = $0; group.leave() }
        group.enter()
        fetchLatest(.oxygenSaturation, unit: .percent()) { v in spo2 = v.map { $0 * 100 }; group.leave() }
        group.enter()
        fetchTodaySum(.stepCount, unit: .count()) { steps = $0; group.leave() }
        group.enter()
        fetchTodaySum(.activeEnergyBurned, unit: .kilocalorie()) { calories = $0; group.leave() }
        group.enter()
        fetchLatest(.restingHeartRate, unit: HKUnit(from: "count/min")) { restingHR = $0; group.leave() }
        group.enter()
        fetchTodaySleep { sleep = $0; group.leave() }

        group.notify(queue: .global()) {
            let body: [String: Any?] = [
                "token": "user_479945484",
                "heart_rate": heartRate,
                "hrv": hrv,
                "blood_oxygen": spo2,
                "steps": steps.map { Int($0) },
                "active_calories": calories,
                "resting_heart_rate": restingHR,
                "sleep_hours": sleep,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
            let filtered = body.compactMapValues { $0 }

            guard let url = URL(string: "https://health-care-bot-production.up.railway.app/health"),
                  let jsonData = try? JSONSerialization.data(withJSONObject: filtered) else {
                completion(false); return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 15
            request.httpBody = jsonData

            URLSession.shared.dataTask(with: request) { _, response, error in
                let success = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
                completion(success)
            }.resume()
        }
    }

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
            let totalSeconds = asleep.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            completion(totalSeconds > 0 ? totalSeconds / 3600.0 : nil)
        }
        healthStore.execute(query)
    }
}
