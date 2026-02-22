import SwiftUI
import SwiftData

struct ProfileImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let name: String
    let faceImage: UIImage
    let onImported: (Person) -> Void

    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(uiImage: faceImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppColors.teal, lineWidth: 3)
                    )

                Text(name)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(localized: "Shared Remet Profile"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppColors.error)
                }

                Button {
                    importProfile()
                } label: {
                    if isImporting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text(String(localized: "Import"))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .background(AppColors.coral)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isImporting)

                Button(String(localized: "Cancel")) {
                    dismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(24)
            .navigationTitle(String(localized: "Import Profile"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func importProfile() {
        isImporting = true
        errorMessage = nil

        Task {
            do {
                let person = try await ProfileSharingService.importProfile(
                    name: name,
                    faceImage: faceImage,
                    modelContext: modelContext
                )
                await MainActor.run {
                    isImporting = false
                    onImported(person)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }
}
