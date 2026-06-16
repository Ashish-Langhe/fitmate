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
    @Published private(set) var isTracking = false
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var savedRoutes: [RouteSession] = []
    @Published private(set) var selectedKind: ActivityKind = .walking

    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var startedAt: Date?
    private var timer: Timer?
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
        lastLocation = nil
        startedAt = Date()
        isTracking = true
        locationManager.startUpdatingLocation()
        scheduleTimer()
    }

    func stopTracking() {
        if let startedAt {
            elapsedTime = Date().timeIntervalSince(startedAt)
        }
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
            lastLocation = location
            routeCoordinates.append(location.coordinate)
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let startedAt = self.startedAt else { return }
                self.elapsedTime = Date().timeIntervalSince(startedAt)
            }
        }
    }

    private var estimatedCalories: Double {
        FitnessMath.routeCalories(
            distanceKilometers: distanceInMeters / 1_000,
            bodyWeightKilograms: bodyWeightKilograms,
            multiplier: selectedKind.routeCalorieMultiplier
        )
    }

    private func saveCurrentRouteIfNeeded() {
        guard let startedAt, routeCoordinates.count > 1, distanceInMeters >= 10 else { return }

        let session = RouteSession(
            kind: selectedKind,
            date: startedAt,
            duration: elapsedTime,
            distanceInMeters: distanceInMeters,
            calories: estimatedCalories,
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
    @Published private(set) var isTracking = false
    @Published private(set) var savedRoutes: [RouteSession] = RouteSession.preview
    @Published private(set) var selectedKind: ActivityKind = .walking

    var distanceText: String { "--" }
    var durationText: String { "00:00" }
    var caloriesText: String { "--" }
    var locationAccessStatus: LocationAccessStatus { .unavailable }
    func selectKind(_ kind: ActivityKind) {}
    func updateBodyWeight(_ kilograms: Double) {}
    func toggleTracking() {}
}
#endif

