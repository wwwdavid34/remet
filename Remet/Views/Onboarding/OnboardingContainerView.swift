import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep = 0
    @State private var createdMeProfile: Person?
    @State private var showSkipProfileAlert = false

    /// Total onboarding steps (Welcome, Profile, LiveScan, Memory, Complete)
    private let totalSteps = 5

    var body: some View {
        ZStack {
            switch currentStep {
            case 0:
                OnboardingWelcomeView(
                    currentStep: currentStep,
                    totalSteps: totalSteps,
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = 1
                        }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            case 1:
                OnboardingProfileView(
                    currentStep: currentStep,
                    totalSteps: totalSteps,
                    onComplete: { person in
                        createdMeProfile = person
                        withAnimation(.easeInOut(duration: 0.3)) {
                            // Go to live scan if profile was created
                            currentStep = 2
                        }
                    },
                    onSkip: {
                        showSkipProfileAlert = true
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            case 2:
                // Live Scan demo - only shown if profile was created
                OnboardingLiveScanView(
                    currentStep: currentStep,
                    totalSteps: totalSteps,
                    onComplete: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = 3
                        }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = 3
                        }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            case 3:
                OnboardingFirstMemoryView(
                    currentStep: currentStep,
                    totalSteps: totalSteps,
                    onComplete: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = 4
                        }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = 4
                        }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            case 4:
                OnboardingCompleteView(
                    currentStep: currentStep,
                    totalSteps: totalSteps,
                    onFinish: completeOnboarding
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            default:
                EmptyView()
            }
        }
        .interactiveDismissDisabled()
        .alert(String(localized: "Profile Skipped"), isPresented: $showSkipProfileAlert) {
            Button(String(localized: "OK")) { }
        } message: {
            Text(String(localized: "You can create your profile later from Account settings."))
        }
        .onChange(of: showSkipProfileAlert) { _, isPresented in
            if !isPresented && currentStep == 1 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = 3
                }
            }
        }
    }

    private func completeOnboarding() {
        AppSettings.shared.hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingContainerView()
}
