import Foundation
import SwiftData

@Model
final class EncounterPhoto {
    var id: UUID = UUID()
    var imageData: Data = Data()
    var date: Date = Date()
    var latitude: Double?
    var longitude: Double?
    var assetIdentifier: String?

    // Store face bounding boxes as JSON
    var faceBoundingBoxesData: Data?

    @Relationship(inverse: \Encounter.photos)
    var encounter: Encounter?

    init(
        id: UUID = UUID(),
        imageData: Data,
        date: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil,
        assetIdentifier: String? = nil
    ) {
        self.id = id
        self.imageData = imageData
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.assetIdentifier = assetIdentifier
    }

    // Convenience for face bounding boxes
    var faceBoundingBoxes: [FaceBoundingBox] {
        get {
            guard let data = faceBoundingBoxesData else { return [] }
            return (try? JSONDecoder().decode([FaceBoundingBox].self, from: data)) ?? []
        }
        set {
            faceBoundingBoxesData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Check if GPS coordinates are available
    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }
}
