import SwiftUI
import SwiftData

struct FaceReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var people: [Person]

    let image: UIImage?
    let detectedFaces: [DetectedFace]
    let onComplete: () -> Void

    @State private var viewModel = FaceReviewViewModel()
    @State private var showPeoplePicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let currentFace = viewModel.currentFace {
                    ScrollView {
                        VStack(spacing: 24) {
                            faceImageSection(currentFace)
                            matchSection(currentFace)
                        }
                        .padding()
                    }
                } else if viewModel.allFacesProcessed {
                    completionView
                } else {
                    ProgressView("Processing...")
                }
            }
            .navigationTitle("Review Faces")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onComplete()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if viewModel.currentFace != nil {
                        Button("Skip") {
                            viewModel.skipCurrentFace()
                        }
                    }
                }
            }
            .onAppear {
                viewModel.setupFaces(from: detectedFaces)
                Task {
                    await viewModel.processCurrentFace(people: people)
                }
            }
            .onChange(of: viewModel.currentFaceIndex) {
                Task {
                    await viewModel.processCurrentFace(people: people)
                }
            }
            .sheet(isPresented: $viewModel.showNameInput) {
                newPersonSheet
            }
            .sheet(isPresented: $showPeoplePicker) {
                peoplePickerSheet
            }
        }
    }

    @ViewBuilder
    private func faceImageSection(_ face: FaceForReview) -> some View {
        VStack(spacing: 12) {
            Image(uiImage: face.detectedFace.cropImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 250)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 4)

            Text("Face \(viewModel.currentFaceIndex + 1) of \(viewModel.facesForReview.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func matchSection(_ face: FaceForReview) -> some View {
        VStack(spacing: 16) {
            if viewModel.isProcessing {
                ProgressView("Analyzing face...")
            } else if let match = face.matchResult {
                matchResultView(match)
            } else {
                noMatchView
            }
        }
    }

    @ViewBuilder
    private func matchResultView(_ match: MatchResult) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Is this \(match.person.name)?")
                        .font(.headline)

                    Text(confidenceText(match.confidence))
                        .font(.caption)
                        .foregroundStyle(confidenceColor(match.confidence))
                }

                Spacer()

                Text("\(Int(match.similarity * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(confidenceColor(match.confidence))
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 16) {
                Button {
                    viewModel.rejectMatch()
                } label: {
                    Label("Not them", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    viewModel.confirmMatch(modelContext: modelContext)
                } label: {
                    Label("Yes, that's \(match.person.name)", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    @ViewBuilder
    private var noMatchView: some View {
        VStack(spacing: 16) {
            Text("Who is this?")
                .font(.headline)

            Text("No matching person found in your library")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Button {
                    viewModel.showNameInput = true
                } label: {
                    Label("Add New Person", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if !people.isEmpty {
                    Button {
                        showPeoplePicker = true
                    } label: {
                        Label("Choose Existing Person", systemImage: "person.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
    }

    @ViewBuilder
    private var completionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("All Done!")
                .font(.title2)
                .fontWeight(.semibold)

            let processed = viewModel.facesForReview.filter { $0.assignedPerson != nil }
            Text("\(processed.count) face(s) identified")
                .foregroundStyle(.secondary)

            if viewModel.createdEncounter != nil {
                Label("Encounter created", systemImage: "person.2.crop.square.stack")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("Done") {
                // Create encounter if we have an image and identified faces
                if let img = image, viewModel.createdEncounter == nil {
                    let hasIdentifiedFaces = viewModel.facesForReview.contains { $0.assignedPerson != nil }
                    if hasIdentifiedFaces {
                        _ = viewModel.createEncounter(from: img, modelContext: modelContext)
                    }
                }
                onComplete()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .onAppear {
            // Auto-create encounter when completion view appears
            if let img = image, viewModel.createdEncounter == nil {
                let hasIdentifiedFaces = viewModel.facesForReview.contains { $0.assignedPerson != nil }
                if hasIdentifiedFaces {
                    // Small delay to ensure embeddings are saved
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        _ = viewModel.createEncounter(from: img, modelContext: modelContext)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var newPersonSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let face = viewModel.currentFace {
                    Image(uiImage: face.detectedFace.cropImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)
                        .clipShape(Circle())
                }

                TextField("Name", text: $viewModel.newPersonName)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("New Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.newPersonName = ""
                        viewModel.showNameInput = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        _ = viewModel.createNewPerson(modelContext: modelContext)
                    }
                    .disabled(viewModel.newPersonName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var peoplePickerSheet: some View {
        NavigationStack {
            List(people) { person in
                Button {
                    viewModel.assignToExistingPerson(person, modelContext: modelContext)
                    showPeoplePicker = false
                } label: {
                    HStack {
                        if let firstEmbedding = person.embeddings.first,
                           let image = UIImage(data: firstEmbedding.faceCropData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary)
                        }

                        Text(person.name)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Choose Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showPeoplePicker = false
                    }
                }
            }
        }
    }

    private func confidenceText(_ confidence: MatchConfidence) -> String {
        switch confidence {
        case .high:
            return "High confidence match"
        case .ambiguous:
            return "Possible match - please confirm"
        case .none:
            return "Low confidence"
        }
    }

    private func confidenceColor(_ confidence: MatchConfidence) -> Color {
        switch confidence {
        case .high:
            return .green
        case .ambiguous:
            return .orange
        case .none:
            return .red
        }
    }
}
