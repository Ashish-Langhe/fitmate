import SwiftUI
import Charts

struct CyclingDashboardCard: View {
    @ObservedObject var routeTracker: RouteTracker
    @State private var selectedRide: RouteSession?

    private var cyclingRoutes: [RouteSession] {
        routeTracker.savedRoutes.filter { $0.kind == .cycling }
    }

    private var isCyclingActive: Bool {
        routeTracker.isTracking && routeTracker.selectedKind == .cycling
    }

    private var graphSamples: [RideMetricSample] {
        if isCyclingActive, !routeTracker.rideSamples.isEmpty {
            return routeTracker.rideSamples
        }
        return cyclingRoutes.first?.samples ?? Self.previewBurnSamples
    }

    private var graphSubtitle: String {
        if isCyclingActive {
            return "Live ride samples"
        }
        if cyclingRoutes.first != nil {
            return "Latest ride samples"
        }
        return "Sample burn curve until your first ride"
    }

    private static var previewBurnSamples: [RideMetricSample] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sixThirty = calendar.date(bySettingHour: 6, minute: 30, second: 0, of: today) ?? today
        let seven = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: today) ?? today.addingTimeInterval(1_800)
        let sevenThirty = calendar.date(bySettingHour: 7, minute: 30, second: 0, of: today) ?? today.addingTimeInterval(3_600)

        return [
            RideMetricSample(timestamp: sixThirty, elapsedTime: 0, distanceInMeters: 1_900, calories: 50, speedKilometersPerHour: 12.4),
            RideMetricSample(timestamp: seven, elapsedTime: 1_800, distanceInMeters: 7_800, calories: 120, speedKilometersPerHour: 21.2),
            RideMetricSample(timestamp: sevenThirty, elapsedTime: 3_600, distanceInMeters: 13_600, calories: 188, speedKilometersPerHour: 18.6)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppPalette.blue.opacity(0.14))
                        .frame(width: 52, height: 52)

                    Image(systemName: "bicycle")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppPalette.blue)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Cycling Studio")
                        .font(.title3.bold())
                        .foregroundStyle(AppPalette.ink)

                    Text(isCyclingActive ? "Live GPS ride in progress" : "Start a ride to capture speed, path, breaks, and burn")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    routeTracker.toggleCyclingRide()
                } label: {
                    Label(isCyclingActive ? "End ride" : "Start ride", systemImage: isCyclingActive ? "stop.fill" : "bicycle")
                        .font(.caption.weight(.bold))
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)
                .tint(isCyclingActive ? .red : AppPalette.green)
                .disabled(routeTracker.isTracking && routeTracker.selectedKind != .cycling)
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

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                CyclingMetricTile(title: "Speed", value: routeTracker.currentSpeedText, icon: "speedometer", tint: AppPalette.blue)
                CyclingMetricTile(title: "Average", value: routeTracker.averageSpeedText, icon: "gauge.medium", tint: AppPalette.green)
                CyclingMetricTile(title: "Duration", value: routeTracker.durationText, icon: "timer", tint: AppPalette.orange)
                CyclingMetricTile(title: "Distance", value: routeTracker.distanceText, icon: "map.fill", tint: AppPalette.purple)
                CyclingMetricTile(title: "Calories", value: routeTracker.caloriesText, icon: "flame.fill", tint: .red)
                CyclingMetricTile(title: "Pedal steps", value: routeTracker.cyclingStepCountText, icon: "bicycle", tint: .cyan)
            }

            HStack(spacing: 10) {
                CyclingCompactMetric(title: "Start", value: routeTracker.startTimeText)
                CyclingCompactMetric(title: "Max", value: routeTracker.maxSpeedText)
                CyclingCompactMetric(title: "Breaks", value: routeTracker.breakCountText)
                CyclingCompactMetric(title: "Break time", value: routeTracker.breakDurationText)
            }

            CyclingBurnChart(
                title: "Calorie burn timeline",
                subtitle: graphSubtitle,
                samples: graphSamples
            )

            if cyclingRoutes.isEmpty {
                Text("Finished rides will show start time, end time, path, duration, speed, breaks, calories, and pedal-step estimate.")
                    .font(.caption)
                    .foregroundStyle(AppPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent rides")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.ink)

                    ForEach(cyclingRoutes.prefix(3)) { ride in
                        CyclingRideRow(ride: ride) {
                            selectedRide = ride
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.96), AppPalette.blue.opacity(0.08), AppPalette.mint.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppPalette.blue.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: AppPalette.shadow, radius: 18, x: 0, y: 12)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .sheet(item: $selectedRide) { ride in
            CyclingRideDetailView(ride: ride)
                .presentationDetents([.medium, .large])
        }
    }
}

