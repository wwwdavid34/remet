import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    premiumHero
                    featuresSection
                    productOptions
                    legalSection
                }
                .padding()
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await subscriptionManager.loadProducts()
                // Pre-select yearly as default
                selectedProduct = subscriptionManager.yearlyProduct
            }
            .alert("Purchase Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(subscriptionManager.purchaseError ?? "An error occurred.")
            }
        }
    }

    // MARK: - Hero Section

    @ViewBuilder
    private var premiumHero: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.coral.opacity(0.2), AppColors.warmYellow.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "crown.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.coral, AppColors.warmYellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Upgrade to Premium")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Unlock unlimited people, cloud sync, and more")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Features Section

    @ViewBuilder
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaywallFeatureRow(
                icon: "infinity",
                title: "Unlimited People",
                description: "No limits on how many people you can save"
            )

            PaywallFeatureRow(
                icon: "icloud",
                title: "Cloud Sync",
                description: "Access your data across all your devices"
            )

            PaywallFeatureRow(
                icon: "tag",
                title: "Unlimited Tags",
                description: "Organize without restrictions"
            )

            PaywallFeatureRow(
                icon: "chart.bar",
                title: "Advanced Analytics",
                description: "Track your memory improvement over time"
            )
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Product Options

    @ViewBuilder
    private var productOptions: some View {
        VStack(spacing: 12) {
            if subscriptionManager.isLoading && subscriptionManager.products.isEmpty {
                ProgressView()
                    .padding()
            } else if subscriptionManager.products.isEmpty {
                Text("Unable to load subscription options")
                    .foregroundStyle(AppColors.textSecondary)
                    .padding()

                Button("Retry") {
                    Task { await subscriptionManager.loadProducts() }
                }
                .buttonStyle(.bordered)
            } else {
                // Yearly option (recommended)
                if let yearly = subscriptionManager.yearlyProduct {
                    ProductOptionCard(
                        product: yearly,
                        isSelected: selectedProduct?.id == yearly.id,
                        badge: "Save \(subscriptionManager.yearlySavingsPercent)%",
                        onSelect: { selectedProduct = yearly }
                    )
                }

                // Monthly option
                if let monthly = subscriptionManager.monthlyProduct {
                    ProductOptionCard(
                        product: monthly,
                        isSelected: selectedProduct?.id == monthly.id,
                        badge: nil,
                        onSelect: { selectedProduct = monthly }
                    )
                }

                // Subscribe button
                Button {
                    Task { await purchase() }
                } label: {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Subscribe Now")
                        }
                    }
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
                .disabled(selectedProduct == nil || isPurchasing)
                .padding(.top, 8)

                // Restore purchases
                Button("Restore Purchases") {
                    Task { await subscriptionManager.restorePurchases() }
                }
                .font(.subheadline)
                .foregroundStyle(AppColors.teal)
            }
        }
    }

    // MARK: - Legal Section

    @ViewBuilder
    private var legalSection: some View {
        VStack(spacing: 8) {
            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundStyle(AppColors.textMuted)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Terms of Service") {
                    // TODO: Open terms URL
                }
                .font(.caption)
                .foregroundStyle(AppColors.teal)

                Button("Privacy Policy") {
                    // TODO: Open privacy URL
                }
                .font(.caption)
                .foregroundStyle(AppColors.teal)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func purchase() async {
        guard let product = selectedProduct else { return }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let success = try await subscriptionManager.purchase(product)
            if success {
                dismiss()
            }
        } catch {
            showError = true
        }

        if subscriptionManager.purchaseError != nil {
            showError = true
        }
    }
}

// MARK: - Product Option Card

struct ProductOptionCard: View {
    let product: Product
    let isSelected: Bool
    let badge: String?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.textPrimary)

                        if let badge {
                            Text(badge)
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(AppColors.coral)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }

                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    if let subscription = product.subscription {
                        Text(subscription.subscriptionPeriod.displayUnit)
                            .font(.caption)
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppColors.coral : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Paywall Feature Row

private struct PaywallFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppColors.teal)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Subscription Period Extension

extension Product.SubscriptionPeriod {
    var displayUnit: String {
        switch unit {
        case .day: return value == 1 ? "per day" : "per \(value) days"
        case .week: return value == 1 ? "per week" : "per \(value) weeks"
        case .month: return value == 1 ? "per month" : "per \(value) months"
        case .year: return value == 1 ? "per year" : "per \(value) years"
        @unknown default: return ""
        }
    }
}

#Preview {
    PaywallView()
}
