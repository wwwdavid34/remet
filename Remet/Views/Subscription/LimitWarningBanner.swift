import SwiftUI

/// Banner shown when approaching the free tier limit
struct LimitWarningBanner: View {
    let status: LimitChecker.LimitStatus
    let onUpgrade: () -> Void

    var body: some View {
        if case .approachingLimit(let limit, let current) = status {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColors.warmYellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(current) of \(limit) people")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Upgrade for unlimited")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Button("Upgrade") {
                    onUpgrade()
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColors.coral)
                .clipShape(Capsule())
            }
            .padding()
            .background(AppColors.warmYellow.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// Compact version for list headers
struct LimitWarningCompact: View {
    let status: LimitChecker.LimitStatus

    var body: some View {
        if let message = status.shortMessage {
            HStack(spacing: 4) {
                Image(systemName: status.isBlocked ? "lock.fill" : "info.circle.fill")
                    .font(.caption)
                Text(message)
                    .font(.caption)
            }
            .foregroundStyle(status.isBlocked ? AppColors.coral : AppColors.warmYellow)
        }
    }
}

/// Unified premium badge — gold crown capsule
struct PremiumBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "crown.fill")
                .font(.caption2)
            Text("Premium")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(AppColors.warmYellow)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(AppColors.warmYellow.opacity(0.15))
        .clipShape(Capsule())
    }
}

#Preview("Approaching Limit") {
    VStack {
        LimitWarningBanner(
            status: .approachingLimit(limit: 25, current: 22),
            onUpgrade: { }
        )
        .padding()

        LimitWarningCompact(status: .approachingLimit(limit: 25, current: 22))
            .padding()

        LimitWarningCompact(status: .hardLimitReached(limit: 25, current: 25))
            .padding()
    }
}
