import UIKit
import Photos
import CoreLocation

struct ScannedPhoto: Identifiable {
    let id: String
    let asset: PHAsset
    var image: UIImage?
    var detectedFaces: [DetectedFace]
    var date: Date
    var location: CLLocation?

    var hasFaces: Bool {
        !detectedFaces.isEmpty
    }
}

/// A group of photos that belong to the same encounter (similar time and location)
struct PhotoGroup: Identifiable {
    let id: UUID
    var photos: [ScannedPhoto]
    var locationName: String?

    var date: Date {
        photos.first?.date ?? Date()
    }

    var location: CLLocation? {
        photos.first(where: { $0.location != nil })?.location
    }

    var totalFaces: Int {
        photos.reduce(0) { $0 + $1.detectedFaces.count }
    }

    var dateRange: String {
        guard let first = photos.first?.date else { return "" }
        guard let last = photos.last?.date, first != last else {
            return first.formatted(date: .abbreviated, time: .shortened)
        }
        return "\(first.formatted(date: .omitted, time: .shortened)) - \(last.formatted(date: .omitted, time: .shortened))"
    }

    var hasLocation: Bool {
        location != nil
    }
}

/// Time range options for scanning photos
enum ScanTimeRange: String, CaseIterable, Identifiable {
    case last24Hours = "Last 24 Hours"
    case last3Days = "Last 3 Days"
    case lastWeek = "Last Week"
    case last2Weeks = "Last 2 Weeks"
    case lastMonth = "Last Month"
    case last3Months = "Last 3 Months"
    case lastYear = "Last Year"
    case allTime = "All Time"

    var id: String { rawValue }

    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .last24Hours:
            return calendar.date(byAdding: .hour, value: -24, to: now)
        case .last3Days:
            return calendar.date(byAdding: .day, value: -3, to: now)
        case .lastWeek:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .last2Weeks:
            return calendar.date(byAdding: .day, value: -14, to: now)
        case .lastMonth:
            return calendar.date(byAdding: .month, value: -1, to: now)
        case .last3Months:
            return calendar.date(byAdding: .month, value: -3, to: now)
        case .lastYear:
            return calendar.date(byAdding: .year, value: -1, to: now)
        case .allTime:
            return nil
        }
    }
}

final class PhotoLibraryScannerService {
    // Grouping thresholds
    private let timeThresholdMinutes: Double = 30  // Photos within 30 minutes
    private let distanceThresholdMeters: Double = 500  // Photos within 500 meters
    private let faceDetectionService = FaceDetectionService()

    /// Request photo library authorization
    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    /// Fetch recent photos from the library with optional time range
    func fetchRecentPhotos(limit: Int = 100, timeRange: ScanTimeRange = .lastMonth) async -> [PHAsset] {
        let status = await requestAuthorization()
        guard status == .authorized || status == .limited else {
            return []
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = limit

        // Build predicate with time range
        if let startDate = timeRange.startDate {
            fetchOptions.predicate = NSPredicate(
                format: "mediaType == %d AND creationDate >= %@",
                PHAssetMediaType.image.rawValue,
                startDate as NSDate
            )
        } else {
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        }

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var result: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            result.append(asset)
        }

        return result
    }

    /// Fetch photos within a custom date range
    func fetchPhotos(from startDate: Date, to endDate: Date, limit: Int = 500) async -> [PHAsset] {
        let status = await requestAuthorization()
        guard status == .authorized || status == .limited else {
            return []
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = limit
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d AND creationDate >= %@ AND creationDate <= %@",
            PHAssetMediaType.image.rawValue,
            startDate as NSDate,
            endDate as NSDate
        )

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var result: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            result.append(asset)
        }

