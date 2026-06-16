import SwiftUI
import Combine

#if os(iOS)
import CoreMotion
import HealthKit
import MapKit
import CoreLocation
#endif

struct FitnessProfile: Codable, Equatable {
    var stepGoal: Int
    var calorieGoal: Int
    var activeMinutesGoal: Int
    var bodyWeightKilograms: Double

    private static let storageKey = "fitmate.fitness.profile.v1"

    static let `default` = FitnessProfile(
        stepGoal: 10_000,
        calorieGoal: 500,
        activeMinutesGoal: 30,
        bodyWeightKilograms: 70
    )

    static func load() -> FitnessProfile {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let profile = try? JSONDecoder().decode(FitnessProfile.self, from: data) else {
            return .default
        }
        return profile.sanitized()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(sanitized()) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func sanitized() -> FitnessProfile {
        FitnessProfile(
            stepGoal: min(max(stepGoal, 1_000), 50_000),
            calorieGoal: min(max(calorieGoal, 50), 2_500),
            activeMinutesGoal: min(max(activeMinutesGoal, 5), 240),
            bodyWeightKilograms: min(max(bodyWeightKilograms, 35), 200)
        )
    }
}

enum HealthAccessStatus: Equatable {
    case checking
    case available
    case denied
    case unavailable

    var icon: String {
        switch self {
        case .checking:
            return "waveform.path.ecg"
        case .available:
            return "checkmark.seal.fill"
        case .denied:
            return "exclamationmark.lock.fill"
        case .unavailable:
            return "iphone.slash"
        }
    }

    var tint: Color {
        switch self {
        case .checking:
            return .blue
        case .available:
            return .green
        case .denied:
            return .orange
        case .unavailable:
            return .secondary
        }
    }

    var message: String {
        switch self {
        case .checking:
            return "FitMate is checking Health access."
        case .available:
            return "Health sync is active for steps, distance, calories, and workouts."
        case .denied:
            return "Health access is off, so full-day workouts cannot be imported."
        case .unavailable:
            return "HealthKit is not available on this device."
        }
    }

    var shortTitle: String {
        switch self {
        case .checking:
            return "Syncing"
        case .available:
            return "Live"
        case .denied:
            return "Locked"
        case .unavailable:
            return "Offline"
        }
    }
}

enum MotionAccessStatus: Equatable {
    case checking
    case available
    case denied
    case unavailable

    var icon: String {
        switch self {
        case .checking:
            return "sensor.tag.radiowaves.forward"
        case .available:
            return "figure.walk.motion"
        case .denied:
            return "exclamationmark.lock.fill"
        case .unavailable:
            return "iphone.slash"
        }
    }

    var tint: Color {
        switch self {
        case .checking:
            return .blue
        case .available:
            return .green
        case .denied:
            return .orange
        case .unavailable:
            return .secondary
        }
    }

    var message: String {
        switch self {
        case .checking:
            return "FitMate is checking Motion & Fitness access."
        case .available:
            return "Live step fallback can update while FitMate is open."
        case .denied:
            return "Motion access is off, so live step fallback is unavailable."
        case .unavailable:
            return "This device cannot provide pedometer data."
        }
    }

    var shortTitle: String {
        switch self {
        case .checking:
            return "Checking"
        case .available:
            return "Live"
        case .denied:
            return "Locked"
        case .unavailable:
            return "Offline"
        }
    }
}

enum LocationAccessStatus: Equatable {
    case checking
    case available
    case denied
    case unavailable

    var icon: String {
        switch self {
        case .checking:
            return "location.magnifyingglass"
        case .available:
            return "location.fill"
        case .denied:
            return "location.slash.fill"
        case .unavailable:
            return "map.slash"
        }
    }

    var tint: Color {
        switch self {
        case .checking:
            return .blue
        case .available:
            return .green
        case .denied:
            return .orange
        case .unavailable:
            return .secondary
        }
    }

