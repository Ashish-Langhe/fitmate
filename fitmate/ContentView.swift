//
//  ContentView.swift
//  fitmate
//
//  Created by Ashish Langhe on 14/06/26.
//

import SwiftUI
import Combine

#if os(iOS)
import CoreMotion
import HealthKit
import MapKit
import CoreLocation
#endif

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var fitnessStore = FitnessStore()
    @StateObject private var routeTracker = RouteTracker()
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            DashboardView(store: fitnessStore, routeTracker: routeTracker)
                .opacity(isShowingSplash ? 0 : 1)

            if isShowingSplash {
                SplashView()
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
                    .zIndex(1)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            fitnessStore.refreshToday()
        }
        .task {
            fitnessStore.start()
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeInOut(duration: 0.45)) {
                isShowingSplash = false
            }
        }
    }
}

private struct SplashView: View {
    @State private var pulse = false
    @State private var orbit = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.10, blue: 0.09), Color(red: 0.02, green: 0.18, blue: 0.14), Color(red: 0.06, green: 0.12, blue: 0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.15), lineWidth: 14)
                        .frame(width: 132, height: 132)

                    Circle()
                        .trim(from: 0.05, to: 0.78)
                        .stroke(
                            AngularGradient(colors: [.mint, .green, .cyan, .mint], center: .center),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .frame(width: 132, height: 132)
                        .rotationEffect(.degrees(orbit ? 360 : 0))

                    Image(systemName: "figure.run")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(pulse ? 1.08 : 0.96)
                }

                VStack(spacing: 10) {
                    Text("FitMate")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Your Personal Fitness Companion")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(28)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                orbit = true
            }
        }
    }
}

private struct DashboardView: View {
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

private enum DashboardSection: String, CaseIterable, Identifiable {
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

private struct DashboardSectionPicker: View {
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

private struct DashboardBackground: View {
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

private struct ActivityDashboard: View {
    @ObservedObject var store: FitnessStore

    private let trackedKinds: [ActivityKind] = [.walking, .running, .cycling, .jumpingJacks]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Activity dashboards")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)

                    Text("Auto-detected calories by movement type")
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                }
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(trackedKinds) { kind in
                    ActivityDashboardTile(kind: kind, summary: store.summary(for: kind))
                }
            }
        }
        .padding(18)
        .sectionCard()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ActivityDashboardTile: View {
    let kind: ActivityKind
    let summary: ActivitySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle()
                        .fill(kind.tint.opacity(0.16))
                        .frame(width: 38, height: 38)

                    Image(systemName: kind.icon)
                        .font(.headline)
                        .foregroundStyle(kind.tint)
                }

                Spacer()

