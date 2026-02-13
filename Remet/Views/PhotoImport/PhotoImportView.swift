import SwiftUI
import SwiftData
import PhotosUI

struct PhotoImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState: AppState?
    @Query(sort: \Person.name) private var people: [Person]
    @State private var viewModel = PhotoImportViewModel()
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "face.smiling")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)

                Text("Import Photos")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Add photos to identify faces")
                    .foregroundStyle(.secondary)

                VStack(spacing: 16) {
                    // Scan Photo Library - Primary action
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan Photo Library", systemImage: "photo.stack")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    // Single photo picker
                    Button {
                        viewModel.showPhotoPicker = true
                    } label: {
                        Label("Choose Single Photo", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal, 40)

                // Description text
                VStack(spacing: 8) {
                    Text("Scan finds photos with faces and groups them into encounters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)

                if viewModel.isProcessing {
                    ProgressView("Detecting faces...")
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Spacer()
            }
            .navigationTitle("Remet")
            .sheet(isPresented: $viewModel.showPhotoPicker, onDismiss: {
                // Process after picker sheet fully dismisses to avoid sheet conflict
                guard let image = viewModel.pendingImage else { return }
                let assetId = viewModel.pendingAssetId
                viewModel.pendingImage = nil
                viewModel.pendingAssetId = nil
                Task {
                    await viewModel.processPickedPhoto(
                        image: image,
                        assetIdentifier: assetId,
                        modelContext: modelContext
                    )
                }
            }) {
                SinglePhotoPicker(
                    onPick: { image, assetIdentifier in
                        viewModel.pendingImage = image
                        viewModel.pendingAssetId = assetIdentifier
                        viewModel.showPhotoPicker = false
                    },
                    onCancel: {
                        viewModel.showPhotoPicker = false
                    }
                )
            }
            .sheet(isPresented: $viewModel.showFaceReview) {
                if let image = viewModel.importedImage {
                    EncounterReviewView(
                        scannedPhoto: ScannedPhoto(
                            id: viewModel.assetIdentifier ?? UUID().uuidString,
                            asset: nil,
                            image: image,
                            detectedFaces: viewModel.detectedFaces,
                            date: viewModel.photoDate ?? Date(),
                            location: viewModel.photoLocation
                        ),
                        people: people,
                        onSave: { encounter in
                            modelContext.insert(encounter)
                            try? modelContext.save()
                            viewModel.reset()
                        }
                    )
                }
            }
            .alert("Already Imported", isPresented: $viewModel.showAlreadyImportedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This photo has already been imported.")
            }
            .sheet(isPresented: $showScanner) {
                EncounterScannerView()
            }
            .onChange(of: appState?.shouldProcessSharedImage) { _, shouldProcess in
                if shouldProcess == true, let imageURL = appState?.sharedImageURL {
                    Task {
                        await processSharedImage(from: imageURL)
                    }
                }
            }
            .onAppear {
                // Check for shared image on appear
                if appState?.shouldProcessSharedImage == true, let imageURL = appState?.sharedImageURL {
                    Task {
                        await processSharedImage(from: imageURL)
                    }
                }
            }
        }
    }

    private func processSharedImage(from url: URL) async {
        defer {
            appState?.shouldProcessSharedImage = false
            appState?.sharedImageURL = nil
            // Clean up the shared file
            try? FileManager.default.removeItem(at: url)
        }

        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            viewModel.errorMessage = "Could not load shared image"
            return
        }

        await viewModel.processPickedPhoto(image: image, assetIdentifier: nil, modelContext: modelContext)
    }
}

// MARK: - PHPicker Wrapper (provides assetIdentifier for dedup)
struct SinglePhotoPicker: UIViewControllerRepresentable {
    let onPick: (UIImage, String?) -> Void
    var onCancel: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage, String?) -> Void
        let onCancel: (() -> Void)?

        init(onPick: @escaping (UIImage, String?) -> Void, onCancel: (() -> Void)?) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                DispatchQueue.main.async { self.onCancel?() }
                return
            }
            let assetId = result.assetIdentifier

            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async {
                    self.onPick(image, assetId)
                }
            }
        }
    }
}

#Preview {
    PhotoImportView()
}
