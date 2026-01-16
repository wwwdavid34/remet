import SwiftUI

/// View shown when the free tier limit is reached
struct LimitReachedView: View {
    @Environment(\.dismiss) private var dismiss
    let onViewPlans: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.coral.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.3.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppColors.coral)
            }

            // Message
            VStack(spacing: 12) {
                Text("Free Limit Reached")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("You've saved \(SubscriptionLimits.freePeopleLimit) people - that's awesome! Upgrade to Premium for unlimited people and cloud sync.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            // Actions
            VStack(spacing: 12) {
                Button {
                    onViewPlans()
                } label: {
                    Text("View Premium Plans")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [AppColors.coral, AppColors.warmYellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button("Maybe Later") {
                    dismiss()
                }
                .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}

/// Sheet wrapper for limit reached
struct LimitReachedSheet: View {
    @State private var showPaywall = false

    var body: some View {
        LimitReachedView {
            showPaywall = true
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

#Preview {
    LimitReachedView(onViewPlans: { })
}
