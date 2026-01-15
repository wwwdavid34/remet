import SwiftUI

struct AddView: View {
    @State private var showingQuickCapture = false
    @State private var showingPhotoImport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
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
                                        .fill(Color.blue)
                                        .frame(width: 60, height: 60)

                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Take a Photo")
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Text("Quickly capture someone you just met")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
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
                                        .fill(Color.purple)
                                        .frame(width: 60, height: 60)

                                    Image(systemName: "photo.on.rectangle")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Photo Library")
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Text("Scan existing photos for faces")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)

                    // Tips Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tips for Best Results")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            TipRow(icon: "sun.max", text: "Good lighting helps face detection")
                            TipRow(icon: "face.smiling", text: "Front-facing photos work best")
                            TipRow(icon: "photo.stack", text: "Multiple photos improve recognition")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    AddView()
}
