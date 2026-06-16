import SwiftUI

struct SplashView: View {
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

