import SwiftUI
import Combine

#if os(iOS)
import CoreMotion
import HealthKit
import MapKit
import CoreLocation
#endif

final class FitnessStore: ObservableObject {
    @Published private(set) var steps = 0
    @Published private(set) var distanceInMeters: Double?
    @Published private(set) var activeEnergyCalories: Double?
    @Published private(set) var activities: [DailyActivity] = []
    @Published private(set) var dailySummaries: [DailySummary] = []
    @Published private(set) var selectedRange: HistoryRange = .week
    @Published private(set) var statusMessage = "Syncing today's movement..."
    @Published private(set) var healthAccessStatus: HealthAccessStatus = .checking
    @Published private(set) var motionAccessStatus: MotionAccessStatus = .checking
    @Published private(set) var profile = FitnessProfile.load()

#if os(iOS)
    private let pedometer = CMPedometer()
    private var baselineSteps = 0
    private var baselineDistanceInMeters: Double = 0
    private let healthStore = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []
#endif

    var headline: String {
        if totalCalories > 0 {
            return "You burned \(Int(totalCalories.rounded())) cal"
        }
        return "Your day, auto tracked"
    }

    var totalCalories: Double {
        if let activeEnergyCalories {
            return activeEnergyCalories
        }

        return activities.reduce(estimatedWalkingCalories) { $0 + $1.calories }
    }

    var totalCaloriesText: String {
        "\(Int(totalCalories.rounded())) cal"
    }

    var calorieSourceText: String {
        activeEnergyCalories == nil ? "estimated" : "from Health"
    }

    var stepProgressPercent: Int {
        Int((stepProgress * 100).rounded())
    }

    var calorieProgressPercent: Int {
        Int((calorieProgress * 100).rounded())
    }

    var activeProgressPercent: Int {
        Int((activeProgress * 100).rounded())
    }

    var stepProgress: Double {
        FitnessMath.progress(current: Double(steps), target: Double(profile.stepGoal))
    }

    var calorieProgress: Double {
        FitnessMath.progress(current: totalCalories, target: Double(profile.calorieGoal))
    }

    var activeProgress: Double {
        FitnessMath.progress(current: Double(activeMinutes), target: Double(profile.activeMinutesGoal))
    }

    var activeMinutes: Int {
        Int((activities.reduce(0) { $0 + $1.duration } / 60).rounded())
    }

    var activeTimeText: String {
        formatDuration(activities.reduce(0) { $0 + $1.duration }, compact: true)
    }

    var distanceText: String {
        guard let distanceInMeters else {
            return "--"
        }
        return formatKilometers(distanceInMeters)
    }

    var emptyActivitiesMessage: String {
        switch healthAccessStatus {
        case .available:
            return "No workouts found in Apple Health for today yet. Steps, distance, and calories still sync automatically."
        case .unavailable:
            return "Health data is unavailable on this device. FitMate can still show live steps while the app is open."
        case .denied:
            return "Enable Health access to import today's workouts automatically."
        case .checking:
            return "Checking Health access..."
        }
    }

    var maxHistoryCalories: Double {
        max(dailySummaries.map(\.calories).max() ?? 1, 1)
    }

    var goalScoreText: String {
        "\(Int(((stepProgress + calorieProgress + activeProgress) / 3 * 100).rounded()))%"
    }

    var goalInsightText: String {
        if stepProgress >= 1, calorieProgress >= 1, activeProgress >= 1 {
            return "All daily goals completed."
        }

        let remainingSteps = max(profile.stepGoal - steps, 0)
        let remainingCalories = max(profile.calorieGoal - Int(totalCalories.rounded()), 0)
        let remainingActive = max(profile.activeMinutesGoal - activeMinutes, 0)

        if remainingSteps > 0 {
            return "\(remainingSteps.formatted()) steps left for today's target."
        }
        if remainingCalories > 0 {
            return "\(remainingCalories.formatted()) calories left for your move goal."
        }
        if remainingActive > 0 {
            return "\(remainingActive) active minutes left."
        }
        return "Daily goals are nearly complete."
    }

    var analyticsSubtitle: String {
        selectedRange == .week ? "7-day movement trend" : "30-day movement trend"
    }

    var averageStepsText: String {
        guard let average = FitnessMath.average(dailySummaries.map(\.steps)) else { return "--" }
        return average.formatted()
    }

