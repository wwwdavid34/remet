import SwiftUI
import SwiftData

/// Scan tab for identifying people via camera or photo
/// Core feature: "Who is this person?"
struct ScanTabView: View {
    @Query private var people: [Person]

    @State private var showMemoryScan = false
    @State private var showImageMatch = false
    @State private var showPremiumRequired = false

    private var subscriptionManager: SubscriptionManager { .shared }

    /// People with at least one embedding (required for matching)
    private var matchablePeople: [Person] {
        people.filter { !($0.embeddings ?? []).isEmpty }
    }

    private var canScan: Bool {
        !matchablePeople.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header illustration
                    headerSection

                    // Scan options
                    if canScan {
                        scanOptionsSection
                    } else {
                        emptyStateSection
                    }

                    // Tips
                    tipsSection
                }
                .padding()
                .padding(.bottom, 80) // Space for FAB
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Identify")
            .navigationBarTitleDisplayMode(.large)
        }
        .fullScreenCover(isPresented: $showMemoryScan) {
            MemoryScanView()
        }
        .sheet(isPresented: $showImageMatch) {
            EphemeralMatchView()
        }
        .sheet(isPresented: $showPremiumRequired) {
            PaywallView()
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.teal.opacity(0.2), AppColors.softPurple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.teal, AppColors.softPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Who's This?")
                .font(.title2)
                .fontWeight(.bold)

            Text("Identify someone using your camera or a photo")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    // MARK: - Scan Options

    @ViewBuilder
    private var scanOptionsSection: some View {
        VStack(spacing: 16) {
            // Live Scan (Free)
            Button {
                showMemoryScan = true
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppColors.teal)
                            .frame(width: 56, height: 56)

                        Image(systemName: "camera.viewfinder")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Live Camera Scan")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("Point your camera at someone")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .tintedGlassBackground(AppColors.teal, tintOpacity: 0.05, cornerRadius: 16)
            }
            .buttonStyle(.plain)

            // Photo Match (Premium or free photo import)
            Button {
                if subscriptionManager.isPremium {
                    showImageMatch = true
                } else {
                    showPremiumRequired = true
                }
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(subscriptionManager.isPremium ? AppColors.softPurple : AppColors.textMuted)
                            .frame(width: 56, height: 56)

                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Match from Photo")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            if !subscriptionManager.isPremium {
                                PremiumBadge()
                            }
                        }

                        Text("Select a photo to identify faces")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: subscriptionManager.isPremium ? "chevron.right" : "lock.fill")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .tintedGlassBackground(
                    subscriptionManager.isPremium ? AppColors.softPurple : AppColors.textMuted,
                    tintOpacity: 0.05,
                    cornerRadius: 16
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(AppColors.textMuted)

            Text("Add People First")
                .font(.headline)

            Text("You need to add at least one person with a face before you can identify them.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Use the camera button below to get started")
                .font(.caption)
                .foregroundStyle(AppColors.coral)
        }
        .padding()
        .glassCard(intensity: .regular, cornerRadius: 16)
    }

    // MARK: - Tips

    @ViewBuilder
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tips for Best Results")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                TipRow(icon: "sun.max", text: "Good lighting improves accuracy")
                TipRow(icon: "face.smiling", text: "Face the camera directly")
                TipRow(icon: "photo.stack", text: "More face samples = better matching")
            }
        }
        .padding(.top, 8)
    }
}

#Preview {
    ScanTabView()
        .modelContainer(for: Person.self, inMemory: true)
}
