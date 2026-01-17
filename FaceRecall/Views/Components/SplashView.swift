import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    @State private var visibleTaglineCount = 0

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

                // Stacked taglines appearing one by one
                VStack(spacing: 4) {
                    ForEach(Array(taglines.enumerated()), id: \.offset) { index, tagline in
                        Text(tagline)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundStyle(AppColors.textSecondary)
                            .opacity(index < visibleTaglineCount ? 1 : 0)
                            .offset(y: index < visibleTaglineCount ? 0 : 10)
                    }
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
            // Show taglines one by one
            startTaglineSequence()
        }
    }

    private func startTaglineSequence() {
        // Show each tagline with 0.5s delay, fitting within 1.8s splash
        for index in 0..<taglines.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Double(index) * 0.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    visibleTaglineCount = index + 1
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