    var averageCaloriesText: String {
        guard let average = FitnessMath.average(dailySummaries.map(\.calories)) else { return "--" }
        return "\(Int(average.rounded())) cal"
    }

    var bestDayText: String {
        guard let best = dailySummaries.max(by: { $0.calories < $1.calories }), best.calories > 0 else {
            return "--"
        }
        return best.shortDayText
    }

    var coachingInsightText: String {
        guard !dailySummaries.isEmpty else {
            return "Enable Health access to unlock trend insights from your daily activity."
        }

        let activeDays = dailySummaries.filter { $0.steps > 0 || $0.calories > 0 }.count
        let goalDays = dailySummaries.filter { $0.steps >= profile.stepGoal || $0.calories >= Double(profile.calorieGoal) }.count

        if goalDays >= max(1, dailySummaries.count / 2) {
            return "Strong consistency: you hit at least one daily target on \(goalDays) days in this range."
        }
        if activeDays > 0 {
            return "You recorded activity on \(activeDays) days. A short walk or route session can lift this trend today."
        }
        return "No movement trend yet. FitMate will fill this automatically as Health data arrives."
    }

    var goalCompletionSummaries: [GoalCompletionSummary] {
        dailySummaries.map { summary in
            let stepScore = FitnessMath.progress(current: Double(summary.steps), target: Double(profile.stepGoal))
            let calorieScore = FitnessMath.progress(current: summary.calories, target: Double(profile.calorieGoal))
            let activeMinutes = summary.activeDuration / 60
            let activeScore = FitnessMath.progress(current: activeMinutes, target: Double(profile.activeMinutesGoal))
            let averageScore = (stepScore + calorieScore + activeScore) / 3
            let isTargetHit = stepScore >= 1 || calorieScore >= 1 || activeScore >= 1

            return GoalCompletionSummary(date: summary.date, score: averageScore, isTargetHit: isTargetHit)
        }
    }

    var currentStreakText: String {
        let streak = FitnessMath.currentStreak(goalCompletionSummaries.map(\.isTargetHit))
        return "\(streak)d streak"
    }

    var goalDaysText: String {
        let days = goalCompletionSummaries.filter(\.isTargetHit).count
        return "\(days)/\(max(goalCompletionSummaries.count, 1))"
    }

    var completionRateText: String {
        let rate = FitnessMath.completionRate(goalCompletionSummaries.map(\.isTargetHit))
        return "\(Int((rate * 100).rounded()))%"
    }

    var averageGoalScoreText: String {
        guard let average = FitnessMath.average(goalCompletionSummaries.map(\.score)) else { return "--" }
        return "\(Int((average * 100).rounded()))%"
    }

    var consistencyInsightText: String {
        let summaries = goalCompletionSummaries
        guard !summaries.isEmpty else {
            return "Goal streaks appear as Health history syncs."
        }

        let streak = FitnessMath.currentStreak(summaries.map(\.isTargetHit))
        if streak >= 3 {
            return "Nice momentum: \(streak) goal days in a row."
        }

        let hitCount = summaries.filter(\.isTargetHit).count
        if hitCount > 0 {
            return "You hit a daily target on \(hitCount) days in this range."
        }

        return "No goal days yet in this range."
    }

    func dataReadinessText(locationStatus: LocationAccessStatus) -> String {
        let connectedCount = [
            healthAccessStatus == .available,
            motionAccessStatus == .available,
            locationStatus == .available
        ].filter { $0 }.count

        return "\(connectedCount)/3 live"
    }

    func rangeActivitySummaries(routeSessions: [RouteSession] = []) -> [ActivityRangeSummary] {
        let trackedKinds: [ActivityKind] = [.walking, .running, .cycling, .jumpingJacks]
        let rangeRoutes = filteredRouteSessions(in: selectedRange, from: routeSessions)
        let totals = trackedKinds.reduce(into: [ActivityKind: Double]()) { partialResult, kind in
            let healthCalories = dailySummaries.reduce(0) { $0 + $1.calories(for: kind) }
            let matchingRoutes = rangeRoutes.filter { $0.kind == kind }
            let routeCalories = matchingRoutes.reduce(0.0) { total, route in
                total + route.calories
            }
            partialResult[kind] = healthCalories + routeCalories
        }
        let maxCalories = max(totals.values.max() ?? 1, 1)

        return trackedKinds.map { kind in
            let calories = totals[kind] ?? 0
            let healthActiveDays = dailySummaries.filter { $0.calories(for: kind) > 0 }.map(\.date)
            let routeActiveDays = rangeRoutes
                .filter { route in route.kind == kind }
                .map { Calendar.current.startOfDay(for: $0.date) }
            let activeDays = Set(healthActiveDays + routeActiveDays).count
            return ActivityRangeSummary(
                kind: kind,
                calories: calories,
                activeDays: activeDays,
                progress: FitnessMath.progress(current: calories, target: maxCalories)
            )
        }
    }

