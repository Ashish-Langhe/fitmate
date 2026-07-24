import SwiftUI

struct ActivityDashboard: View {
    @ObservedObject var store: FitnessStore

    private let trackedKinds: [ActivityKind] = [.walking, .running, .cycling, .jumpingJacks]
    private var summaries: [ActivitySummary] {
        trackedKinds.map { store.summary(for: $0) }
    }

    private var maxCalories: Double {
        max(summaries.map(\.calories).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Activity intelligence")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)

                    Text("Auto-classified burn by movement type")
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                }
                Spacer()

                Text(store.totalCaloriesText)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.78))
                    .clipShape(Capsule())
            }

            VStack(spacing: 10) {
                ForEach(summaries, id: \.kind) { summary in
                    ActivityDashboardRow(summary: summary, maxCalories: maxCalories)
                }
            }
        }
        .padding(18)
        .sectionCard()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ActivityDashboardRow: View {
    let summary: ActivitySummary
    let maxCalories: Double

    private var progress: Double {
        FitnessMath.progress(current: summary.calories, target: maxCalories)
    }

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(summary.kind.tint.opacity(0.14))
                    .frame(width: 44, height: 44)

                Image(systemName: summary.kind.icon)
                    .font(.headline)
                    .foregroundStyle(summary.kind.tint)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.kind.dashboardTitle)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppPalette.ink)

                        Text(summary.detailText)
                            .font(.caption)
                            .foregroundStyle(AppPalette.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(summary.caloriesText)
                            .font(.headline.bold().monospacedDigit())
                            .foregroundStyle(AppPalette.ink)

                        Text(summary.sessionCountText)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(summary.kind.tint)
                    }
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppPalette.border.opacity(0.58))

                        Capsule()
                            .fill(summary.kind.tint)
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(Color.white.opacity(0.76))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(summary.kind.tint.opacity(0.16), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
