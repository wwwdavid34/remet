import SwiftUI
import SwiftData
import Photos

struct EncounterScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var people: [Person]

    @State private var isScanning = false
    @State private var scanProgress = 0
    @State private var scanTotal = 0
    @State private var photoGroups: [PhotoGroup] = []
    @State private var selectedGroup: PhotoGroup?

    // Time range selection
    @State private var selectedTimeRange: ScanTimeRange = .lastWeek
    @State private var useCustomDateRange = false
    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate = Date()
    @State private var photoLimit = 200

    // Limit reached notification
    @State private var showLimitReachedAlert = false
    @State private var totalPhotosInRange = 0
    @State private var scannedPhotosCount = 0

    // Track scanned assets to allow continuation
    @State private var scannedAssetIds: Set<String> = []
    @State private var previouslyScannedCount = 0

    // Group selection for merge
    @State private var isGroupSelectMode = false
    @State private var selectedGroupIds: Set<UUID> = []

    // Alert for already-imported group
    @State private var showAlreadyImportedAlert = false

    private let scannerService = PhotoLibraryScannerService()

    var body: some View {
        NavigationStack {
            Group {
                if isScanning {
                    scanningView
                } else if photoGroups.isEmpty {
                    emptyStateView
                } else {
                    groupedPhotosGrid
                }
            }
            .navigationTitle("Scan Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if !isGroupSelectMode {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }

                if !isScanning && !photoGroups.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        if photoGroups.count >= 2 {
                            Button {
                                withAnimation {
                                    isGroupSelectMode.toggle()
                                    if !isGroupSelectMode {
                                        selectedGroupIds.removeAll()
                                    }
                                }
                            } label: {
                                Text(isGroupSelectMode ? "Cancel" : "Select")
                            }
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        if !isGroupSelectMode {
                            Menu {
                                Button {
                                    startScan()
                                } label: {
                                    Label("Rescan", systemImage: "arrow.clockwise")
                                }

                                Button {
                                    photoGroups = []
                                } label: {
                                    Label("Change Settings", systemImage: "slider.horizontal.3")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedGroup) { group in
                EncounterGroupReviewView(
                    photoGroup: group,
                    people: people
                ) { encounter in
                    modelContext.insert(encounter)
                    // Remove processed group and strip saved photos from remaining groups
                    photoGroups.removeAll { $0.id == group.id }
                    stripImportedPhotosFromGroups()
                    selectedGroup = nil
                }
            }
            .alert("Already Imported", isPresented: $showAlreadyImportedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("All photos in this group have already been imported.")
            }
            .alert("Photo Limit Reached", isPresented: $showLimitReachedAlert) {
                let remainingPhotos = totalPhotosInRange - scannedPhotosCount
                let additionalToScan = min(remainingPhotos, 200)
                Button("Scan \(additionalToScan) More Photos") {
                    // Continue scanning from where we left off
                    continueScan(additionalCount: additionalToScan)
                }
                Button("Keep Current Results", role: .cancel) {}
            } message: {
                Text("Scanned \(scannedPhotosCount) of \(totalPhotosInRange) photos. Continue scanning more?")
            }
        }
    }

    @ViewBuilder
    private var scanningView: some View {
        VStack(spacing: 24) {
            // Native scanning animation
            ScanningAnimationView(tintColor: AppColors.teal)
                .frame(width: 120, height: 120)

            Text("Scanning photos...")
                .font(.headline)

            if scanTotal > 0 {
                Text("\(scanProgress) of \(scanTotal)")
                    .foregroundStyle(.secondary)

                ProgressView(value: Double(scanProgress), total: Double(scanTotal))
                    .padding(.horizontal, 40)
                    .tint(AppColors.teal)
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("Scan Photos")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Find photos with faces and group them into encounters")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // Time Range Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Time Range")
                        .font(.headline)

                    if useCustomDateRange {
                        // Custom date range pickers
                        VStack(spacing: 12) {
                            DatePicker(
                                "From",
                                selection: $customStartDate,
                                in: ...customEndDate,
                                displayedComponents: .date
                            )

                            DatePicker(
                                "To",
                                selection: $customEndDate,
                                in: customStartDate...,
                                displayedComponents: .date
                            )
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button("Use Preset Range") {
                            useCustomDateRange = false
                        }
                        .font(.subheadline)
                    } else {
                        // Preset time range picker
                        Picker("Time Range", selection: $selectedTimeRange) {
                            ForEach(ScanTimeRange.allCases) { range in
                                Text(range.localizedName).tag(range)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button("Use Custom Date Range") {
                            useCustomDateRange = true
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.horizontal)

                // Photo Limit
                VStack(alignment: .leading, spacing: 8) {
                    Text("Photo Limit")
                        .font(.headline)

                    HStack {
                        Text("\(photoLimit) photos max")
                            .foregroundStyle(.secondary)

                        Spacer()

                        Stepper("", value: $photoLimit, in: 50...2000, step: 50)
                            .labelsHidden()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("Higher limits may take longer to scan")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal)

                // Scan Button
                Button {
                    startScan()
                } label: {
                    Label("Start Scan", systemImage: "magnifyingglass")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private var groupedPhotosGrid: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(photoGroups) { group in
                    if isGroupSelectMode {
                        Button {
                            toggleGroupSelection(group.id)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: selectedGroupIds.contains(group.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedGroupIds.contains(group.id) ? AppColors.teal : .secondary)
                                    .font(.title3)
                                    .padding(.top, 4)

                                GroupThumbnailCard(group: group)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        GroupThumbnailCard(group: group)
                            .onTapGesture {
                                openGroupForReview(group)
                            }
                    }
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                if isGroupSelectMode && selectedGroupIds.count >= 2 {
                    groupMergeBar
                }

                if scannedPhotosCount < totalPhotosInRange && scannedPhotosCount >= photoLimit {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Showing \(scannedPhotosCount) of \(totalPhotosInRange) photos")
                    }
                    .font(.caption)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }

                if !isGroupSelectMode {
                    Text("\(photoGroups.count) potential encounters found")
                        .font(.caption)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 8)
        }
    }

    private func toggleGroupSelection(_ id: UUID) {
        if selectedGroupIds.contains(id) {
            selectedGroupIds.remove(id)
        } else {
            selectedGroupIds.insert(id)
        }
    }

    @ViewBuilder
    private var groupMergeBar: some View {
        Button {
            mergeSelectedGroups()
        } label: {
            HStack {
                Image(systemName: "arrow.triangle.merge")
                Text("Merge \(selectedGroupIds.count) Groups")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppColors.teal)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
    }

    private func mergeSelectedGroups() {
        let groupsToMerge = photoGroups
            .filter { selectedGroupIds.contains($0.id) }
            .sorted { $0.date < $1.date }

        guard groupsToMerge.count >= 2 else { return }

        // Combine all photos, sorted by date
        let combinedPhotos = groupsToMerge
            .flatMap { $0.photos }
            .sorted { $0.date < $1.date }

        // Take location from earliest group that has one
        let locationName = groupsToMerge.first(where: { $0.locationName != nil })?.locationName

        let mergedGroup = PhotoGroup(
            id: UUID(),
            photos: combinedPhotos,
            locationName: locationName
        )

        // Replace selected groups with merged group
        photoGroups.removeAll { selectedGroupIds.contains($0.id) }
        photoGroups.append(mergedGroup)
        photoGroups.sort { $0.date > $1.date }

        // Exit selection mode
        withAnimation {
            selectedGroupIds.removeAll()
            isGroupSelectMode = false
        }
    }

    /// Fetch asset identifiers already imported into encounters
    private func fetchImportedAssetIds() -> Set<String> {
        let descriptor = FetchDescriptor<EncounterPhoto>()
        guard let photos = try? modelContext.fetch(descriptor) else { return [] }
        return Set(photos.compactMap { $0.assetIdentifier })
    }

    /// Filter a group's photos against the DB before showing the review sheet.
    /// If all photos are already imported, removes the group and shows an alert.
    private func openGroupForReview(_ group: PhotoGroup) {
        let importedIds = fetchImportedAssetIds()
        let freshPhotos = group.photos.filter { !importedIds.contains($0.id) }

        if freshPhotos.isEmpty {
            // All photos already imported — remove stale group
            photoGroups.removeAll { $0.id == group.id }
            showAlreadyImportedAlert = true
        } else if freshPhotos.count < group.photos.count {
            // Some photos already imported — open with filtered group
            var filtered = group
            filtered.photos = freshPhotos
            selectedGroup = filtered
        } else {
            selectedGroup = group
        }
    }

    /// After saving a group, strip any now-imported photos from remaining groups
    /// and remove groups that become empty.
    private func stripImportedPhotosFromGroups() {
        let importedIds = fetchImportedAssetIds()
        photoGroups = photoGroups.compactMap { group in
            let remaining = group.photos.filter { !importedIds.contains($0.id) }
            if remaining.isEmpty { return nil }
            if remaining.count == group.photos.count { return group }
            var updated = group
            updated.photos = remaining
            return updated
        }
    }

    private func startScan() {
        isScanning = true
        scanProgress = 0
        totalPhotosInRange = 0
        scannedPhotosCount = 0
        scannedAssetIds = []
        previouslyScannedCount = 0

        let importedIds = fetchImportedAssetIds()

        Task {
            let groups: [PhotoGroup]
            var scannedIds: [String] = []

            if useCustomDateRange {
                // Count total photos in range first
                let totalCount = await scannerService.countPhotos(from: customStartDate, to: customEndDate)

                // Use custom date range
                let allAssets = await scannerService.fetchPhotos(
                    from: customStartDate,
                    to: customEndDate,
                    limit: photoLimit
                )
                // Filter out photos already used in encounters
                let assets = allAssets.filter { !importedIds.contains($0.localIdentifier) }
                scanTotal = assets.count
                scannedIds = allAssets.map { $0.localIdentifier }

                await MainActor.run {
                    totalPhotosInRange = totalCount - importedIds.count
                    scannedPhotosCount = assets.count
                }

                groups = await scannerService.scanAndGroupPhotos(assets: assets) { current, total in
                    Task { @MainActor in
                        scanProgress = current
                    }
                }
            } else {
                // Count total photos in range first
                let totalCount = await scannerService.countPhotos(timeRange: selectedTimeRange)

                // Use preset time range
                let allAssets = await scannerService.fetchRecentPhotos(
                    limit: photoLimit,
                    timeRange: selectedTimeRange
                )
                // Filter out photos already used in encounters
                let assets = allAssets.filter { !importedIds.contains($0.localIdentifier) }
                scanTotal = assets.count
                scannedIds = allAssets.map { $0.localIdentifier }

                await MainActor.run {
                    totalPhotosInRange = totalCount - importedIds.count
                    scannedPhotosCount = assets.count
                }

                groups = await scannerService.scanAndGroupPhotos(assets: assets) { current, total in
                    Task { @MainActor in
                        scanProgress = current
                    }
                }
            }

            // Add location names via reverse geocoding
            let groupsWithLocations = await scannerService.addLocationNames(to: groups)

            await MainActor.run {
                photoGroups = groupsWithLocations
                scannedAssetIds = Set(scannedIds)
                isScanning = false

                // Show alert if limit was reached
                if scannedPhotosCount < totalPhotosInRange {
                    showLimitReachedAlert = true
                }
            }
        }
    }

    private func continueScan(additionalCount: Int) {
        isScanning = true
        previouslyScannedCount = scannedPhotosCount
        scanProgress = 0

        let importedIds = fetchImportedAssetIds()

        Task {
            // Fetch more photos, skipping already scanned and already imported ones
            let newLimit = scannedPhotosCount + additionalCount
            var newAssets: [PHAsset] = []
            var scannedIds: [String] = []

            if useCustomDateRange {
                let allAssets = await scannerService.fetchPhotos(
                    from: customStartDate,
                    to: customEndDate,
                    limit: newLimit
                )
                // Filter out already scanned and already imported assets
                newAssets = allAssets.filter {
                    !scannedAssetIds.contains($0.localIdentifier) &&
                    !importedIds.contains($0.localIdentifier)
                }
                scannedIds = allAssets.map { $0.localIdentifier }
            } else {
                let allAssets = await scannerService.fetchRecentPhotos(
                    limit: newLimit,
                    timeRange: selectedTimeRange
                )
                // Filter out already scanned and already imported assets
                newAssets = allAssets.filter {
                    !scannedAssetIds.contains($0.localIdentifier) &&
                    !importedIds.contains($0.localIdentifier)
                }
                scannedIds = allAssets.map { $0.localIdentifier }
            }

            scanTotal = newAssets.count

            await MainActor.run {
                scannedPhotosCount = previouslyScannedCount + newAssets.count
            }

            // Scan only the new photos
            var newGroups = await scannerService.scanAndGroupPhotos(assets: newAssets) { current, total in
                Task { @MainActor in
                    scanProgress = current
                }
            }

            // Add location names via reverse geocoding
            newGroups = await scannerService.addLocationNames(to: newGroups)

            await MainActor.run {
                // Merge new groups with existing ones
                mergePhotoGroups(newGroups)
                scannedAssetIds = Set(scannedIds)
                isScanning = false

                // Show alert if still more photos to scan
                if scannedPhotosCount < totalPhotosInRange {
                    showLimitReachedAlert = true
                }
            }
        }
    }

    private func mergePhotoGroups(_ newGroups: [PhotoGroup]) {
        // For now, simply append new groups
        // In future, could merge groups that are close in time/location
        photoGroups.append(contentsOf: newGroups)

        // Sort all groups by date
        photoGroups.sort { $0.date > $1.date }
    }
}

struct GroupThumbnailCard: View {
    let group: PhotoGroup

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Photo grid preview (up to 6 photos)
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(group.photos.prefix(6).enumerated()), id: \.element.id) { index, photo in
                    Group {
                        if let image = photo.image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 80)
                                .clipped()
                                .overlay {
                                    if index == 5 && group.photos.count > 6 {
                                        Color.black.opacity(0.5)
                                        Text("+\(group.photos.count - 6)")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                }
                        } else {
                            // Placeholder for loading photos (e.g., from iCloud)
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 80)
                                .overlay {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Group info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)

                    Text(group.dateRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let locationName = group.locationName {
                        Label(locationName, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Stats
                HStack(spacing: 12) {
                    Label("\(group.photos.count)", systemImage: "photo")
                    Label("\(group.totalFaces)", systemImage: "person.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    EncounterScannerView()
}
