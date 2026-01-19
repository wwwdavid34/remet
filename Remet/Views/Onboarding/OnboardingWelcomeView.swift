import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // App icon/logo area
            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppColors.coral)

                Text("Remet")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
            }

            // Tagline
            VStack(spacing: 12) {
                Text(String(localized: "Remember every face,\nevery name"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text(String(localized: "Remet helps you build and maintain meaningful connections by remembering the people you meet."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Get started button
            Button(action: onContinue) {
                Text(String(localized: "Get Started"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.coral)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(AppColors.background)
    }
}

#Preview {
    OnboardingWelcomeView(onContinue: {})
}