                Text(summary.sessionCountText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(kind.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(kind.tint.opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(kind.dashboardTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.ink)

                Text(summary.caloriesText)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(AppPalette.ink)

                Text(summary.detailText)
                    .font(.caption)
                    .foregroundStyle(AppPalette.muted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
        .background(Color.white.opacity(0.82))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(kind.tint.opacity(0.18), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HistoryDashboard: View {
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

private struct AnalyticsInsightsCard: View {
    @ObservedObject var store: FitnessStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Analytics")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)

                    Text(store.analyticsSubtitle)
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                }

                Spacer()

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                    .foregroundStyle(.blue)
            }

            HStack(spacing: 10) {
                HeroMetricLight(title: "Avg steps", value: store.averageStepsText)
                HeroMetricLight(title: "Avg burn", value: store.averageCaloriesText)
                HeroMetricLight(title: "Best day", value: store.bestDayText)
            }

            Text(store.coachingInsightText)
                .font(.subheadline)
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppPalette.mint.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(18)
        .sectionCard()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct RangeActivityBreakdownCard: View {
    @ObservedObject var store: FitnessStore
    @ObservedObject var routeTracker: RouteTracker

    var body: some View {
        let summaries = store.rangeActivitySummaries(routeSessions: routeTracker.savedRoutes)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Range activity burn")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)

                    Text("Calories by activity across \(store.selectedRange.title)")
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                }

                Spacer()

                Text(store.rangeActivityTotalText(routeSessions: routeTracker.savedRoutes))
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.82))
                    .clipShape(Capsule())
            }

            if summaries.allSatisfy({ $0.calories == 0 }) {
                Text("FitMate will separate walking, running, cycling, and jumping-jack burn as Health history syncs.")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 11) {
                    ForEach(summaries) { summary in
                        RangeActivityRow(summary: summary)
                    }
                }
            }
        }
        .padding(18)
        .sectionCard()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct RangeActivityRow: View {
    let summary: ActivityRangeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Image(systemName: summary.kind.icon)
                    .font(.subheadline)
                    .foregroundStyle(summary.kind.tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.kind.dashboardTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text(summary.detailText)
                        .font(.caption2)
                        .foregroundStyle(AppPalette.muted)
                }

                Spacer()

                Text(summary.caloriesText)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(AppPalette.ink)
            }

            ProgressView(value: summary.progress)
                .tint(summary.kind.tint)
        }
        .padding(12)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct RouteTrackingCard: View {
    @ObservedObject var routeTracker: RouteTracker
    @State private var selectedRoute: RouteSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Route tracking")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)

                    Text("Track walks, runs, and rides with path map")
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                }

                Spacer()

                Button {
                    routeTracker.toggleTracking()
                } label: {
                    Label(routeTracker.isTracking ? "Stop" : "Start", systemImage: routeTracker.isTracking ? "stop.fill" : "location.fill")
                        .labelStyle(.iconOnly)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.borderedProminent)
                .tint(routeTracker.isTracking ? .red : .green)
            }

            RouteMapView(routeTracker: routeTracker)
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if routeTracker.locationAccessStatus == .denied || routeTracker.locationAccessStatus == .unavailable {
                Label(routeTracker.locationAccessStatus.message, systemImage: routeTracker.locationAccessStatus.icon)
                    .font(.caption)
                    .foregroundStyle(routeTracker.locationAccessStatus.tint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(routeTracker.locationAccessStatus.tint.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Picker("Route type", selection: Binding(
                get: { routeTracker.selectedKind },
                set: { routeTracker.selectKind($0) }
            )) {
                ForEach(ActivityKind.routeKinds) { kind in
                    Text(kind.routeTitle).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .disabled(routeTracker.isTracking)

            HStack(spacing: 10) {
                HeroMetricLight(title: "Distance", value: routeTracker.distanceText)
                HeroMetricLight(title: "Duration", value: routeTracker.durationText)
                HeroMetricLight(title: "Calories", value: routeTracker.caloriesText)
            }

            if routeTracker.savedRoutes.isEmpty {
                Text("Completed route sessions will appear here with distance, time, path points, and calorie burn.")
                    .font(.caption)
                    .foregroundStyle(AppPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent routes")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.ink)

                    ForEach(routeTracker.savedRoutes.prefix(3)) { route in
                        RouteSessionRow(route: route) {
                            selectedRoute = route
                        }
                    }
                }
            }
        }
        .padding(18)
        .sectionCard()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .sheet(item: $selectedRoute) { route in
            RouteSessionDetailView(route: route)
                .presentationDetents([.medium, .large])
        }
    }
}

private struct RouteSessionRow: View {
    let route: RouteSession
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(route.kind.tint.opacity(0.12))

                    Image(systemName: route.kind.icon)
                        .font(.headline)
                        .foregroundStyle(route.kind.tint)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(route.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text("\(route.kind.dashboardTitle) • \(route.distanceText) • \(route.durationText)")
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer()

                Text(route.caloriesText)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.82))
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.muted)
            }
        }
        .buttonStyle(.plain)
        .padding(10)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct RouteSessionDetailView: View {
    let route: RouteSession

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SavedRouteMapView(route: route)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: route.kind.icon)
                                .font(.title3)
                                .foregroundStyle(route.kind.tint)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(route.kind.dashboardTitle)
                                    .font(.headline)
                                    .foregroundStyle(AppPalette.ink)

                                Text(route.date.formatted(date: .complete, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(AppPalette.muted)
                            }
                        }

                        Text("Saved path with \(route.pointCountText).")
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.muted)
                    }

                    HStack(spacing: 10) {
                        HeroMetricLight(title: "Distance", value: route.distanceText)
                        HeroMetricLight(title: "Duration", value: route.durationText)
                        HeroMetricLight(title: "Calories", value: route.caloriesText)
                    }
                }
                .padding(20)
            }
            .background(DashboardBackground())
            .navigationTitle("Route detail")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct HeroMetricLight: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(AppPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppPalette.muted)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#if os(iOS)
