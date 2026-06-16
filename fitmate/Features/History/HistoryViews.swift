import SwiftUI

struct HistoryDashboard: View {
    @ObservedObject var store: FitnessStore
    @State private var selectedSummary: DailySummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("History")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)

                    Text("Daily trends from Health")
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                }

                Spacer()

                Picker("Range", selection: Binding(
                    get: { store.selectedRange },
                    set: { store.selectRange($0) }
                )) {
                    ForEach(HistoryRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 148)
            }

            if store.dailySummaries.isEmpty {
                Text("Enable Health access to see weekly and monthly trends.")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(store.dailySummaries) { summary in
                        DailySummaryRow(summary: summary, maxCalories: store.maxHistoryCalories) {
                            selectedSummary = summary
                        }
                    }
                }
            }
        }
        .padding(18)
        .sectionCard()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .sheet(item: $selectedSummary) { summary in
            DailySummaryDetailView(summary: summary, profile: store.profile)
        }
    }
}

private struct DailySummaryRow: View {
    let summary: DailySummary
    let maxCalories: Double
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(summary.dayText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.ink)

                    Spacer()

                    Text(summary.caloriesText)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(AppPalette.muted)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppPalette.muted.opacity(0.8))
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppPalette.border.opacity(0.55))

                        Capsule()
                            .fill(LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing))
                            .frame(width: proxy.size.width * summary.progress(maxCalories: maxCalories))
                    }
                }
                .frame(height: 8)

                HStack(spacing: 10) {
                    Label(summary.steps.formatted(), systemImage: "shoeprints.fill")
                    Label(summary.distanceText, systemImage: "map.fill")
                    Label(summary.activeTimeText, systemImage: "timer")
                }
                .font(.caption2)
                .foregroundStyle(AppPalette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .padding(12)
            .background(Color.white.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct DailySummaryDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let summary: DailySummary
    let profile: FitnessProfile

    private let activityKinds: [ActivityKind] = [.walking, .running, .cycling, .jumpingJacks]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(summary.fullDateText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppPalette.muted)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(summary.caloriesText)
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(AppPalette.ink)
                                .monospacedDigit()

                            Text("burned")
                                .font(.headline)
                                .foregroundStyle(AppPalette.muted)
                        }

                        HStack(spacing: 10) {
                            DailyDetailMetric(title: "Steps", value: summary.steps.formatted(), icon: "shoeprints.fill", tint: .green)
                            DailyDetailMetric(title: "Distance", value: summary.distanceText, icon: "map.fill", tint: .blue)
                            DailyDetailMetric(title: "Active", value: summary.activeMinutesText, icon: "timer", tint: .orange)
                        }
                    }
                    .padding(18)
                    .sectionCard()

                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeaderLight(title: "Goal performance", subtitle: summary.goalScoreText(profile: profile), icon: "target")

                        DailyGoalRow(
                            title: "Move",
                            value: summary.caloriesText,
                            target: "\(profile.calorieGoal.formatted()) cal goal",
                            progress: summary.calorieGoalProgress(profile: profile),
                            tint: .orange,
                            icon: "flame.fill"
                        )

                        DailyGoalRow(
                            title: "Steps",
                            value: summary.steps.formatted(),
                            target: "\(profile.stepGoal.formatted()) steps goal",
                            progress: summary.stepGoalProgress(profile: profile),
                            tint: .green,
                            icon: "shoeprints.fill"
                        )

                        DailyGoalRow(
                            title: "Active minutes",
                            value: summary.activeMinutesText,
                            target: "\(profile.activeMinutesGoal)m goal",
                            progress: summary.activeGoalProgress(profile: profile),
                            tint: .blue,
                            icon: "timer"
                        )
                    }
                    .padding(18)
                    .sectionCard()

                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeaderLight(title: "Activity calories", subtitle: "How this day was split", icon: "chart.bar.fill")

                        ForEach(activityKinds) { kind in
                            DailyActivityBurnRow(
                                kind: kind,
                                calories: summary.calories(for: kind),
                                totalCalories: max(summary.activityCaloriesTotal, 1)
                            )
                        }
                    }
                    .padding(18)
                    .sectionCard()
                }
                .padding(18)
            }
            .background(DashboardBackground())
            .navigationTitle(summary.dayText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct DailyDetailMetric: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppPalette.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppPalette.muted)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SectionHeaderLight: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppPalette.ink)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppPalette.muted)
            }

            Spacer()
        }
    }
}

private struct DailyGoalRow: View {
    let title: String
    let value: String
    let target: String
    let progress: Double
    let tint: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.ink)

                    Text(target)
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                }

                Spacer()

                Text(value)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppPalette.ink)
            }

            ProgressView(value: progress)
                .tint(tint)
        }
        .padding(12)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DailyActivityBurnRow: View {
    let kind: ActivityKind
    let calories: Double
    let totalCalories: Double

    private var progress: Double {
        FitnessMath.progress(current: calories, target: totalCalories)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(kind.tint.opacity(0.14))
                    .frame(width: 38, height: 38)

                Image(systemName: kind.icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(kind.tint)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(kind.dashboardTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.ink)

                    Spacer()

                    Text("\(Int(calories.rounded())) cal")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppPalette.muted)
                }

                ProgressView(value: progress)
                    .tint(kind.tint)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

