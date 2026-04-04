import Foundation

struct HealthData: Codable {
    let token: String
    let heartRate: Double?
    let hrv: Double?
    let bloodOxygen: Double?
    let steps: Int?
    let activeCalories: Double?
    let restingHeartRate: Double?
    let sleepHours: Double?
    let timestamp: String?

    enum CodingKeys: String, CodingKey {
        case token
        case heartRate = "heart_rate"
        case hrv
        case bloodOxygen = "blood_oxygen"
        case steps
        case activeCalories = "active_calories"
        case restingHeartRate = "resting_heart_rate"
        case sleepHours = "sleep_hours"
        case timestamp
    }
}