private struct RouteMapView: View {
    @ObservedObject var routeTracker: RouteTracker

    var body: some View {
        Map(position: .constant(routeTracker.cameraPosition)) {
            UserAnnotation()
            if routeTracker.routeCoordinates.count > 1 {
                MapPolyline(coordinates: routeTracker.routeCoordinates)
                    .stroke(.green, lineWidth: 5)
            }
        }
        .mapControls {
            MapUserLocationButton()
        }
    }
}

private struct SavedRouteMapView: View {
    let route: RouteSession

    var body: some View {
        Map(position: .constant(route.cameraPosition)) {
            if route.coordinates.count > 1 {
                MapPolyline(coordinates: route.coordinates)
                    .stroke(route.kind.tint, lineWidth: 5)
            }
        }
        .mapControls {
            MapScaleView()
        }
    }
}
#else
private struct RouteMapView: View {
    @ObservedObject var routeTracker: RouteTracker

    var body: some View {
        ZStack {
            AppPalette.border.opacity(0.35)
            Text("Route map runs on iPhone")
                .font(.subheadline)
                .foregroundStyle(AppPalette.muted)
        }
    }
}

private struct SavedRouteMapView: View {
    let route: RouteSession

    var body: some View {
        ZStack {
            AppPalette.border.opacity(0.35)
            Text("Saved route map runs on iPhone")
                .font(.subheadline)
                .foregroundStyle(AppPalette.muted)
        }
    }
}
#endif

private struct GoalSettingsCard: View {
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

private struct AutoTrackingCard: View {
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

private struct CalorieBreakdown: View {
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

private struct ActivityTimeline: View {
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

private struct LogoMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(LinearGradient(colors: [.green, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))

            Image(systemName: "bolt.heart.fill")
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: .green.opacity(0.25), radius: 12, x: 0, y: 7)
    }
}

@MainActor
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

private enum AppPalette {
    static let pageTop = Color(red: 0.96, green: 0.99, blue: 0.97)
    static let page = Color(red: 0.93, green: 0.97, blue: 0.95)
    static let pageBottom = Color(red: 0.91, green: 0.95, blue: 0.98)
    static let card = Color.white.opacity(0.88)
    static let tile = Color.white.opacity(0.92)
    static let ink = Color(red: 0.07, green: 0.11, blue: 0.13)
    static let muted = Color(red: 0.40, green: 0.47, blue: 0.50)
    static let border = Color(red: 0.82, green: 0.88, blue: 0.86)
    static let shadow = Color(red: 0.10, green: 0.18, blue: 0.16).opacity(0.12)
    static let green = Color(red: 0.00, green: 0.55, blue: 0.33)
    static let mint = Color(red: 0.43, green: 0.96, blue: 0.69)
}

private extension View {
    func sectionCard() -> some View {
        self
            .background(AppPalette.card)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppPalette.border, lineWidth: 1)
            }
            .shadow(color: AppPalette.shadow, radius: 16, x: 0, y: 10)
    }
}

#Preview {
    ContentView()
}
