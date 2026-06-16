import SwiftUI

struct GoalSettingsCard: View {
    @ObservedObject var store: FitnessStore
    @ObservedObject var routeTracker: RouteTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Goals & profile")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)

                    Text("Personalize targets and calorie estimates")
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                }

                Spacer()

                Image(systemName: "slider.horizontal.3")
                    .font(.headline)
                    .foregroundStyle(AppPalette.green)
            }

            VStack(spacing: 10) {
                GoalControlRow(
                    title: "Step goal",
                    value: store.profile.stepGoal.formatted(),
                    unit: "steps",
                    tint: .green,
                    decrement: { store.adjustStepGoal(by: -500) },
                    increment: { store.adjustStepGoal(by: 500) }
                )

                GoalControlRow(
                    title: "Move goal",
                    value: store.profile.calorieGoal.formatted(),
                    unit: "cal",
                    tint: .red,
                    decrement: { store.adjustCalorieGoal(by: -25) },
                    increment: { store.adjustCalorieGoal(by: 25) }
                )

                GoalControlRow(
                    title: "Active goal",
                    value: store.profile.activeMinutesGoal.formatted(),
                    unit: "min",
                    tint: .blue,
                    decrement: { store.adjustActiveGoal(by: -5) },
                    increment: { store.adjustActiveGoal(by: 5) }
                )

                GoalControlRow(
                    title: "Body weight",
                    value: store.profile.bodyWeightKilograms.formatted(.number.precision(.fractionLength(0))),
                    unit: "kg",
                    tint: .orange,
                    decrement: {
                        store.adjustBodyWeight(by: -1)
                        routeTracker.updateBodyWeight(store.profile.bodyWeightKilograms)
                    },
                    increment: {
                        store.adjustBodyWeight(by: 1)
                        routeTracker.updateBodyWeight(store.profile.bodyWeightKilograms)
                    }
                )
            }
        }
        .padding(18)
        .sectionCard()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct GoalControlRow: View {
    let title: String
    let value: String
    let unit: String
    let tint: Color
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)

                Text("\(value) \(unit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppPalette.muted)
            }

            Spacer()

            HStack(spacing: 6) {
                Button(action: decrement) {
                    Image(systemName: "minus")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
                .tint(tint)
                .accessibilityLabel("Decrease \(title)")

                Button(action: increment) {
                    Image(systemName: "plus")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderedProminent)
                .tint(tint)
                .accessibilityLabel("Increase \(title)")
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct AutoTrackingCard: View {
    @ObservedObject var store: FitnessStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: store.healthAccessStatus.icon)
                    .font(.title2)
                    .foregroundStyle(store.healthAccessStatus.tint)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Automatic daily tracking")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)

                    Text(store.healthAccessStatus.message)
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if store.healthAccessStatus != .available {
                Button {
                    store.requestHealthAccess()
                } label: {
                    Label("Enable Health Access", systemImage: "heart.text.square.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(18)
        .sectionCard()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct CalorieBreakdown: View {
    @ObservedObject var store: FitnessStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Calories by activity")
                    .font(.headline)
                    .foregroundStyle(AppPalette.ink)
                Spacer()
                Text(store.totalCaloriesText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.muted)
            }

            ForEach(ActivityKind.allCases) { kind in
                let calories = store.calories(for: kind)
                HStack(spacing: 12) {
                    Image(systemName: kind.icon)
                        .font(.headline)
                        .foregroundStyle(kind.tint)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(kind.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppPalette.ink)
                            Spacer()
                            Text("\(Int(calories.rounded())) cal")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(AppPalette.muted)
                        }

                        ProgressView(value: store.breakdownProgress(for: kind))
                            .tint(kind.tint)
                    }
                }
            }
        }
        .padding(18)
        .sectionCard()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ActivityTimeline: View {
    @ObservedObject var store: FitnessStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today's activities")
                .font(.headline)
                .foregroundStyle(AppPalette.ink)

            if store.activities.isEmpty {
                Text(store.emptyActivitiesMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(store.activities) { activity in
                    HStack(spacing: 12) {
                        Image(systemName: activity.kind.icon)
                            .font(.headline)
                            .foregroundStyle(activity.kind.tint)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(activity.kind.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppPalette.ink)

                            Text(activity.detailText)
                                .font(.caption)
                                .foregroundStyle(AppPalette.muted)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(Int(activity.calories.rounded())) cal")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(AppPalette.ink)
                            Text(activity.timeText)
                                .font(.caption2)
                                .foregroundStyle(AppPalette.muted)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(18)
        .sectionCard()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

