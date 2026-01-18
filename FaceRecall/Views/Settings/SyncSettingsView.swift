import SwiftUI

struct SyncSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CloudSyncManager.self) private var syncManager
    @State private var isCheckingAccount = false

    var body: some View {
        List {
            Section {
                syncStatusRow
            } header: {
                Text("iCloud Sync")
            } footer: {
                Text("Your data syncs automatically across all devices signed into the same iCloud account.")
            }

            Section {
                if let lastSync = syncManager.lastSyncDate {
                    LabeledContent("Last Sync") {
                        Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                Button {
                    checkStatus()
                } label: {
                    HStack {
                        Text("Check Sync Status")
                        Spacer()
                        if isCheckingAccount {
                            ProgressView()
                        }
                    }
                }
                .disabled(isCheckingAccount)
            }

            Section {
                NavigationLink("What Gets Synced") {
                    syncDetailsView
                }
            }
        }
        .navigationTitle("iCloud Sync")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var syncStatusRow: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading) {
                Text(statusTitle)
                    .font(.headline)
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if case .syncing = syncManager.syncStatus {
                ProgressView()
            } else if case .checking = syncManager.syncStatus {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private var syncDetailsView: some View {
        List {
            Section("Synced Data") {
                Label("People & Names", systemImage: "person.3")
                Label("Face Photos", systemImage: "photo")
                Label("Encounters", systemImage: "calendar")
                Label("Notes & Tags", systemImage: "tag")
                Label("Practice Progress", systemImage: "chart.line.uptrend.xyaxis")
            }

            Section("Not Synced") {
                Label("Subscription Status", systemImage: "creditcard")
                    .foregroundStyle(.secondary)
                Label("App Settings", systemImage: "gearshape")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Sync Details")
    }

    private var statusIcon: String {
        switch syncManager.syncStatus {
        case .disabled: return "icloud.slash"
        case .checking, .syncing: return "icloud"
        case .synced: return "checkmark.icloud"
        case .error: return "exclamationmark.icloud"
        case .noAccount: return "person.crop.circle.badge.exclamationmark"
        }
    }

    private var statusColor: Color {
        switch syncManager.syncStatus {
        case .disabled: return .secondary
        case .checking, .syncing: return .blue
        case .synced: return .green
        case .error: return .red
        case .noAccount: return .orange
        }
    }

    private var statusTitle: String {
        switch syncManager.syncStatus {
        case .disabled: return String(localized: "Sync Disabled")
        case .checking: return String(localized: "Checking...")
        case .syncing: return String(localized: "Syncing...")
        case .synced: return String(localized: "Synced")
        case .error: return String(localized: "Sync Error")
        case .noAccount: return String(localized: "No iCloud Account")
        }
    }

    private var statusSubtitle: String {
        switch syncManager.syncStatus {
        case .disabled:
            return String(localized: "Upgrade to Premium to enable")
        case .checking:
            return String(localized: "Checking iCloud status...")
        case .syncing:
            return String(localized: "Uploading changes...")
        case .synced:
            return String(localized: "All data up to date")
        case .error(let message):
            return message
        case .noAccount:
            return String(localized: "Sign in to iCloud in Settings")
        }
    }

    private func checkStatus() {
        isCheckingAccount = true
        Task {
            await syncManager.checkAccountStatus()
            await MainActor.run {
                isCheckingAccount = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        SyncSettingsView()
            .environment(CloudSyncManager.shared)
    }
}
