import Foundation
import SwiftData

@Model
final class ImportedPhoto {
    var id: UUID = UUID()
    var imageData: Data = Data()
    var importedAt: Date = Date()
    var processed: Bool = false

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
