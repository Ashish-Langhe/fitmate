import SwiftUI
import Combine

#if os(iOS)
import CoreMotion
import HealthKit
import MapKit
import CoreLocation
#endif

private struct RouteSessionStore {
    private let key = "fitmate.route.sessions.v1"

    func load() -> [RouteSession] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        if let routes = try? JSONDecoder().decode([RouteSession].self, from: data) {
            return routes
        }
        return (try? JSONDecoder().decode([SafeRouteSession].self, from: data))?.compactMap(\.value) ?? []
    }

    func save(_ routes: [RouteSession]) {
        guard let data = try? JSONEncoder().encode(routes) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private struct SafeRouteSession: Decodable {
    let value: RouteSession?

    init(from decoder: Decoder) throws {
        value = try? RouteSession(from: decoder)
    }
}

#if os(iOS)
@MainActor
final class RouteTracker: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var distanceInMeters: Double = 0
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var currentSpeedKilometersPerHour: Double = 0
    @Published private(set) var maxSpeedKilometersPerHour: Double = 0
    @Published private(set) var breakCount = 0
    @Published private(set) var breakDuration: TimeInterval = 0
    @Published private(set) var rideSamples: [RideMetricSample] = []
    @Published private(set) var isTracking = false
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var savedRoutes: [RouteSession] = []
    @Published private(set) var selectedKind: ActivityKind = .walking

    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var startedAt: Date?
    private var timer: Timer?
    private var breakStartedAt: Date?
    private var accumulatedBreakDuration: TimeInterval = 0
    private var lastSampleAt: Date?
    private var shouldStartAfterAuthorization = false
    private let routeStore = RouteSessionStore()
    private var bodyWeightKilograms = FitnessProfile.default.bodyWeightKilograms

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 8
        authorizationStatus = locationManager.authorizationStatus
        savedRoutes = routeStore.load()
    }

    var cameraPosition: MapCameraPosition {
        let center = routeCoordinates.last ?? CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777)
        let region = MKCoordinateRegion(center: center, latitudinalMeters: routeCoordinates.isEmpty ? 2_000 : 800, longitudinalMeters: routeCoordinates.isEmpty ? 2_000 : 800)
        return .region(region)
    }

    var distanceText: String {
        let kilometers = distanceInMeters / 1_000
        return kilometers.formatted(.number.precision(.fractionLength(2))) + " km"
    }

    var durationText: String {
        let seconds = max(Int(elapsedTime), 0)
        return Self.formatDuration(seconds)
    }

    var caloriesText: String {
        "\(Int(estimatedCalories.rounded())) cal"
    }

    var startTimeText: String {
        guard let startedAt else { return "--" }
        return startedAt.formatted(date: .omitted, time: .shortened)
    }

    var currentSpeedText: String {
        currentSpeedKilometersPerHour.formatted(.number.precision(.fractionLength(1))) + " km/h"
    }

    var averageSpeedText: String {
        averageSpeedKilometersPerHour.formatted(.number.precision(.fractionLength(1))) + " km/h"
    }

    var maxSpeedText: String {
        maxSpeedKilometersPerHour.formatted(.number.precision(.fractionLength(1))) + " km/h"
    }

    var breakCountText: String {
        breakCount == 1 ? "1 break" : "\(breakCount) breaks"
    }

    var breakDurationText: String {
        let minutes = Int((breakDuration / 60).rounded())
        return minutes == 1 ? "1m" : "\(minutes)m"
    }

    var cyclingStepCountText: String {
        FitnessMath.estimatedCyclingSteps(distanceMeters: distanceInMeters).formatted()
    }

    var locationAccessStatus: LocationAccessStatus {
        guard CLLocationManager.locationServicesEnabled() else {
            return .unavailable
        }

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return .available
        case .denied:
            return .denied
        case .restricted:
            return .unavailable
        case .notDetermined:
            return .checking
        @unknown default:
            return .checking
        }
    }

    func toggleTracking() {
        isTracking ? stopTracking() : startTracking()
    }

    func selectKind(_ kind: ActivityKind) {
        guard ActivityKind.routeKinds.contains(kind), !isTracking else { return }
        selectedKind = kind
    }

    func updateBodyWeight(_ kilograms: Double) {
        bodyWeightKilograms = min(max(kilograms, 35), 200)
    }

    func startTracking() {
        if authorizationStatus == .notDetermined {
            shouldStartAfterAuthorization = true
            locationManager.requestWhenInUseAuthorization()
            return
        }

        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            shouldStartAfterAuthorization = false
            return
        }

        routeCoordinates.removeAll()
        distanceInMeters = 0
        elapsedTime = 0
        currentSpeedKilometersPerHour = 0
        maxSpeedKilometersPerHour = 0
        breakCount = 0
        breakDuration = 0
        rideSamples = []
        accumulatedBreakDuration = 0
        breakStartedAt = nil
        lastSampleAt = nil
        lastLocation = nil
        startedAt = Date()
        recordRideSampleIfNeeded(at: startedAt ?? Date(), force: true)
        isTracking = true
        locationManager.startUpdatingLocation()
        scheduleTimer()
    }

    func stopTracking() {
        let endedAt = Date()
        if let startedAt {
            elapsedTime = endedAt.timeIntervalSince(startedAt)
        }
        finalizeBreakIfNeeded(at: endedAt)
        saveCurrentRouteIfNeeded()
        isTracking = false
        locationManager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if shouldStartAfterAuthorization,
           authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            shouldStartAfterAuthorization = false
            startTracking()
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            shouldStartAfterAuthorization = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking else { return }

        for location in locations where location.horizontalAccuracy >= 0 {
            if let lastLocation {
                distanceInMeters += location.distance(from: lastLocation)
            }
            updateSpeed(with: location)
            lastLocation = location
            routeCoordinates.append(location.coordinate)
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let startedAt = self.startedAt else { return }
                let now = Date()
                self.elapsedTime = now.timeIntervalSince(startedAt)
                self.refreshBreakDuration(at: now)
                self.recordRideSampleIfNeeded(at: now)
            }
        }
    }

    private var averageSpeedKilometersPerHour: Double {
        FitnessMath.speedKilometersPerHour(
            distanceMeters: distanceInMeters,
            durationSeconds: max(elapsedTime - breakDuration, 1)
        )
    }

    private var estimatedCalories: Double {
        FitnessMath.routeCalories(
            distanceKilometers: distanceInMeters / 1_000,
            bodyWeightKilograms: bodyWeightKilograms,
            multiplier: selectedKind.routeCalorieMultiplier
        )
    }

    private func updateSpeed(with location: CLLocation) {
        let speedMetersPerSecond: Double
        if location.speed >= 0 {
            speedMetersPerSecond = location.speed
        } else if let lastLocation {
            let distance = location.distance(from: lastLocation)
            let interval = max(location.timestamp.timeIntervalSince(lastLocation.timestamp), 1)
            speedMetersPerSecond = distance / interval
        } else {
            speedMetersPerSecond = 0
        }

        currentSpeedKilometersPerHour = max(speedMetersPerSecond * 3.6, 0)
        maxSpeedKilometersPerHour = max(maxSpeedKilometersPerHour, currentSpeedKilometersPerHour)
        updateBreakState(at: location.timestamp)
    }

    private func updateBreakState(at date: Date) {
        guard selectedKind == .cycling, elapsedTime > 20 else { return }

        if currentSpeedKilometersPerHour < 1.5 {
            if breakStartedAt == nil {
                breakStartedAt = date
            }
            refreshBreakDuration(at: date)
        } else {
            finalizeBreakIfNeeded(at: date)
        }
    }

    private func refreshBreakDuration(at date: Date) {
        if let breakStartedAt {
            breakDuration = accumulatedBreakDuration + max(date.timeIntervalSince(breakStartedAt), 0)
        } else {
            breakDuration = accumulatedBreakDuration
        }
    }

    private func finalizeBreakIfNeeded(at date: Date) {
        guard let breakStartedAt else { return }
        let duration = max(date.timeIntervalSince(breakStartedAt), 0)
        if duration >= 15 {
            breakCount += 1
            accumulatedBreakDuration += duration
        }
        self.breakStartedAt = nil
        breakDuration = accumulatedBreakDuration
    }

    private func recordRideSampleIfNeeded(at date: Date, force: Bool = false) {
        guard selectedKind == .cycling, let startedAt else { return }
        if !force, let lastSampleAt, date.timeIntervalSince(lastSampleAt) < 60 {
            return
        }

        let sample = RideMetricSample(
            timestamp: date,
            elapsedTime: max(date.timeIntervalSince(startedAt), 0),
            distanceInMeters: distanceInMeters,
            calories: estimatedCalories,
            speedKilometersPerHour: currentSpeedKilometersPerHour
        )

        if let last = rideSamples.last, abs(last.calories - sample.calories) < 0.5, !force {
            return
        }

        rideSamples.append(sample)
        lastSampleAt = date
    }

    func startCyclingRide() {
        guard !isTracking else { return }
        selectedKind = .cycling
        startTracking()
    }

    func toggleCyclingRide() {
        isTracking && selectedKind == .cycling ? stopTracking() : startCyclingRide()
    }

    private func saveCurrentRouteIfNeeded() {
        guard let startedAt, routeCoordinates.count > 1, distanceInMeters >= 10 else { return }
        recordRideSampleIfNeeded(at: startedAt.addingTimeInterval(elapsedTime), force: true)

        let session = RouteSession(
            kind: selectedKind,
            date: startedAt,
            endedAt: startedAt.addingTimeInterval(elapsedTime),
            duration: elapsedTime,
            distanceInMeters: distanceInMeters,
            calories: estimatedCalories,
            averageSpeedKilometersPerHour: averageSpeedKilometersPerHour,
            maxSpeedKilometersPerHour: maxSpeedKilometersPerHour,
            breakCount: breakCount,
            breakDuration: breakDuration,
            cyclingStepCount: selectedKind == .cycling ? FitnessMath.estimatedCyclingSteps(distanceMeters: distanceInMeters) : 0,
            samples: selectedKind == .cycling ? rideSamples : nil,
            points: routeCoordinates.map { RoutePoint(coordinate: $0) }
        )

        savedRoutes.insert(session, at: 0)
        savedRoutes = Array(savedRoutes.prefix(20))
        routeStore.save(savedRoutes)
    }

    private static func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }

        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
