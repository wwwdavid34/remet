import SwiftUI
import PhotosUI

struct PhotoImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState: AppState?
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
                    PhotosPicker(selection: $viewModel.selectedItem, matching: .images) {
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
            .onChange(of: viewModel.selectedItem) {
                Task {
                    await viewModel.processSelectedPhoto()
                }
            }
            .sheet(isPresented: $viewModel.showFaceReview) {
                FaceReviewView(
                    image: viewModel.importedImage,
                    detectedFaces: viewModel.detectedFaces
                ) {
                    viewModel.reset()
                }
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

        await processCamera(image: image)
    }

    private func processCamera(image: UIImage) async {
        viewModel.importedImage = image
        do {
            let faceDetectionService = FaceDetectionService()
            viewModel.detectedFaces = try await faceDetectionService.detectFaces(in: image)
            viewModel.showFaceReview = !viewModel.detectedFaces.isEmpty

            if viewModel.detectedFaces.isEmpty {
                viewModel.errorMessage = "No faces detected in this photo"
            }
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    PhotoImportView()
}
