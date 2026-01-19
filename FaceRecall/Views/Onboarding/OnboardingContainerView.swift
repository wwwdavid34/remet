import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep = 0
    @State private var createdMeProfile: Person?

    var body: some View {
        ZStack {
            switch currentStep {
            case 0:
                OnboardingWelcomeView(onContinue: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = 1
                    }
                })
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            case 1:
                OnboardingProfileView(
                    onComplete: { person in
                        createdMeProfile = person
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = 2
                        }
                    },
                    onSkip: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = 2
                        }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            case 2:
                OnboardingFirstMemoryView(
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
                OnboardingCompleteView(onFinish: completeOnboarding)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            default:
                EmptyView()
            }
        }
        .interactiveDismissDisabled()
    }

    private func completeOnboarding() {
        AppSettings.shared.hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingContainerView()
}