    func rangeActivityTotalText(routeSessions: [RouteSession] = []) -> String {
        let total = rangeActivitySummaries(routeSessions: routeSessions).reduce(0) { $0 + $1.calories }
        return "\(Int(total.rounded())) cal"
    }

    private func filteredRouteSessions(in range: HistoryRange, from sessions: [RouteSession]) -> [RouteSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(range.dayCount - 1), to: today) ?? today
        return sessions.filter { session in
            let day = calendar.startOfDay(for: session.date)
            return day >= start && day <= today
        }
    }

    func start() {
        requestHealthAccess()
        startStepFallback()
    }

    func refreshToday() {
        statusMessage = "Refreshing today's activity..."
        fetchTodayFromHealth()
        fetchHistoryFromHealth()
        startStepFallback()
    }

    func selectRange(_ range: HistoryRange) {
        selectedRange = range
        fetchHistoryFromHealth()
    }

    func adjustStepGoal(by amount: Int) {
        profile.stepGoal = min(max(profile.stepGoal + amount, 1_000), 50_000)
        saveProfile()
        updateStatusAfterHealthSync()
    }

    func adjustCalorieGoal(by amount: Int) {
        profile.calorieGoal = min(max(profile.calorieGoal + amount, 50), 2_500)
        saveProfile()
    }

    func adjustActiveGoal(by amount: Int) {
        profile.activeMinutesGoal = min(max(profile.activeMinutesGoal + amount, 5), 240)
        saveProfile()
    }

    func adjustBodyWeight(by amount: Double) {
        profile.bodyWeightKilograms = min(max(profile.bodyWeightKilograms + amount, 35), 200)
        saveProfile()
    }

    func requestHealthAccess() {
#if os(iOS)
        guard HKHealthStore.isHealthDataAvailable() else {
            healthAccessStatus = .unavailable
            statusMessage = "Health data is unavailable on this device."
            startStepFallback()
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        healthStore.requestAuthorization(toShare: [], read: readTypes) { [weak self] success, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.healthAccessStatus = success ? .available : .denied
                self.statusMessage = success ? "Imported today's activity from Apple Health." : "Health access is needed for full-day automatic activity tracking."
                if success {
                    self.configureBackgroundHealthSync()
                    self.fetchTodayFromHealth()
                    self.fetchHistoryFromHealth()
                } else {
                    self.startStepFallback()
                }
            }
        }
#else
        healthAccessStatus = .unavailable
        steps = 7_240
        distanceInMeters = 5_320
        activeEnergyCalories = 382
        activities = DailyActivity.preview
        dailySummaries = DailySummary.preview
        statusMessage = "Health sync runs on iPhone. Showing preview activity."
#endif
    }

    func calories(for kind: ActivityKind) -> Double {
        let workoutCalories = activities.filter { $0.kind == kind }.reduce(0) { $0 + $1.calories }

        if kind == .walking, workoutCalories == 0 {
            return estimatedWalkingCalories
        }

        return workoutCalories
    }

    func summary(for kind: ActivityKind) -> ActivitySummary {
        let matchingActivities = activities.filter { $0.kind == kind }
        let workoutCalories = matchingActivities.reduce(0) { $0 + $1.calories }
        let calories = kind == .walking && workoutCalories == 0 ? estimatedWalkingCalories : workoutCalories
        let duration = matchingActivities.reduce(0) { $0 + $1.duration }
        let distance = matchingActivities.compactMap(\.distanceInMeters).reduce(0, +)

        let resolvedDistance: Double?
        if distance > 0 {
            resolvedDistance = distance
        } else if kind == .walking {
            resolvedDistance = distanceInMeters
        } else {
            resolvedDistance = nil
        }

        return ActivitySummary(
            kind: kind,
            calories: calories,
            durationText: formatDuration(duration, compact: true),
            distanceText: resolvedDistance.map(formatKilometers),
            sessionCount: matchingActivities.count,
            steps: kind == .walking ? steps : nil
        )
    }

    func breakdownProgress(for kind: ActivityKind) -> Double {
        guard totalCalories > 0 else { return 0 }
        return calories(for: kind) / totalCalories
    }

    private var estimatedWalkingCalories: Double {
        let distanceKilometers = (distanceInMeters ?? 0) / 1_000
        return FitnessMath.walkingCalories(distanceKilometers: distanceKilometers, bodyWeightKilograms: profile.bodyWeightKilograms)
    }

    private func saveProfile() {
        profile.save()
    }

    private func formatDuration(_ duration: TimeInterval, compact: Bool) -> String {
        let seconds = max(Int(duration.rounded()), 0)
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60

        if hours > 0 {
            return compact ? "\(hours)h \(minutes)m" : String(format: "%d:%02d", hours, minutes)
        }

        return compact ? "\(minutes)m" : "\(minutes) min"
    }

    private func formatKilometers(_ meters: Double) -> String {
        let kilometers = meters / 1_000
        return kilometers.formatted(.number.precision(.fractionLength(1))) + " km"
    }

