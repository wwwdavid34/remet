import SwiftUI
import SwiftData
import PhotosUI

struct OnboardingFirstMemoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]

    let currentStep: Int
    let totalSteps: Int
    let onComplete: () -> Void
    let onSkip: () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showPhotosPicker = false
    @State private var showFaceReview = false
    @State private var isProcessing = false
    @State private var detectedFaces: [DetectedFace] = []
    @State private var encounterSaved = false
    @State private var showReviewIntro = true

    var body: some View {
        VStack(spacing: 24) {
            // Progress indicator
            OnboardingProgressIndicator(currentStep: currentStep, totalSteps: totalSteps)
                .padding(.top, 16)

            // Header
            VStack(spacing: 8) {
                Text(String(localized: "Add Your First Memory"))
                    .font(.title)
                    .fontWeight(.bold)

                Text(String(localized: "Import a photo with people you've met. We'll help you tag faces and remember their names."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 40)

            Spacer()

            // Photo import area
            VStack(spacing: 24) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppColors.teal, lineWidth: 2)
                        )
                } else {
                    // Placeholder
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundStyle(AppColors.teal.opacity(0.6))

                        Text(String(localized: "Choose a photo with people you know"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 280, height: 200)
                    .background(AppColors.teal.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Photo picker button
                Button {
                    showPhotosPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selectedImage == nil ? "photo.badge.plus" : "arrow.triangle.2.circlepath")
                        Text(selectedImage == nil ? String(localized: "Choose Photo") : String(localized: "Choose Different"))
                    }
                    .font(.headline)
                    .foregroundStyle(AppColors.teal)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppColors.teal.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                if selectedImage != nil {
                    Button {
                        detectFacesAndShowReview()
                    } label: {
                        Text(String(localized: "Continue"))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.coral)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isProcessing)
                }

                Button(action: onSkip) {
                    Text(String(localized: "Skip for Now"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 44)
                }
                .contentShape(Rectangle())
                .padding(.top, selectedImage == nil ? 0 : 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(AppColors.background)
        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newItem in
            loadImage(from: newItem)
        }
        .sheet(isPresented: $showFaceReview, onDismiss: {
            if encounterSaved {
                onComplete()
            }
        }) {
            if showReviewIntro {
                reviewIntroView
            } else if let image = selectedImage {
                EncounterGroupReviewView(
                    photoGroup: PhotoGroup(
                        id: UUID(),
                        photos: [
                            ScannedPhoto(
                                id: UUID().uuidString,
                                asset: nil,
                                image: image,
                                detectedFaces: detectedFaces,
                                date: Date(),
                                location: nil
                            )
                        ]
                    ),
                    people: people,
                    onSave: { encounter in
                        modelContext.insert(encounter)
                        try? modelContext.save()
                        encounterSaved = true
                    }
                )
            }
        }
        .overlay {
            if isProcessing {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView()
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Review Intro

    @ViewBuilder
    private var reviewIntroView: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "person.crop.rectangle.stack")
                    .font(.system(size: 56))
                    .foregroundStyle(AppColors.teal)

                VStack(spacing: 8) {
                    if detectedFaces.isEmpty {
                        Text(String(localized: "No faces detected"))
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(String(localized: "You can manually tap where you see a face in the next screen."))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    } else {
                        Text(String(localized: "We found \(detectedFaces.count) face(s)!"))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    reviewIntroRow(
                        icon: "hand.tap",
                        text: String(localized: "Tap a face to assign a name")
                    )
                    reviewIntroRow(
                        icon: "person.badge.plus",
                        text: String(localized: "Add new people or match existing ones")
                    )
                    reviewIntroRow(
                        icon: "calendar.badge.plus",
                        text: String(localized: "Optionally add occasion and location")
                    )
                }
                .padding(.horizontal, 40)

                Spacer()

                Button {
                    showReviewIntro = false
                } label: {
                    Text(String(localized: "Continue"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.coral)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .navigationTitle(String(localized: "Review Your Photo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        showFaceReview = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func reviewIntroRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppColors.teal)
                .frame(width: 28)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Actions

    private func detectFacesAndShowReview() {
        guard let image = selectedImage else { return }
        isProcessing = true

        Task {
            let faceDetectionService = FaceDetectionService()
            let faces = (try? await faceDetectionService.detectFaces(in: image)) ?? []

            await MainActor.run {
                detectedFaces = faces
                isProcessing = false
                encounterSaved = false
                showReviewIntro = true
                showFaceReview = true
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        isProcessing = true

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                    isProcessing = false
                }
            } else {
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }
}

#Preview {
    OnboardingFirstMemoryView(currentStep: 2, totalSteps: 4, onComplete: {}, onSkip: {})
}