        return result
    }

    /// Count total photos in time range (without limit)
    func countPhotos(timeRange: ScanTimeRange) async -> Int {
        let status = await requestAuthorization()
        guard status == .authorized || status == .limited else {
            return 0
        }

        let fetchOptions = PHFetchOptions()

        if let startDate = timeRange.startDate {
            fetchOptions.predicate = NSPredicate(
                format: "mediaType == %d AND creationDate >= %@",
                PHAssetMediaType.image.rawValue,
                startDate as NSDate
            )
        } else {
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        }

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        return assets.count
    }

    /// Count total photos in custom date range (without limit)
    func countPhotos(from startDate: Date, to endDate: Date) async -> Int {
        let status = await requestAuthorization()
        guard status == .authorized || status == .limited else {
            return 0
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d AND creationDate >= %@ AND creationDate <= %@",
            PHAssetMediaType.image.rawValue,
            startDate as NSDate,
            endDate as NSDate
        )

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        return assets.count
    }

    /// Load image from PHAsset
    func loadImage(from asset: PHAsset, targetSize: CGSize? = nil) async -> UIImage? {
        let size = targetSize ?? AppSettings.shared.photoTargetSize
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    /// Load full resolution image data
    func loadImageData(from asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    /// Scan photos and filter those with faces
    func scanPhotosForFaces(
        assets: [PHAsset],
        progressHandler: @escaping (Int, Int) -> Void
    ) async -> [ScannedPhoto] {
        var results: [ScannedPhoto] = []

        for (index, asset) in assets.enumerated() {
            progressHandler(index + 1, assets.count)

            guard let image = await loadImage(from: asset) else {
                continue
            }

            do {
                let faces = try await faceDetectionService.detectFaces(in: image)

                if !faces.isEmpty {
                    let scannedPhoto = ScannedPhoto(
                        id: asset.localIdentifier,
                        asset: asset,
                        image: image,
                        detectedFaces: faces,
                        date: asset.creationDate ?? Date(),
                        location: asset.location
                    )
                    results.append(scannedPhoto)
                }
            } catch {
                print("Error detecting faces in asset \(asset.localIdentifier): \(error)")
            }
        }

        return results
    }

    /// Process a scanned photo and match faces to known people
    func matchFacesToPeople(
        in photo: ScannedPhoto,
        people: [Person],
        autoAcceptThreshold: Float? = nil
    ) async -> [FaceBoundingBox] {
        let threshold = autoAcceptThreshold ?? AppSettings.shared.autoAcceptThreshold
        let embeddingService = FaceEmbeddingService()
        let matchingService = FaceMatchingService()

        var boundingBoxes: [FaceBoundingBox] = []

        for face in photo.detectedFaces {
            do {
                let embedding = try await embeddingService.generateEmbedding(for: face.cropImage)
                let matches = matchingService.findMatches(for: embedding, in: people)

                var box = FaceBoundingBox(
                    rect: face.normalizedBoundingBox,
                    personId: nil,
                    personName: nil,
                    confidence: nil,
                    isAutoAccepted: false
                )

                if let topMatch = matches.first {
                    box.personId = topMatch.person.id
                    box.personName = topMatch.person.name
                    box.confidence = topMatch.similarity
                    box.isAutoAccepted = topMatch.similarity >= threshold
                }

                boundingBoxes.append(box)
            } catch {
                // Still add the bounding box without match info
                let box = FaceBoundingBox(
                    rect: face.normalizedBoundingBox,
                    personId: nil,
                    personName: nil,
                    confidence: nil,
                    isAutoAccepted: false
                )
                boundingBoxes.append(box)
            }
        }

        return boundingBoxes
    }

    /// Process detected faces and match to known people (for re-detection)
    func matchFacesToPeopleWithFaces(
        faces: [DetectedFace],
        people: [Person],
        autoAcceptThreshold: Float? = nil
    ) async -> [FaceBoundingBox] {
        let threshold = autoAcceptThreshold ?? AppSettings.shared.autoAcceptThreshold
        let embeddingService = FaceEmbeddingService()
        let matchingService = FaceMatchingService()

        var boundingBoxes: [FaceBoundingBox] = []

        for face in faces {
            do {
                let embedding = try await embeddingService.generateEmbedding(for: face.cropImage)
                let matches = matchingService.findMatches(for: embedding, in: people)

                var box = FaceBoundingBox(
                    rect: face.normalizedBoundingBox,
                    personId: nil,
                    personName: nil,
                    confidence: nil,
                    isAutoAccepted: false
                )

                if let topMatch = matches.first {
                    box.personId = topMatch.person.id
                    box.personName = topMatch.person.name
                    box.confidence = topMatch.similarity
                    box.isAutoAccepted = topMatch.similarity >= threshold
                }

                boundingBoxes.append(box)
            } catch {
                // Still add the bounding box without match info
                let box = FaceBoundingBox(
                    rect: face.normalizedBoundingBox,
                    personId: nil,
                    personName: nil,
                    confidence: nil,
                    isAutoAccepted: false
                )
                boundingBoxes.append(box)
            }
        }

        return boundingBoxes
    }

    /// Group scanned photos by time and location proximity
    func groupPhotosByEncounter(_ photos: [ScannedPhoto]) -> [PhotoGroup] {
        guard !photos.isEmpty else { return [] }

        // Sort by date
        let sorted = photos.sorted { $0.date < $1.date }

        var groups: [PhotoGroup] = []
        var currentGroup: [ScannedPhoto] = [sorted[0]]

        for i in 1..<sorted.count {
            let currentPhoto = sorted[i]
            let previousPhoto = sorted[i - 1]

            if shouldGroupTogether(currentPhoto, previousPhoto) {
                currentGroup.append(currentPhoto)
            } else {
                // Save current group and start new one
                groups.append(PhotoGroup(id: UUID(), photos: currentGroup))
                currentGroup = [currentPhoto]
            }
        }

        // Don't forget the last group
        if !currentGroup.isEmpty {
            groups.append(PhotoGroup(id: UUID(), photos: currentGroup))
        }

        return groups
    }

    /// Check if two photos should be grouped together
    private func shouldGroupTogether(_ photo1: ScannedPhoto, _ photo2: ScannedPhoto) -> Bool {
        // Check time proximity
        let timeDiff = abs(photo1.date.timeIntervalSince(photo2.date))
        let timeThreshold = timeThresholdMinutes * 60  // Convert to seconds

        if timeDiff > timeThreshold {
            return false
        }

        // If both have location, check distance
        if let loc1 = photo1.location, let loc2 = photo2.location {
            let distance = loc1.distance(from: loc2)
            if distance > distanceThresholdMeters {
                return false
            }
        }

        return true
    }

    /// Scan and group photos into encounters
    func scanAndGroupPhotos(
        assets: [PHAsset],
        progressHandler: @escaping (Int, Int) -> Void
    ) async -> [PhotoGroup] {
        let photos = await scanPhotosForFaces(assets: assets, progressHandler: progressHandler)
        return groupPhotosByEncounter(photos)
    }

    /// Scan and group photos with time range
    func scanAndGroupPhotos(
        timeRange: ScanTimeRange,
        limit: Int = 200,
        progressHandler: @escaping (Int, Int) -> Void
    ) async -> [PhotoGroup] {
        let assets = await fetchRecentPhotos(limit: limit, timeRange: timeRange)
        return await scanAndGroupPhotos(assets: assets, progressHandler: progressHandler)
    }

    /// Scan and group photos with custom date range
    func scanAndGroupPhotos(
        from startDate: Date,
        to endDate: Date,
        limit: Int = 500,
        progressHandler: @escaping (Int, Int) -> Void
    ) async -> [PhotoGroup] {
        let assets = await fetchPhotos(from: startDate, to: endDate, limit: limit)
        return await scanAndGroupPhotos(assets: assets, progressHandler: progressHandler)
    }

    /// Reverse geocode a location to get a place name
    func reverseGeocode(_ location: CLLocation) async -> String? {
        await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                if let placemark = placemarks?.first {
                    var components: [String] = []

                    // Prefer neighborhood or area name
                    if let subLocality = placemark.subLocality {
                        components.append(subLocality)
                    } else if let name = placemark.name, name != placemark.locality {
                        components.append(name)
                    }

                    // Add city
                    if let locality = placemark.locality, !components.contains(locality) {
                        components.append(locality)
                    }

                    continuation.resume(returning: components.isEmpty ? nil : components.joined(separator: ", "))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Reverse geocode locations for all photo groups
    func addLocationNames(to groups: [PhotoGroup]) async -> [PhotoGroup] {
        var updatedGroups = groups

        for i in 0..<updatedGroups.count {
            if let location = updatedGroups[i].location {
                let name = await reverseGeocode(location)
                updatedGroups[i].locationName = name
            }
        }

        return updatedGroups
    }
}