#if os(iOS)
    private var backgroundHealthSampleTypes: [HKSampleType] {
        [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        ].compactMap { $0 }
    }

    private func configureBackgroundHealthSync() {
        guard observerQueries.isEmpty else { return }

        for sampleType in backgroundHealthSampleTypes {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, _ in
                Task { @MainActor [weak self] in
                    guard let self else {
                        completionHandler()
                        return
                    }
                    self.fetchTodayFromHealth()
                    self.fetchHistoryFromHealth()
                    completionHandler()
                }
            }

            healthStore.execute(query)
            observerQueries.append(query)

            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .hourly) { _, _ in }
        }
    }

    private func fetchTodayFromHealth() {
        guard healthAccessStatus == .available else { return }
        fetchQuantity(.stepCount, unit: .count()) { [weak self] value in
            self?.steps = Int(value.rounded())
            self?.updateStatusAfterHealthSync()
        }
        fetchQuantity(.distanceWalkingRunning, unit: .meter()) { [weak self] value in
            self?.distanceInMeters = value
        }
        fetchQuantity(.activeEnergyBurned, unit: .kilocalorie()) { [weak self] value in
            self?.activeEnergyCalories = value
        }
        fetchWorkouts()
    }

    private func fetchHistoryFromHealth() {
        guard healthAccessStatus == .available else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = (0..<selectedRange.dayCount).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
        .reversed()

        dailySummaries = dates.map { DailySummary(date: $0) }

        for date in dates {
            fetchDailySummary(for: date) { [weak self] summary in
                guard let self else { return }
                if let index = self.dailySummaries.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: summary.date) }) {
                    self.dailySummaries[index] = summary
                }
            }
        }
    }

    private func fetchDailySummary(for date: Date, completion: @escaping @MainActor (DailySummary) -> Void) {
        let group = DispatchGroup()
        var steps = 0
        var distance = 0.0
        var calories = 0.0
        var workoutDuration: TimeInterval = 0
        var workoutBreakdown: [ActivityKind: Double] = [:]

        group.enter()
        fetchQuantity(.stepCount, unit: .count(), date: date) { value in
            steps = Int(value.rounded())
            group.leave()
        }

        group.enter()
        fetchQuantity(.distanceWalkingRunning, unit: .meter(), date: date) { value in
            distance = value
            group.leave()
        }

        group.enter()
        fetchQuantity(.activeEnergyBurned, unit: .kilocalorie(), date: date) { value in
            calories = value
            group.leave()
        }

        group.enter()
        fetchWorkoutDuration(for: date) { value in
            workoutDuration = value
            group.leave()
        }

        group.enter()
        fetchWorkoutBreakdown(for: date) { value in
            workoutBreakdown = value
            group.leave()
        }

        group.notify(queue: .main) {
            var activityCalories = workoutBreakdown
            if (activityCalories[.walking] ?? 0) == 0, distance > 0 {
                activityCalories[.walking] = FitnessMath.walkingCalories(distanceKilometers: distance / 1_000, bodyWeightKilograms: self.profile.bodyWeightKilograms)
            }

            let summary = DailySummary(
                date: date,
                steps: steps,
                distanceInMeters: distance,
                calories: calories,
                activeDuration: workoutDuration,
                activityCalories: activityCalories
            )
            Task { @MainActor in
                completion(summary)
            }
        }
    }

    private func fetchQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping @MainActor (Double) -> Void) {
        fetchQuantity(identifier, unit: unit, date: Date(), completion: completion)
    }

    private func fetchQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, date: Date, completion: @escaping @MainActor (Double) -> Void) {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return }

        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
        let cappedEnd = min(end, Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: cappedEnd, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
            Task { @MainActor in
                completion(value)
            }
        }

        healthStore.execute(query)
    }

    private func fetchWorkoutDuration(for date: Date, completion: @escaping @MainActor (TimeInterval) -> Void) {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
        let cappedEnd = min(end, Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: cappedEnd, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let duration = ((samples as? [HKWorkout]) ?? []).reduce(0) { $0 + $1.duration }
            Task { @MainActor in
                completion(duration)
            }
        }

        healthStore.execute(query)
    }

    private func fetchWorkoutBreakdown(for date: Date, completion: @escaping @MainActor ([ActivityKind: Double]) -> Void) {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
        let cappedEnd = min(end, Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: cappedEnd, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let workouts = (samples as? [HKWorkout]) ?? []

            Task { @MainActor in
                let breakdown = workouts.reduce(into: [ActivityKind: Double]()) { partialResult, workout in
                    let kind = ActivityKind(workoutActivityType: workout.workoutActivityType)
                    guard kind != .workout else { return }
                    let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
                    partialResult[kind, default: 0] += calories
                }
                completion(breakdown)
            }
        }

        healthStore.execute(query)
    }

    private func fetchWorkouts() {
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 30, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            let workouts = (samples as? [HKWorkout]) ?? []

            Task { @MainActor [weak self] in
                let activities = workouts.map(DailyActivity.init)
                self?.activities = activities
                self?.updateStatusAfterHealthSync()
            }
        }

        healthStore.execute(query)
    }

    private func updateStatusAfterHealthSync() {
        let remaining = max(profile.stepGoal - steps, 0)
        if remaining == 0 {
            statusMessage = "Daily step goal completed. Health data is synced automatically."
        } else {
            statusMessage = "\(remaining.formatted()) steps left. Activity totals sync from Apple Health."
        }
    }

    private func startStepFallback() {
        guard CMPedometer.isStepCountingAvailable() else {
            motionAccessStatus = .unavailable
            return
        }

        updateMotionAuthorizationStatus()

        pedometer.queryPedometerData(from: Calendar.current.startOfDay(for: Date()), to: Date()) { [weak self] data, error in
            Task { @MainActor [weak self] in
                self?.applyTodayTotal(data: data, error: error)
            }
        }

        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            Task { @MainActor [weak self] in
                self?.applyLiveUpdate(data: data, error: error)
            }
        }
    }

    private func applyTodayTotal(data: CMPedometerData?, error: Error?) {
        if error != nil, healthAccessStatus != .available {
            statusMessage = "Allow Motion & Fitness access for live step fallback."
            return
        }

        guard let data, healthAccessStatus != .available else { return }
        motionAccessStatus = .available
        baselineSteps = data.numberOfSteps.intValue
        baselineDistanceInMeters = data.distance?.doubleValue ?? 0
        steps = baselineSteps
        distanceInMeters = data.distance?.doubleValue
    }

    private func applyLiveUpdate(data: CMPedometerData?, error: Error?) {
        if error != nil, healthAccessStatus != .available {
            statusMessage = "Allow Motion & Fitness access for live step fallback."
            return
        }

        guard let data, healthAccessStatus != .available else { return }
        motionAccessStatus = .available
        steps = baselineSteps + data.numberOfSteps.intValue
        distanceInMeters = baselineDistanceInMeters + (data.distance?.doubleValue ?? 0)
    }

    private func updateMotionAuthorizationStatus() {
        switch CMPedometer.authorizationStatus() {
        case .authorized:
            motionAccessStatus = .available
        case .denied, .restricted:
            motionAccessStatus = .denied
        case .notDetermined:
            motionAccessStatus = .checking
        @unknown default:
            motionAccessStatus = .checking
        }
    }
#else
    private func fetchTodayFromHealth() {}
    private func startStepFallback() {}
#endif
}