    var message: String {
        switch self {
        case .checking:
            return "Location permission has not been requested yet."
        case .available:
            return "Route maps can record and save your path."
        case .denied:
            return "Location access is off, so path maps cannot be recorded."
        case .unavailable:
            return "Location services are restricted on this device."
        }
    }

    var shortTitle: String {
        switch self {
        case .checking:
            return "Ready"
        case .available:
            return "Live"
        case .denied:
            return "Locked"
        case .unavailable:
            return "Offline"
        }
    }
}

enum ActivityKind: String, CaseIterable, Identifiable, Codable {
    case walking
    case running
    case cycling
    case jumpingJacks
    case workout

    var id: String { rawValue }

    static let routeKinds: [ActivityKind] = [.walking, .running, .cycling]

    var title: String {
        switch self {
        case .walking:
            return "Walking"
        case .running:
            return "Running"
        case .cycling:
            return "Cycling"
        case .jumpingJacks:
            return "Jacks / HIIT"
        case .workout:
            return "Workout"
        }
    }

    var dashboardTitle: String {
        switch self {
        case .walking:
            return "Walking"
        case .running:
            return "Running"
        case .cycling:
            return "Cycling"
        case .jumpingJacks:
            return "Jumping Jacks"
        case .workout:
            return "Workout"
        }
    }

    var routeTitle: String {
        switch self {
        case .walking:
            return "Walk"
        case .running:
            return "Run"
        case .cycling:
            return "Ride"
        case .jumpingJacks:
            return "Jacks"
        case .workout:
            return "Workout"
        }
    }

    var routeCalorieMultiplier: Double {
        switch self {
        case .walking:
            return 0.57
        case .running:
            return 1.03
        case .cycling:
            return 0.35
        case .jumpingJacks, .workout:
            return 0.75
        }
    }

    var icon: String {
        switch self {
        case .walking:
            return "figure.walk"
        case .running:
            return "figure.run"
        case .cycling:
            return "bicycle"
        case .jumpingJacks:
            return "figure.jumprope"
        case .workout:
            return "figure.strengthtraining.traditional"
        }
    }

    var tint: Color {
        switch self {
        case .walking:
            return .green
        case .running:
            return .orange
        case .cycling:
            return .blue
        case .jumpingJacks:
            return .purple
        case .workout:
            return .pink
        }
    }
}

struct ActivitySummary {
    let kind: ActivityKind
    let calories: Double
    let durationText: String
    let distanceText: String?
    let sessionCount: Int
    let steps: Int?

    var caloriesText: String {
        "\(Int(calories.rounded())) cal"
    }

    var sessionCountText: String {
        if sessionCount == 1 {
            return "1 session"
        }
        if sessionCount > 1 {
            return "\(sessionCount) sessions"
        }
        return kind == .walking ? "Auto" : "0 sessions"
    }

    var detailText: String {
        switch kind {
        case .walking:
            let stepsText = steps.map { "\($0.formatted()) steps" } ?? "Health steps"
            let distanceText = distanceText ?? "--"
            return "\(stepsText) • \(distanceText)"
        case .running:
            return [durationText, distanceText].compactMap { $0 }.joined(separator: " • ")
        case .cycling:
            return [durationText, distanceText].compactMap { $0 }.joined(separator: " • ")
        case .jumpingJacks:
            return sessionCount == 0 ? "Imported from HIIT workouts" : "\(durationText) tracked"
        case .workout:
            return "\(durationText) tracked"
        }
    }
}

struct ActivityRangeSummary: Identifiable {
    let kind: ActivityKind
    let calories: Double
    let activeDays: Int
    let progress: Double

    var id: ActivityKind { kind }

    var caloriesText: String {
        "\(Int(calories.rounded())) cal"
    }

    var detailText: String {
        if activeDays == 1 {
            return "1 active day"
        }
        return "\(activeDays) active days"
    }
}

struct GoalCompletionSummary: Identifiable {
    let date: Date
    let score: Double
    let isTargetHit: Bool

