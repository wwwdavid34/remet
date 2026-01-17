import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    @State private var showTagline = false
    @State private var currentTaglineIndex = 0

    private let taglines = ["remember", "refresh", "remet"]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    AppColors.coral.opacity(0.1),
                    AppColors.teal.opacity(0.05),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // App icon/logo
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppColors.coral.opacity(0.3), AppColors.coral.opacity(0)],
                                center: .center,
                                startRadius: 40,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)

                    // Main circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.coral, AppColors.coral.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: AppColors.coral.opacity(0.4), radius: 20, x: 0, y: 10)

                    // Icon
                    Image(systemName: "face.smiling.inverse")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(.white)
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                }

                // App name
                Text("Remet")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.coral)

                // Rolling tagline
                Text(taglines[currentTaglineIndex])
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.textSecondary)
                    .contentTransition(.numericText())
                    .opacity(showTagline ? 1 : 0)
                    .offset(y: showTagline ? 0 : 10)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                showTagline = true
            }
            // Start rolling taglines
            startTaglineRotation()
        }
    }

    private func startTaglineRotation() {
        // Cycle every 0.5s to fit all 3 words within 1.8s splash duration
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                currentTaglineIndex = (currentTaglineIndex + 1) % taglines.count
            }
        }
    }
}

#Preview {
    SplashView()
}
