import Foundation
import UIKit
import SwiftData

struct RemetProfile: Codable {
    let version: Int
    let name: String
    let faceImageBase64: String
}

enum ProfileSharingError: LocalizedError {
    case noProfileFace
    case invalidFileData
    case embeddingFailed

    var errorDescription: String? {
        switch self {
        case .noProfileFace: return "This person has no profile face to share."
        case .invalidFileData: return "The file could not be read."
        case .embeddingFailed: return "Failed to process the face image."
        }
    }
}

@MainActor
enum ProfileSharingService {

    /// Create a temporary .remet file for sharing via the share sheet.
    static func exportProfile(for person: Person) throws -> URL {
        guard let embedding = person.profileEmbedding else {
            throw ProfileSharingError.noProfileFace
        }

        let profile = RemetProfile(
            version: 1,
            name: person.name,
            faceImageBase64: embedding.faceCropData.base64EncodedString()
        )

        let data = try JSONEncoder().encode(profile)

        let safeName = person.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let fileName = "\(safeName).remet"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try? FileManager.default.removeItem(at: tempURL)
        try data.write(to: tempURL)

        return tempURL
    }

    /// Parse a .remet file and return the profile data (name + face image).
    static func parseProfile(from url: URL) throws -> (name: String, faceImage: UIImage) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let profile = try JSONDecoder().decode(RemetProfile.self, from: data)

        guard let imageData = Data(base64Encoded: profile.faceImageBase64),
              let image = UIImage(data: imageData) else {
            throw ProfileSharingError.invalidFileData
        }

        return (name: profile.name, faceImage: image)
    }

    /// Import a parsed profile into SwiftData.
    static func importProfile(
        name: String,
        faceImage: UIImage,
        modelContext: ModelContext
    ) async throws -> Person {
        let person = Person(name: name)

        let embeddingService = FaceEmbeddingService.shared
        let vector = try await embeddingService.generateEmbedding(for: faceImage)

        guard let faceData = faceImage.jpegData(compressionQuality: 0.8) else {
            throw ProfileSharingError.embeddingFailed
        }

        let faceEmbedding = FaceEmbedding(
            vector: vector.withUnsafeBytes { Data($0) },
            faceCropData: faceData
        )
        faceEmbedding.person = person
        person.embeddings = [faceEmbedding]
        person.profileEmbeddingId = faceEmbedding.id

        let srData = SpacedRepetitionData()
        srData.person = person
        person.spacedRepetitionData = srData

        modelContext.insert(person)
        try modelContext.save()

        return person
    }
}