    var id: Date { date }

    var shortDayText: String {
        if Calendar.current.isDateInToday(date) {
            return "T"
        }
        return date.formatted(.dateTime.weekday(.narrow))
    }

    var scoreText: String {
        "\(Int((score * 100).rounded()))%"
    }
}

enum HistoryRange: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week:
            return "7D"
        case .month:
            return "30D"
        }
    }

    var dayCount: Int {
        switch self {
        case .week:
            return 7
        case .month:
            return 30
        }
    }
}

struct DailySummary: Identifiable {
    let id: Date
    let date: Date
    let steps: Int
    let distanceInMeters: Double
    let calories: Double
    let activeDuration: TimeInterval
    let activityCalories: [ActivityKind: Double]

    init(
        date: Date,
        steps: Int = 0,
        distanceInMeters: Double = 0,
        calories: Double = 0,
        activeDuration: TimeInterval = 0,
        activityCalories: [ActivityKind: Double] = [:]
    ) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        self.id = startOfDay
        self.date = startOfDay
        self.steps = steps
        self.distanceInMeters = distanceInMeters
        self.calories = calories
        self.activeDuration = activeDuration
        self.activityCalories = activityCalories
    }

    var dayText: String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        return date.formatted(.dateTime.weekday(.abbreviated).day())
    }

    var shortDayText: String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }

    var fullDateText: String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }

    var caloriesText: String {
        "\(Int(calories.rounded())) cal"
    }

    var distanceText: String {
        let kilometers = distanceInMeters / 1_000
        return kilometers.formatted(.number.precision(.fractionLength(1))) + " km"
    }

    var activeTimeText: String {
        let minutes = Int(activeDuration / 60)
        return "\(minutes)m"
    }

    var activeMinutesText: String {
        "\(activeMinutes)m"
    }

    var activeMinutes: Int {
        Int(activeDuration / 60)
    }

    var activityCaloriesTotal: Double {
        activityCalories.values.reduce(0, +)
    }

    func progress(maxCalories: Double) -> Double {
        guard maxCalories > 0 else { return 0 }
        return min(calories / maxCalories, 1)
    }

    func stepGoalProgress(profile: FitnessProfile) -> Double {
        FitnessMath.progress(current: Double(steps), target: Double(profile.stepGoal))
    }

    func calorieGoalProgress(profile: FitnessProfile) -> Double {
        FitnessMath.progress(current: calories, target: Double(profile.calorieGoal))
    }

    func activeGoalProgress(profile: FitnessProfile) -> Double {
        FitnessMath.progress(current: Double(activeMinutes), target: Double(profile.activeMinutesGoal))
    }

    func goalScore(profile: FitnessProfile) -> Double {
        FitnessMath.goalScore(
            stepProgress: stepGoalProgress(profile: profile),
            calorieProgress: calorieGoalProgress(profile: profile),
            activeProgress: activeGoalProgress(profile: profile)
        )
    }

    func goalScoreText(profile: FitnessProfile) -> String {
        "\(Int((goalScore(profile: profile) * 100).rounded()))% of daily goals"
    }

    func calories(for kind: ActivityKind) -> Double {
        activityCalories[kind] ?? 0
    }

    static let preview: [DailySummary] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailySummary(
                date: date,
                steps: 5_400 + offset * 620,
                distanceInMeters: 3_100 + Double(offset * 430),
                calories: 220 + Double(offset * 28),
                activeDuration: 1_800 + Double(offset * 180),
                activityCalories: [
                    .walking: 130 + Double(offset * 12),
                    .running: offset % 2 == 0 ? 70 + Double(offset * 6) : 0,
                    .cycling: offset % 3 == 0 ? 90 : 0,
                    .jumpingJacks: offset % 2 == 1 ? 35 : 0
                ]
            )
        }
        .reversed()
    }()
}

