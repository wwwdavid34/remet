import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep = 0
    @State private var createdMeProfile: Person?

    var body: some View {
        TabView(selection: $currentStep) {
            OnboardingWelcomeView(onContinue: { currentStep = 1 })
                .tag(0)

            OnboardingProfileView(
                onComplete: { person in
                    createdMeProfile = person
                    currentStep = 2
                },
                onSkip: { currentStep = 2 }
            )
            .tag(1)

            OnboardingFirstMemoryView(
                onComplete: { currentStep = 3 },
                onSkip: { currentStep = 3 }
            )
            .tag(2)

            OnboardingCompleteView(onFinish: completeOnboarding)
                .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut, value: currentStep)
        .interactiveDismissDisabled()
        .gesture(DragGesture()) // Disable swipe navigation
    }

    private func completeOnboarding() {
        AppSettings.shared.hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingContainerView()
}
