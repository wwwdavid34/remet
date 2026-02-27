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

                    // Photo picker
                    Button {
                        viewModel.showPhotoPicker = true
                    } label: {
                        Label("Choose Photos", systemImage: "photo.on.rectangle")
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
                guard !viewModel.pendingImages.isEmpty else { return }
                let images = viewModel.pendingImages
                viewModel.pendingImages = []
                Task {
                    await viewModel.processPickedPhotos(images: images, modelContext: modelContext)
                }
            }) {
                PhotoPicker(
                    onPick: { results in
                        viewModel.pendingImages = results.map { (image: $0.0, assetId: $0.1) }
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
            .sheet(isPresented: $viewModel.showGroupReview) {
                if let group = viewModel.photoGroup {
                    EncounterGroupReviewView(
                        photoGroup: group,
                        people: people
                    ) { encounter in
                        modelContext.insert(encounter)
                        try? modelContext.save()
                        viewModel.reset()
                    }
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
            .onAppear {
                processAnyPendingSharedImages()
            }
            .onChange(of: appState?.shouldProcessSharedImages) { _, shouldProcess in
                if shouldProcess == true {
                    processAnyPendingSharedImages()
                }
            }
        }
    }

    private func processAnyPendingSharedImages() {
        guard let paths = appState?.pendingSharedImagePaths, !paths.isEmpty else { return }

        // Take the first pending image; remaining will be processed after review
        let path = paths[0]

        appState?.pendingSharedImagePaths = Array(paths.dropFirst())
        if appState?.pendingSharedImagePaths.isEmpty == true {
            appState?.shouldProcessSharedImages = false
        }

        let url = URL(fileURLWithPath: path)

        Task {
            defer {
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
}

// MARK: - PHPicker Wrapper (multi-select, provides assetIdentifier for dedup)
struct PhotoPicker: UIViewControllerRepresentable {
    let onPick: ([(UIImage, String?)]) -> Void
    var onCancel: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 10
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
        let onPick: ([(UIImage, String?)]) -> Void
        let onCancel: (() -> Void)?

        init(onPick: @escaping ([(UIImage, String?)]) -> Void, onCancel: (() -> Void)?) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                DispatchQueue.main.async { self.onCancel?() }
                return
            }

            let group = DispatchGroup()
            var collected: [(Int, UIImage, String?)] = []

            for (index, result) in results.enumerated() {
                let assetId = result.assetIdentifier
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                    if let image = object as? UIImage {
                        DispatchQueue.main.async {
                            collected.append((index, image, assetId))
                            group.leave()
                        }
                    } else {
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                let sorted = collected.sorted { $0.0 < $1.0 }
                self.onPick(sorted.map { ($0.1, $0.2) })
            }
        }
    }
}

#Preview {
    PhotoImportView()
}
