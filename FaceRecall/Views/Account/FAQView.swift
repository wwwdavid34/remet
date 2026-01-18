import SwiftUI

struct FAQView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FAQSection(
                    question: String(localized: "What does \"Restore Purchases\" do?"),
                    answer: String(localized: """
                    Restore Purchases syncs your subscription status with the App Store. \
                    Use this if your premium features aren't showing after a purchase, \
                    or if you reinstalled the app.

                    Note: This restores your subscription only, not your data. \
                    Your data syncs automatically via iCloud when signed in with the same Apple ID.
                    """)
                )

                FAQSection(
                    question: String(localized: "What happens if I change my Apple ID?"),
                    answer: String(localized: """
                    Your subscription and cloud data are tied to your Apple ID:

                    • Subscription: Tied to the Apple ID that purchased it. \
                    You'll need to subscribe again on the new Apple ID, or sign back \
                    into your original Apple ID to access your subscription.

                    • Cloud Data: Stored in iCloud under your Apple ID. \
                    Switching Apple IDs means you won't have access to data synced \
                    under the previous account.

                    • Local Data: Stays on your device regardless of Apple ID changes.

                    To keep your subscription and synced data, use the same Apple ID.
                    """)
                )

                FAQSection(
                    question: String(localized: "What happens if I get a new phone?"),
                    answer: String(localized: """
                    If you sign in with the same Apple ID on your new phone:

                    • Subscription: Automatically restored. Tap \"Restore Purchases\" \
                    if it doesn't appear immediately.

                    • Cloud Data (Premium): Syncs automatically from iCloud. \
                    Your people, encounters, and face data will download to your new device.

                    • Local-Only Data (Free tier): Not transferred. Free tier data \
                    is stored only on your device and won't move to a new phone.

                    For seamless migration, upgrade to Premium before switching phones.
                    """)
                )

                FAQSection(
                    question: String(localized: "What are the free tier limits?"),
                    answer: String(localized: """
                    Free users can store up to 25 people. Encounters are unlimited.

                    Free tier data is stored locally on your device only and does not sync \
                    to iCloud. If you delete the app or switch phones, this data will be lost.

                    Premium removes the people limit and adds iCloud sync across all your devices.
                    """)
                )

                FAQSection(
                    question: String(localized: "Why can't I export my data?"),
                    answer: String(localized: """
                    To protect privacy, Remet does not allow exporting face data. \
                    Face embeddings are sensitive biometric information, and export \
                    features could enable unauthorized copying or sharing.

                    Your data is securely stored on your device and (for Premium users) \
                    encrypted in your personal iCloud account.
                    """)
                )

                FAQSection(
                    question: String(localized: "Is my face data secure?"),
                    answer: String(localized: """
                    Yes. All face detection and recognition happens entirely on your device. \
                    Your photos and face data are never sent to external servers.

                    Premium users' data syncs via iCloud, which is encrypted and accessible \
                    only to your Apple ID. We cannot access your iCloud data.
                    """)
                )

                FAQSection(
                    question: String(localized: "How do I report a problem?"),
                    answer: String(localized: """
                    Tap "Contact Support" in the About section to send us an email. \
                    Your message will automatically include your app version and device info \
                    to help us diagnose the issue.

                    Please describe what you were doing when the problem occurred \
                    and any error messages you saw.
                    """)
                )
            }
            .padding()
        }
        .navigationTitle(String(localized: "FAQ"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FAQSection: View {
    let question: String
    let answer: String

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top) {
                    Text(question)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(answer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        FAQView()
    }
}
