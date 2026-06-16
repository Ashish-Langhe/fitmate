import SwiftUI

struct AnalyticsInsightsCard: View {
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

struct RangeActivityBreakdownCard: View {
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

