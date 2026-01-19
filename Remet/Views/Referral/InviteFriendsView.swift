import SwiftUI

struct InviteFriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var referralManager = ReferralManager.shared
    @State private var showShareSheet = false
    @State private var copiedCode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header illustration
                    headerSection

                    // Referral code card
                    referralCodeCard

                    // How it works
                    howItWorksSection

                    // Stats
                    if referralManager.referralCount > 0 || referralManager.hasCredit {
                        statsSection
                    }

                    // Credit history
                    if !referralManager.credit.creditHistory.isEmpty {
                        historySection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "Invite Friends"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [referralManager.shareMessage()])
            }
            .task {
                await referralManager.syncCredits()
            }
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.coral.opacity(0.2), AppColors.teal.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "gift.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppColors.coral)
            }

            Text(String(localized: "Help Friends Remember Faces"))
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(String(localized: "Get $0.50 credit for each friend who upgrades to Premium"))
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }

    @ViewBuilder
    private var referralCodeCard: some View {
        VStack(spacing: 16) {
            Text(String(localized: "Your Referral Code"))
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 12) {
                Text(referralManager.referralCode)
                    .font(.title2)
                    .fontWeight(.bold)
                    .fontDesign(.monospaced)
                    .foregroundStyle(AppColors.coral)

                Button {
                    UIPasteboard.general.string = referralManager.referralCode
                    copiedCode = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copiedCode = false
                    }
                } label: {
                    Image(systemName: copiedCode ? "checkmark" : "doc.on.doc")
                        .font(.body)
                        .foregroundStyle(copiedCode ? AppColors.success : AppColors.teal)
                }
            }

            if copiedCode {
                Text(String(localized: "Copied!"))
                    .font(.caption)
                    .foregroundStyle(AppColors.success)
            }

            Button {
                showShareSheet = true
            } label: {
                Label(String(localized: "Share Invite"), systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.coral)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "How It Works"))
                .font(.headline)

            VStack(spacing: 12) {
                HowItWorksRow(
                    number: "1",
                    icon: "square.and.arrow.up",
                    title: String(localized: "Share your code"),
                    subtitle: String(localized: "Send to friends who'd benefit")
                )

                HowItWorksRow(
                    number: "2",
                    icon: "person.badge.plus",
                    title: String(localized: "Friend joins"),
                    subtitle: String(localized: "They enter your code in the app")
                )

                HowItWorksRow(
                    number: "3",
                    icon: "crown",
                    title: String(localized: "Friend upgrades"),
                    subtitle: String(localized: "When they subscribe to Premium")
                )

                HowItWorksRow(
                    number: "4",
                    icon: "dollarsign.circle",
                    title: String(localized: "You both earn"),
                    subtitle: String(localized: "$0.50 credit for each of you")
                )
            }
        }
        .padding(20)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Your Referral Stats"))
                .font(.headline)

            HStack(spacing: 20) {
                StatBox(
                    value: "\(referralManager.referralCount)",
                    label: String(localized: "Friends Referred"),
                    icon: "person.2.fill",
                    color: AppColors.teal
                )

                StatBox(
                    value: referralManager.formattedBalance,
                    label: String(localized: "Credit Balance"),
                    icon: "dollarsign.circle.fill",
                    color: AppColors.coral
                )
            }
        }
        .padding(20)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Credit History"))
                .font(.headline)

            ForEach(referralManager.credit.creditHistory.suffix(5).reversed()) { transaction in
                HStack {
                    Image(systemName: transaction.type.icon)
                        .foregroundStyle(transaction.amount > 0 ? AppColors.success : AppColors.textMuted)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(transaction.description)
                            .font(.subheadline)
                        Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(AppColors.textMuted)
                    }

                    Spacer()

                    Text(transaction.amount > 0 ? "+\(formatCurrency(transaction.amount))" : formatCurrency(transaction.amount))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(transaction.amount > 0 ? AppColors.success : AppColors.textMuted)
                }
                .padding(.vertical, 8)

                if transaction.id != referralManager.credit.creditHistory.last?.id {
                    Divider()
                }
            }
        }
        .padding(20)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$\(amount)"
    }
}

// MARK: - Supporting Views

struct HowItWorksRow: View {
    let number: String
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.coral.opacity(0.15))
                    .frame(width: 36, height: 36)

                Text(number)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.coral)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(AppColors.teal)
        }
    }
}

struct StatBox: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - CreditType Extension

extension CreditType {
    var icon: String {
        switch self {
        case .referralBonus: return "person.badge.plus"
        case .referredBonus: return "gift"
        case .promoBonus: return "tag"
        case .redeemed: return "checkmark.circle"
        case .expired: return "clock"
        }
    }
}

#Preview {
    InviteFriendsView()
}