struct RouteSession: Identifiable, Codable {
    let id: UUID
    let kind: ActivityKind
    let date: Date
    let duration: TimeInterval
    let distanceInMeters: Double
    let calories: Double
    let points: [RoutePoint]

    init(
        id: UUID = UUID(),
        kind: ActivityKind = .walking,
        date: Date,
        duration: TimeInterval,
        distanceInMeters: Double,
        calories: Double,
        points: [RoutePoint]
    ) {
        self.id = id
        self.kind = kind
        self.date = date
        self.duration = duration
        self.distanceInMeters = distanceInMeters
        self.calories = calories
        self.points = points
    }

    var distanceText: String {
        let kilometers = distanceInMeters / 1_000
        return kilometers.formatted(.number.precision(.fractionLength(2))) + " km"
    }

    var durationText: String {
        let seconds = max(Int(duration.rounded()), 0)
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }

        if minutes > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        }

        return "\(remainingSeconds)s"
    }

    var caloriesText: String {
        "\(Int(calories.rounded())) cal"
    }

    var pointCountText: String {
        "\(points.count) pts"
    }

#if os(iOS)
    var coordinates: [CLLocationCoordinate2D] {
        points.map(\.coordinate)
    }

    var cameraPosition: MapCameraPosition {
        guard let first = coordinates.first else {
            return .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777), latitudinalMeters: 2_000, longitudinalMeters: 2_000))
        }

        let bounds = coordinates.reduce(
            (minLatitude: first.latitude, maxLatitude: first.latitude, minLongitude: first.longitude, maxLongitude: first.longitude)
        ) { partialResult, coordinate in
            (
                min(partialResult.minLatitude, coordinate.latitude),
                max(partialResult.maxLatitude, coordinate.latitude),
                min(partialResult.minLongitude, coordinate.longitude),
                max(partialResult.maxLongitude, coordinate.longitude)
            )
        }

        let center = CLLocationCoordinate2D(
            latitude: (bounds.minLatitude + bounds.maxLatitude) / 2,
            longitude: (bounds.minLongitude + bounds.maxLongitude) / 2
        )
        let latitudeMeters = max((bounds.maxLatitude - bounds.minLatitude) * 111_000, 800)
        let longitudeMeters = max((bounds.maxLongitude - bounds.minLongitude) * 111_000, 800)

        return .region(MKCoordinateRegion(center: center, latitudinalMeters: latitudeMeters * 1.4, longitudinalMeters: longitudeMeters * 1.4))
    }
#endif

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case date
        case duration
        case distanceInMeters
        case calories
        case points
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.kind = try container.decodeIfPresent(ActivityKind.self, forKey: .kind) ?? .walking
        self.date = try container.decode(Date.self, forKey: .date)
        self.duration = try container.decode(TimeInterval.self, forKey: .duration)
        self.distanceInMeters = try container.decode(Double.self, forKey: .distanceInMeters)
        self.calories = try container.decode(Double.self, forKey: .calories)
        self.points = try container.decode([RoutePoint].self, forKey: .points)
    }

    static let preview: [RouteSession] = [
        RouteSession(
            kind: .walking,
            date: Date().addingTimeInterval(-3_600),
            duration: 1_860,
            distanceInMeters: 2_840,
            calories: 149,
            points: [
                RoutePoint(latitude: 19.0760, longitude: 72.8777),
                RoutePoint(latitude: 19.0782, longitude: 72.8791)
            ]
        )
    ]
}

struct RoutePoint: Codable {
    let latitude: Double
    let longitude: Double

#if os(iOS)
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
#endif

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}


#if os(iOS)
extension ActivityKind {
    init(workoutActivityType: HKWorkoutActivityType) {
        switch workoutActivityType {
        case .walking:
            self = .walking
        case .running:
            self = .running
        case .cycling:
            self = .cycling
        case .highIntensityIntervalTraining, .functionalStrengthTraining:
            self = .jumpingJacks
        default:
            self = .workout
        }
    }
}
#endif
