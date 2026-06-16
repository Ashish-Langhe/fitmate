import SwiftUI

struct LogoMark: View {
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


struct HeroMetricLight: View {
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

enum AppPalette {
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

extension View {
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
