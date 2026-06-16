import SwiftUI

struct ActivityDashboard: View {
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

