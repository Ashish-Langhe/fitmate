import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: FitnessStore
    @ObservedObject var routeTracker: RouteTracker
    @State private var selectedSection: DashboardSection = .overview

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        TodayHeader(store: store)
                        DashboardSectionPicker(selectedSection: $selectedSection)

                        switch selectedSection {
                        case .overview:
                            SummaryGrid(store: store)
                            DataSourcesCard(store: store, routeTracker: routeTracker)
                            GoalProgressCard(store: store)
                            ConsistencyCard(store: store)
                            ActivityDashboard(store: store)
                        case .activity:
                            ActivityDashboard(store: store)
                            CalorieBreakdown(store: store)
                            ActivityTimeline(store: store)
                            AutoTrackingCard(store: store)
                        case .history:
                            HistoryDashboard(store: store)
                            AnalyticsInsightsCard(store: store)
                            RangeActivityBreakdownCard(store: store, routeTracker: routeTracker)
                        case .routes:
                            RouteTrackingCard(routeTracker: routeTracker)
                            GoalSettingsCard(store: store, routeTracker: routeTracker)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.refreshToday()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(AppPalette.ink)
                    }
                    .accessibilityLabel("Refresh today's activity")
                }
            }
            .onAppear {
                routeTracker.updateBodyWeight(store.profile.bodyWeightKilograms)
            }
            .onChange(of: store.profile.bodyWeightKilograms) { _, weight in
                routeTracker.updateBodyWeight(weight)
            }
        }
    }
}

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview
    case activity
    case history
    case routes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .activity:
            return "Activity"
        case .history:
            return "History"
        case .routes:
            return "Routes"
        }
    }
}

struct DashboardSectionPicker: View {
    @Binding var selectedSection: DashboardSection

    var body: some View {
        Picker("Dashboard section", selection: $selectedSection) {
            ForEach(DashboardSection.allCases) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .padding(5)
        .background(Color.white.opacity(0.78))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppPalette.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel("Dashboard section")
    }
}

struct DashboardBackground: View {
    var body: some View {
        LinearGradient(
            colors: [AppPalette.pageTop, AppPalette.page, AppPalette.pageBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(AppPalette.mint.opacity(0.16))
                    .frame(height: 180)
                    .rotationEffect(.degrees(-7))
                    .offset(y: -78)

                Spacer()

                Rectangle()
                    .fill(Color.blue.opacity(0.07))
                    .frame(height: 160)
                    .rotationEffect(.degrees(-6))
                    .offset(y: 84)
            }
            .ignoresSafeArea()
        }
    }
}

private struct TodayHeader: View {
    @ObservedObject var store: FitnessStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                LogoMark(size: 58)

                VStack(alignment: .leading, spacing: 5) {
                    Text("FitMate")
                        .font(.title3.bold())
                        .foregroundStyle(AppPalette.ink)

                    Text("Auto-synced daily fitness")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.muted)
                }

                Spacer()

                StatusPill(status: store.healthAccessStatus)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Today")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppPalette.green)

                Text(store.headline)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(store.statusMessage)
                    .font(.callout)
                    .foregroundStyle(AppPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                HeroMetric(title: "Steps", value: store.steps.formatted())
                HeroMetric(title: "Distance", value: store.distanceText)
                HeroMetric(title: "Active", value: store.activeTimeText)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.white, Color(red: 0.91, green: 0.98, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppPalette.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: AppPalette.shadow, radius: 24, x: 0, y: 16)
    }
}

private struct StatusPill: View {
    let status: HealthAccessStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
                .font(.caption)
            Text(status.shortTitle)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(status == .available ? AppPalette.ink : AppPalette.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(status == .available ? AppPalette.mint.opacity(0.82) : Color.orange.opacity(0.16))
        .clipShape(Capsule())
    }
}

