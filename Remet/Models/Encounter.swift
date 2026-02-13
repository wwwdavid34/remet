import Foundation
import SwiftData

@Model
final class Encounter {
    var id: UUID = UUID()
    var occasion: String?
    var notes: String?
    var location: String?
    var date: Date = Date()
    var createdAt: Date = Date()
    var isFavorite: Bool = false

    // GPS coordinates (from first photo or average)
    var latitude: Double?
    var longitude: Double?

    // Thumbnail image data (first photo or representative)
    var thumbnailData: Data?

    // Legacy single-photo support (deprecated, use photos relationship)
    var imageData: Data?
    var faceBoundingBoxesData: Data?

    // Multiple photos in this encounter
    @Relationship(deleteRule: .cascade)
    var photos: [EncounterPhoto]?

    @Relationship(deleteRule: .nullify, inverse: \Person.encounters)
    var people: [Person]?

    @Relationship(deleteRule: .nullify)
    var tags: [Tag]?

    init(
        id: UUID = UUID(),
        occasion: String? = nil,
        notes: String? = nil,
        location: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        date: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.occasion = occasion
        self.notes = notes
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.date = date
        self.createdAt = createdAt
    }

    // Legacy initializer for backward compatibility
    convenience init(
        id: UUID = UUID(),
        imageData: Data,
        occasion: String? = nil,
        notes: String? = nil,
        location: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        date: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.init(
            id: id,
            occasion: occasion,
            notes: notes,
            location: location,
            latitude: latitude,
            longitude: longitude,
            date: date,
            createdAt: createdAt
        )
        self.imageData = imageData
        self.thumbnailData = imageData
    }

    /// Check if GPS coordinates are available
    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    /// Get Apple Maps URL for the coordinates
    var mapsURL: URL? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return URL(string: "https://maps.apple.com/?ll=\(lat),\(lon)&q=Encounter%20Location")
    }

    /// Get the display image (first photo or legacy imageData)
    var displayImageData: Data? {
        if let firstPhoto = (photos ?? []).first {
            return firstPhoto.imageData
        }
        return imageData ?? thumbnailData
    }

    /// Total number of faces across all photos
    var totalFaceCount: Int {
        let p = photos ?? []
        if p.isEmpty {
            return faceBoundingBoxes.count
        }
        return p.reduce(0) { $0 + $1.faceBoundingBoxes.count }
    }

    /// Photos sorted by date
    var sortedPhotos: [EncounterPhoto] {
        (photos ?? []).sorted { $0.date < $1.date }
    }

    // Legacy convenience for face bounding boxes (single photo mode)
    var faceBoundingBoxes: [FaceBoundingBox] {
        get {
            guard let data = faceBoundingBoxesData else { return [] }
            return (try? JSONDecoder().decode([FaceBoundingBox].self, from: data)) ?? []
        }
        set {
            faceBoundingBoxesData = try? JSONEncoder().encode(newValue)
        }
    }
}

struct FaceBoundingBox: Codable, Identifiable {
    var id: UUID
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var personId: UUID?
    var personName: String?
    var confidence: Float?
    var isAutoAccepted: Bool

    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    init(
        id: UUID = UUID(),
        rect: CGRect,
        personId: UUID? = nil,
        personName: String? = nil,
        confidence: Float? = nil,
        isAutoAccepted: Bool = false
    ) {
        self.id = id
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.width
        self.height = rect.height
        self.personId = personId
        self.personName = personName
        self.confidence = confidence
        self.isAutoAccepted = isAutoAccepted
    }
}
