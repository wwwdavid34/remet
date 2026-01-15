import SwiftUI

struct AddView: View {
    @State private var showingQuickCapture = false
    @State private var showingPhotoImport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(WittyCopy.random(from: WittyCopy.captureHints))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Quick Capture - Primary Action
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Capture")
                            .font(.headline)

                        Button {
                            showingQuickCapture = true
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [AppColors.coral, AppColors.coral.opacity(0.7)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 60, height: 60)

                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Take a Photo")
                                        .font(.headline)
                                        .foregroundStyle(AppColors.textPrimary)

                                    Text("Quickly capture someone you just met")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(AppColors.coral)
                            }
                            .padding()
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: AppColors.coral.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)

                    // Photo Library Import - Secondary Action
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Import from Library")
                            .font(.headline)

                        Button {
                            showingPhotoImport = true
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [AppColors.teal, AppColors.teal.opacity(0.7)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 60, height: 60)

                                    Image(systemName: "photo.on.rectangle")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Photo Library")
                                        .font(.headline)
                                        .foregroundStyle(AppColors.textPrimary)

                                    Text("Scan existing photos for faces")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(AppColors.teal)
                            }
                            .padding()
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: AppColors.teal.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)

                    // Tips Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tips for Best Results")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            TipRow(icon: "sun.max", text: "Good lighting helps face detection", color: AppColors.warmYellow)
                            TipRow(icon: "face.smiling", text: "Front-facing photos work best", color: AppColors.coral)
                            TipRow(icon: "photo.stack", text: "Multiple photos improve recognition", color: AppColors.teal)
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Person")
            .fullScreenCover(isPresented: $showingQuickCapture) {
                QuickCaptureView()
            }
            .sheet(isPresented: $showingPhotoImport) {
                PhotoImportView()
            }
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    var color: Color = AppColors.textSecondary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

#Preview {
    AddView()
}
