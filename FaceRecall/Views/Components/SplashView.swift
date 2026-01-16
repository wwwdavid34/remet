import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    @State private var showTagline = false

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

                // Tagline
                VStack(spacing: 8) {
                    Text("Never forget a face")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text("Remember everyone you meet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
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
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                showTagline = true
            }
        }
    }
}

#Preview {
    SplashView()
}
