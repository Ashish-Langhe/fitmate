import Foundation

enum FitnessMath {
    static func progress(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1)
    }

    static func walkingCalories(distanceKilometers: Double, bodyWeightKilograms: Double) -> Double {
        max(distanceKilometers, 0) * max(bodyWeightKilograms, 0) * 0.57
    }

    static func routeCalories(distanceKilometers: Double, bodyWeightKilograms: Double, multiplier: Double) -> Double {
        max(distanceKilometers, 0) * max(bodyWeightKilograms, 0) * max(multiplier, 0)
    }

    static func average(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / values.count
    }

    static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    static func currentStreak(_ completions: [Bool]) -> Int {
        var count = 0
        for isComplete in completions.reversed() {
            guard isComplete else { break }
            count += 1
        }
        return count
    }

    static func completionRate(_ completions: [Bool]) -> Double {
        guard !completions.isEmpty else { return 0 }
        let completedCount = completions.filter { $0 }.count
        return Double(completedCount) / Double(completions.count)
    }

    static func goalScore(stepProgress: Double, calorieProgress: Double, activeProgress: Double) -> Double {
        let scores = [stepProgress, calorieProgress, activeProgress].map { min(max($0, 0), 1) }
        return scores.reduce(0, +) / Double(scores.count)
    }
}
