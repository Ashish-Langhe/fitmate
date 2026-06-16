import SwiftUI
import Combine

#if os(iOS)
import CoreMotion
import HealthKit
import MapKit
import CoreLocation
#endif

struct DailyActivity: Identifiable, Codable {
    let id: UUID
    let kind: ActivityKind
    let date: Date
    let duration: TimeInterval
    let distanceInMeters: Double?
    let calories: Double

    init(id: UUID = UUID(), kind: ActivityKind, date: Date, duration: TimeInterval, distanceInMeters: Double?, calories: Double) {
        self.id = id
        self.kind = kind
        self.date = date
        self.duration = duration
        self.distanceInMeters = distanceInMeters
        self.calories = calories
    }

#if os(iOS)
    init(workout: HKWorkout) {
        self.id = UUID()
        self.kind = ActivityKind(workoutActivityType: workout.workoutActivityType)
        self.date = workout.startDate
        self.duration = workout.duration
        self.distanceInMeters = workout.totalDistance?.doubleValue(for: .meter())
        self.calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
    }
#endif

    var detailText: String {
        let minutes = max(Int(duration / 60), 0)
        if let distanceInMeters, distanceInMeters > 0 {
            let kilometers = (distanceInMeters / 1_000).formatted(.number.precision(.fractionLength(1)))
            return "\(minutes)m • \(kilometers) km"
        }
        return "\(minutes)m"
    }

    var timeText: String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static let preview: [DailyActivity] = [
        DailyActivity(kind: .walking, date: Date(), duration: 2_400, distanceInMeters: 3_100, calories: 128),
        DailyActivity(kind: .cycling, date: Date(), duration: 1_800, distanceInMeters: 6_200, calories: 210)
    ]
}