#else
@MainActor
final class RouteTracker: ObservableObject {
    @Published private(set) var routeCoordinates: [Never] = []
    @Published private(set) var distanceInMeters: Double = 0
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var currentSpeedKilometersPerHour: Double = 0
    @Published private(set) var maxSpeedKilometersPerHour: Double = 0
    @Published private(set) var breakCount = 0
    @Published private(set) var breakDuration: TimeInterval = 0
    @Published private(set) var rideSamples: [RideMetricSample] = []
    @Published private(set) var isTracking = false
    @Published private(set) var savedRoutes: [RouteSession] = RouteSession.preview
    @Published private(set) var selectedKind: ActivityKind = .walking

    var distanceText: String { "--" }
    var durationText: String { "00:00" }
    var caloriesText: String { "--" }
    var startTimeText: String { "--" }
    var currentSpeedText: String { "--" }
    var averageSpeedText: String { "--" }
    var maxSpeedText: String { "--" }
    var breakCountText: String { "0 breaks" }
    var breakDurationText: String { "0m" }
    var cyclingStepCountText: String { "--" }
    var locationAccessStatus: LocationAccessStatus { .unavailable }
    func selectKind(_ kind: ActivityKind) {}
    func updateBodyWeight(_ kilograms: Double) {}
    func toggleTracking() {}
    func startCyclingRide() {}
    func toggleCyclingRide() {}
}
#endif