private struct CyclingMetricTile: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)

            Text(value)
                .font(.headline.bold().monospacedDigit())
                .foregroundStyle(AppPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppPalette.muted)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
        .background(Color.white.opacity(0.76))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CyclingCompactMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(AppPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppPalette.muted)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CyclingRideRow: View {
    let ride: RouteSession
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "bicycle")
                    .font(.headline)
                    .foregroundStyle(AppPalette.blue)
                    .frame(width: 42, height: 42)
                    .background(AppPalette.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(ride.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.ink)

                    Text("\(ride.startTimeText)-\(ride.endTimeText) • \(ride.distanceText) • \(ride.averageSpeedText)")
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer()

                Text(ride.caloriesText)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(AppPalette.ink)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.muted)
            }
            .padding(12)
            .background(Color.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct CyclingRideDetailView: View {
    let ride: RouteSession

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SavedRouteMapView(route: ride)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Cycling ride")
                            .font(.title3.bold())
                            .foregroundStyle(AppPalette.ink)

                        Text("\(ride.date.formatted(date: .complete, time: .omitted)) • \(ride.startTimeText)-\(ride.endTimeText)")
                            .font(.caption)
                            .foregroundStyle(AppPalette.muted)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        CyclingMetricTile(title: "Distance", value: ride.distanceText, icon: "map.fill", tint: AppPalette.purple)
                        CyclingMetricTile(title: "Duration", value: ride.durationText, icon: "timer", tint: AppPalette.orange)
                        CyclingMetricTile(title: "Avg speed", value: ride.averageSpeedText, icon: "gauge.medium", tint: AppPalette.green)
                        CyclingMetricTile(title: "Max speed", value: ride.maxSpeedText, icon: "speedometer", tint: AppPalette.blue)
                        CyclingMetricTile(title: "Calories", value: ride.caloriesText, icon: "flame.fill", tint: .red)
                        CyclingMetricTile(title: "Pedal steps", value: ride.cyclingStepCountText, icon: "bicycle", tint: .cyan)
                        CyclingMetricTile(title: "Breaks", value: ride.breakCountText, icon: "pause.fill", tint: AppPalette.muted)
                        CyclingMetricTile(title: "Break time", value: ride.breakDurationText, icon: "clock.fill", tint: AppPalette.ink)
                    }

                    CyclingBurnChart(
                        title: "Calories over time",
                        subtitle: "Burn progression by clock time",
                        samples: ride.samples
                    )
                }
                .padding(20)
            }
            .background(DashboardBackground())
            .navigationTitle("Ride detail")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct CyclingBurnChart: View {
    let title: String
    let subtitle: String
    let samples: [RideMetricSample]

    private var lastSampleText: String {
        guard let sample = samples.last else { return "--" }
        return "\(sample.timeText) • \(sample.caloriesText)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.ink)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                }

                Spacer()

                Text(lastSampleText)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.76))
                    .clipShape(Capsule())
            }

            if samples.count > 1 {
                Chart(samples) { sample in
                    AreaMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Calories", sample.calories)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppPalette.orange.opacity(0.36), AppPalette.orange.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Calories", sample.calories)
                    )
                    .foregroundStyle(AppPalette.orange)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Calories", sample.calories)
                    )
                    .foregroundStyle(AppPalette.orange)
                    .symbolSize(24)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                            .foregroundStyle(AppPalette.border.opacity(0.5))
                        AxisValueLabel(format: .dateTime.hour().minute())
                            .font(.caption2)
                            .foregroundStyle(AppPalette.muted)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                            .foregroundStyle(AppPalette.border.opacity(0.5))
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(AppPalette.muted)
                    }
                }
                .frame(height: 190)
                .padding(.top, 2)

                HStack(spacing: 8) {
                    ForEach(samples.suffix(3)) { sample in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sample.timeText)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppPalette.muted)

                            Text(sample.caloriesText)
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(AppPalette.ink)
                        }
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.62))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3)
                        .foregroundStyle(AppPalette.orange)

                    Text("Start a cycling ride to build a burn graph with time-stamped calorie points.")
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
                .background(Color.white.opacity(0.62))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppPalette.orange.opacity(0.16), lineWidth: 1)
        }
    }
}
