import SwiftUI

struct OnboardingCompleteView: View {
    let currentStep: Int
    let totalSteps: Int
    let onFinish: () -> Void

    @State private var showCheckmark = false
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 40) {
            // Progress indicator (completed state)
            OnboardingProgressIndicator(currentStep: currentStep, totalSteps: totalSteps)
                .padding(.top, 16)

            Spacer()

            // Success animation
            ZStack {
                Circle()
                    .fill(AppColors.teal.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(AppColors.teal)
                    .scaleEffect(showCheckmark ? 1.0 : 0.3)
                    .opacity(showCheckmark ? 1.0 : 0.0)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showCheckmark)

            // Content
            VStack(spacing: 16) {
                Text(String(localized: "You're All Set!"))
                    .font(.title)
                    .fontWeight(.bold)

                Text(String(localized: "Your memory palace is ready. Here are some quick tips:"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 20)
            .animation(.easeOut(duration: 0.4).delay(0.3), value: showContent)

            // Tips
            VStack(alignment: .leading, spacing: 16) {
                tipRow(
                    icon: "viewfinder",
                    title: String(localized: "Memory Scan"),
                    description: String(localized: "Instantly identify anyone - just point your camera!")
                )

                tipRow(
                    icon: "camera.fill",
                    title: String(localized: "Quick Capture"),
                    description: String(localized: "Tap the camera to add new faces you meet")
                )

                tipRow(
                    icon: "brain.head.profile",
                    title: String(localized: "Practice"),
                    description: String(localized: "Quiz yourself to strengthen your memory")
                )
            }
            .padding(.horizontal, 32)
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 20)
            .animation(.easeOut(duration: 0.4).delay(0.5), value: showContent)

            Spacer()

            // Get started button
            Button(action: onFinish) {
                Text(String(localized: "Start Using Remet"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.coral)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.4).delay(0.7), value: showContent)
        }
        .background(AppColors.background)
        .onAppear {
            withAnimation {
                showCheckmark = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showContent = true
            }
        }
    }

    @ViewBuilder
    private func tipRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppColors.coral)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    OnboardingCompleteView(currentStep: 4, totalSteps: 5, onFinish: {})
}
