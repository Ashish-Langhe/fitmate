import SwiftUI
import Combine

#if os(iOS)
import CoreMotion
import HealthKit
import MapKit
import CoreLocation
#endif

struct RouteTrackingCard: View {
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

