import Foundation
import SwiftData

@Model
final class ImportedPhoto {
    var id: UUID
    var imageData: Data
    var importedAt: Date
    var processed: Bool

    init(
        id: UUID = UUID(),
        imageData: Data,
        importedAt: Date = Date(),
        processed: Bool = false
    ) {
        self.id = id
        self.imageData = imageData
        self.importedAt = importedAt
        self.processed = processed
    }
}
