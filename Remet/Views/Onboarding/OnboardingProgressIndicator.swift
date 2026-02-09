import SwiftUI

/// Progress indicator showing step dots for onboarding flow
struct OnboardingProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? AppColors.coral : AppColors.coral.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(step == currentStep ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Step \(currentStep + 1) of \(totalSteps)"))
    }
}

#Preview {
    VStack(spacing: 20) {
        OnboardingProgressIndicator(currentStep: 0, totalSteps: 5)
        OnboardingProgressIndicator(currentStep: 2, totalSteps: 5)
        OnboardingProgressIndicator(currentStep: 4, totalSteps: 5)
    }
    .padding()
}