private struct HeroMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(AppPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.66)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppPalette.muted)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.72))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppPalette.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SummaryGrid: View {
    @ObservedObject var store: FitnessStore

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SummaryTile(title: "Calories", value: store.totalCaloriesText, detail: "\(store.calorieProgressPercent)% of goal", icon: "flame.fill", tint: .red)
                SummaryTile(title: "Steps", value: store.steps.formatted(), detail: "\(store.stepProgressPercent)% of goal", icon: "shoeprints.fill", tint: .green)
            }

            HStack(spacing: 12) {
                SummaryTile(title: "Active", value: store.activeTimeText, detail: "\(store.activeProgressPercent)% of goal", icon: "timer", tint: .blue)
                SummaryTile(title: "Distance", value: store.distanceText, detail: "walk + run", icon: "map.fill", tint: .orange)
            }
        }
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(AppPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)

                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(AppPalette.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .background(AppPalette.tile)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppPalette.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: AppPalette.shadow, radius: 14, x: 0, y: 9)
    }
}

private struct DataSourcesCard: View {
    @ObservedObject var store: FitnessStore
    @ObservedObject var routeTracker: RouteTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Data sources")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)

                    Text("Automatic tracking readiness")
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                }

                Spacer()

                Text(store.dataReadinessText(locationStatus: routeTracker.locationAccessStatus))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppPalette.mint.opacity(0.55))
                    .clipShape(Capsule())
            }

            VStack(spacing: 10) {
                DataSourceRow(
                    title: "Apple Health",
                    detail: store.healthAccessStatus.message,
                    icon: store.healthAccessStatus.icon,
                    tint: store.healthAccessStatus.tint,
                    stateText: store.healthAccessStatus.shortTitle
                )

                DataSourceRow(
                    title: "Motion",
                    detail: store.motionAccessStatus.message,
                    icon: store.motionAccessStatus.icon,
                    tint: store.motionAccessStatus.tint,
                    stateText: store.motionAccessStatus.shortTitle
                )

                DataSourceRow(
                    title: "Location",
                    detail: routeTracker.locationAccessStatus.message,
                    icon: routeTracker.locationAccessStatus.icon,
                    tint: routeTracker.locationAccessStatus.tint,
                    stateText: routeTracker.locationAccessStatus.shortTitle
                )
            }
        }
        .padding(18)
        .sectionCard()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DataSourceRow: View {
    let title: String
    let detail: String
    let icon: String
    let tint: Color
    let stateText: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppPalette.muted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }

            Spacer()

            Text(stateText)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(tint.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct GoalProgressCard: View {
    @ObservedObject var store: FitnessStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily goal rings")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)

                    Text(store.goalInsightText)
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                }

                Spacer()

                Text(store.goalScoreText)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppPalette.mint.opacity(0.55))
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                GoalRing(title: "Move", value: store.totalCaloriesText, progress: store.calorieProgress, tint: .red)
                GoalRing(title: "Steps", value: store.steps.formatted(), progress: store.stepProgress, tint: .green)
                GoalRing(title: "Active", value: store.activeTimeText, progress: store.activeProgress, tint: .blue)
            }
        }
        .padding(18)
        .sectionCard()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct GoalRing: View {
    let title: String
    let value: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(AppPalette.border.opacity(0.7), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int((progress * 100).rounded()))%")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 74, height: 74)

            VStack(spacing: 2) {
                Text(value)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppPalette.muted)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ConsistencyCard: View {
    @ObservedObject var store: FitnessStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Consistency")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)

                    Text(store.consistencyInsightText)
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                }

                Spacer()

                Text(store.currentStreakText)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppPalette.mint.opacity(0.55))
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                HeroMetricLight(title: "Goal days", value: store.goalDaysText)
                HeroMetricLight(title: "Completion", value: store.completionRateText)
                HeroMetricLight(title: "Avg score", value: store.averageGoalScoreText)
            }

            HStack(spacing: 6) {
                ForEach(store.goalCompletionSummaries.suffix(14)) { day in
                    GoalDayPill(day: day)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .sectionCard()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct GoalDayPill: View {
    let day: GoalCompletionSummary

    var body: some View {
        VStack(spacing: 5) {
            Capsule()
                .fill(day.isTargetHit ? AppPalette.green : AppPalette.border)
                .frame(width: 16, height: 36)
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(day.isTargetHit ? AppPalette.green : Color.blue.opacity(0.42))
                        .frame(width: 16, height: max(5, 36 * day.score))
                }

            Text(day.shortDayText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppPalette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(day.shortDayText), \(day.scoreText), \(day.isTargetHit ? "goal hit" : "goal not hit")")
    }
}
