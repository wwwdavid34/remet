import Foundation
import SwiftData

@Model
final class FaceEmbedding {
    var id: UUID
    var vector: Data
    var faceCropData: Data
    var sourcePhotoId: UUID?
    var encounterId: UUID?
    var boundingBoxId: UUID?
    var createdAt: Date

    var person: Person?

    init(
        id: UUID = UUID(),
        vector: Data,
        faceCropData: Data,
        sourcePhotoId: UUID? = nil,
        encounterId: UUID? = nil,
        boundingBoxId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.vector = vector
        self.faceCropData = faceCropData
        self.sourcePhotoId = sourcePhotoId
        self.encounterId = encounterId
        self.boundingBoxId = boundingBoxId
        self.createdAt = createdAt
    }

    var embeddingVector: [Float] {
        get {
            vector.withUnsafeBytes { pointer in
                Array(pointer.bindMemory(to: Float.self))
            }
        }
        set {
            vector = newValue.withUnsafeBytes { Data($0) }
        }
    }
}
