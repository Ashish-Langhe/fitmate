import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FitMateCalculationChecks failed: \(message)\n", stderr)
        exit(1)
    }
}

func expectApproximatelyEqual(_ actual: Double, _ expected: Double, tolerance: Double = 0.0001, _ message: String) {
    expect(abs(actual - expected) <= tolerance, message)
}

@main
struct FitMateCalculationChecks {
    static func main() {
        expect(FitnessMath.progress(current: 5_000, target: 10_000) == 0.5, "step progress should be 50%")
        expect(FitnessMath.progress(current: 12_000, target: 10_000) == 1, "progress should clamp at 100%")
        expect(FitnessMath.progress(current: -10, target: 10_000) == 0, "progress should not go below zero")
        expect(FitnessMath.progress(current: 100, target: 0) == 0, "zero target should produce zero progress")

        let walkingCalories = FitnessMath.walkingCalories(distanceKilometers: 5, bodyWeightKilograms: 70)
        expectApproximatelyEqual(walkingCalories, 199.5, "walking calories should use 0.57 kcal/kg/km")

        let routeCalories = FitnessMath.routeCalories(distanceKilometers: 5, bodyWeightKilograms: 70, multiplier: 0.75)
        expectApproximatelyEqual(routeCalories, 262.5, "route calories should use 0.75 kcal/kg/km")

        expect(FitnessMath.average([1_000, 3_000, 5_000]) == 3_000, "integer average should be stable")
        expect(FitnessMath.average([120.0, 180.0, 300.0]) == 200, "double average should be stable")
        expect(FitnessMath.average([Int]()) == nil, "empty integer average should be nil")
        expect(FitnessMath.average([Double]()) == nil, "empty double average should be nil")
        expect(FitnessMath.currentStreak([true, false, true, true]) == 2, "current streak should count backward from latest day")
        expect(FitnessMath.currentStreak([true, true, false]) == 0, "current streak should stop when latest day is incomplete")
        expectApproximatelyEqual(FitnessMath.completionRate([true, false, true, true]), 0.75, "completion rate should be completed days divided by total days")
        expect(FitnessMath.completionRate([]) == 0, "empty completion rate should be zero")
        expectApproximatelyEqual(FitnessMath.goalScore(stepProgress: 1.2, calorieProgress: 0.5, activeProgress: -1), 0.5, "goal score should clamp and average goal progress")

        print("FitMateCalculationChecks passed")
    }
}
