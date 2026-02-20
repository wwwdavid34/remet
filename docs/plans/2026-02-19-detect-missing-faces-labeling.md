# Detect Missing Faces in Encounter Labeling — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add tap-to-detect "Missing faces?" mode and pinch-to-zoom to EncounterReviewView, replacing the ineffective Re-detect button.

**Architecture:** Modify EncounterReviewView in-place. Add locate-face state, port handleLocateFaceTap() from QuickCaptureView (adapted for FaceBoundingBox data model), wrap photo in zoomable container with MagnifyGesture + DragGesture, and replace all Re-detect UI with "Missing?" toggle.

**Tech Stack:** SwiftUI, Vision framework (via FaceDetectionService), SwiftData

---

### Task 1: Add locate-face state and remove re-detect state

**Files:**
- Modify: `Remet/Views/Encounters/EncounterReviewView.swift:13-40` (state declarations)

**Step 1: Replace state variables**

Remove these lines:
```swift
@State private var isRedetecting = false
@State private var redetectAttempts = 0
```

Add these in the same region:
```swift
// Locate face mode
@State private var locateFaceMode = false
@State private var locateFaceError: String?
@State private var isLocatingFace = false
@State private var lastAddedFaceIndex: Int?
```

**Step 2: Remove `redetectFaces()` method**

Delete the entire `redetectFaces()` method at lines 531-574.

**Step 3: Build to verify**

Run: `xcodebuild -scheme Remet -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`

Expected: Build errors for remaining references to `isRedetecting`, `redetectAttempts`, `redetectFaces()`. These are fixed in Task 2.

**Step 4: Commit**

```bash
git add Remet/Views/Encounters/EncounterReviewView.swift
git commit -m "feat(#4): replace re-detect state with locate-face state in EncounterReviewView"
```

---

### Task 2: Replace Re-detect UI with "Missing?" button

**Files:**
- Modify: `Remet/Views/Encounters/EncounterReviewView.swift:110-196` (facesSection)

**Step 1: Replace header button**

Replace the header Re-detect button (lines 118-130):
```swift
// Re-detect button
if !isProcessing && !isRedetecting {
    Button {
        redetectFaces()
    } label: {
        HStack(spacing: 4) {
            Image(systemName: "arrow.clockwise")
            Text("Re-detect")
        }
        .font(.caption)
        .foregroundStyle(AppColors.teal)
    }
}
```

With:
```swift
// Missing faces button
if !isProcessing {
    Button {
        locateFaceMode.toggle()
        if !locateFaceMode {
            locateFaceError = nil
        }
    } label: {
        HStack(spacing: 4) {
            if isLocatingFace {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Image(systemName: locateFaceMode ? "xmark.circle" : "person.crop.rectangle")
            }
            Text(locateFaceMode ? "Cancel" : "Missing?")
        }
        .font(.caption)
        .foregroundStyle(locateFaceMode ? AppColors.coral : AppColors.teal)
    }
    .disabled(isLocatingFace)
}
```

**Step 2: Replace processing/empty state**

Replace the `if isProcessing || isRedetecting` block (lines 133-175):
```swift
if isProcessing || isRedetecting {
    HStack {
        ProgressView()
        Text(isRedetecting ? "Re-analyzing faces..." : "Analyzing faces...")
            .foregroundStyle(AppColors.textSecondary)
    }
} else if boundingBoxes.isEmpty {
    // No faces detected state
    VStack(spacing: 12) {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(AppColors.warning)
            Text("No faces detected")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.warning)
        }

        Text("Try re-detecting with enhanced image processing.")
            .font(.caption)
            .foregroundStyle(AppColors.textSecondary)
            .multilineTextAlignment(.center)

        Button {
            redetectFaces()
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text(redetectAttempts == 0 ? "Re-detect Faces" : "Try Again")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppColors.teal)
            .clipShape(Capsule())
        }
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(AppColors.warning.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 12))
```

With:
```swift
if isProcessing {
    HStack {
        ProgressView()
        Text("Analyzing faces...")
            .foregroundStyle(AppColors.textSecondary)
    }
} else if boundingBoxes.isEmpty {
    // No faces detected — prompt to use locate mode
    VStack(spacing: 12) {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(AppColors.warning)
            Text("No faces detected")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.warning)
        }

        Text("Tap \"Missing?\" above then tap a face in the photo.")
            .font(.caption)
            .foregroundStyle(AppColors.textSecondary)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(AppColors.warning.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 12))
```

**Step 3: Add locate-face-mode banner**

Insert this `locateFaceModeIndicator` ViewBuilder right after the `} else {` on the faces list branch (before the `ForEach(Array(boundingBoxes.enumerated())...`), so it shows above the face rows:

Add this before `} else {` → `ForEach`:
```swift
} else {
    if locateFaceMode {
        locateFaceModeIndicator
    }

    ForEach(Array(boundingBoxes.enumerated()), id: \.element.id) { index, box in
```

And add this computed property to the view:
```swift
@ViewBuilder
private var locateFaceModeIndicator: some View {
    VStack(spacing: 4) {
        HStack(spacing: 6) {
            Image(systemName: "hand.tap")
            Text("Tap where you see a face in the photo")
        }
        .font(.caption)
        .fontWeight(.medium)
        .foregroundStyle(AppColors.coral)

        if let error = locateFaceError {
            Text(error)
                .font(.caption2)
                .foregroundStyle(AppColors.warning)
        }
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(AppColors.coral.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
}
```

Also show the indicator in the empty state — add it after the warning card:
```swift
} else if boundingBoxes.isEmpty {
    // ... existing warning card ...

    if locateFaceMode {
        locateFaceModeIndicator
    }
```

**Step 4: Build to verify**

Run: `xcodebuild -scheme Remet -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: **BUILD SUCCEEDED**

**Step 5: Commit**

```bash
git add Remet/Views/Encounters/EncounterReviewView.swift
git commit -m "feat(#4): replace Re-detect with Missing? button and locate-face banner"
```

---

### Task 3: Add pinch-to-zoom on the photo

**Files:**
- Modify: `Remet/Views/Encounters/EncounterReviewView.swift:81-108` (photoWithOverlays)

**Step 1: Add zoom/pan state**

Add to the state declarations:
```swift
// Zoom state
@State private var zoomScale: CGFloat = 1.0
@State private var lastZoomScale: CGFloat = 1.0
@State private var zoomOffset: CGSize = .zero
@State private var lastDragOffset: CGSize = .zero
```

**Step 2: Replace `photoWithOverlays` with zoomable version**

Replace the entire `photoWithOverlays` computed property with:

```swift
@ViewBuilder
private var photoWithOverlays: some View {
    GeometryReader { geometry in
        ZStack {
            if let image = scannedPhoto.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        ForEach(Array(boundingBoxes.enumerated()), id: \.element.id) { index, box in
                            FaceBoundingBoxOverlay(
                                box: box,
                                isSelected: selectedBoxIndex == index,
                                imageSize: image.size,
                                viewSize: geometry.size
                            )
                            .onTapGesture {
                                if !locateFaceMode {
                                    selectedBoxIndex = index
                                    showPersonPicker = true
                                }
                            }
                        }
                        .allowsHitTesting(!locateFaceMode)
                    }
                    .scaleEffect(zoomScale)
                    .offset(zoomOffset)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                let newScale = lastZoomScale * value.magnification
                                zoomScale = min(max(newScale, 1.0), 5.0)
                            }
                            .onEnded { value in
                                lastZoomScale = zoomScale
                                if zoomScale <= 1.0 {
                                    withAnimation(.spring(duration: 0.3)) {
                                        zoomOffset = .zero
                                        lastDragOffset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        zoomScale > 1.0 ?
                        DragGesture()
                            .onChanged { value in
                                zoomOffset = CGSize(
                                    width: lastDragOffset.width + value.translation.width,
                                    height: lastDragOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastDragOffset = zoomOffset
                            }
                        : nil
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(duration: 0.3)) {
                            zoomScale = 1.0
                            lastZoomScale = 1.0
                            zoomOffset = .zero
                            lastDragOffset = .zero
                        }
                    }
                    .onTapGesture { location in
                        if locateFaceMode {
                            // Adjust tap location for zoom/pan
                            let adjustedLocation = CGPoint(
                                x: (location.x - zoomOffset.width) / zoomScale,
                                y: (location.y - zoomOffset.height) / zoomScale
                            )
                            handleLocateFaceTap(
                                at: adjustedLocation,
                                in: geometry.size,
                                imageSize: image.size
                            )
                        }
                    }
            }
        }
    }
    .aspectRatio(scannedPhoto.image?.size ?? CGSize(width: 1, height: 1), contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 12))
}
```

**Step 3: Build to verify**

Run: `xcodebuild -scheme Remet -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: Build error for missing `handleLocateFaceTap` — added in Task 4.

**Step 4: Commit**

```bash
git add Remet/Views/Encounters/EncounterReviewView.swift
git commit -m "feat(#4): add pinch-to-zoom and pan on photo with adjusted tap coordinates"
```

---

### Task 4: Implement handleLocateFaceTap()

**Files:**
- Modify: `Remet/Views/Encounters/EncounterReviewView.swift` (add method)

**Step 1: Add handleLocateFaceTap method**

Add this method after the `loadFaceCropAndMatches()` method (around line 490). Ported from QuickCaptureView, adapted to produce `FaceBoundingBox` and trigger person picker:

```swift
private func handleLocateFaceTap(at tapLocation: CGPoint, in viewSize: CGSize, imageSize: CGSize) {
    guard let image = scannedPhoto.image else { return }
    isLocatingFace = true
    locateFaceError = nil

    Task {
        do {
            let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
            let scaledWidth = imageSize.width * scale
            let scaledHeight = imageSize.height * scale
            let offsetX = (viewSize.width - scaledWidth) / 2
            let offsetY = (viewSize.height - scaledHeight) / 2

            let imageX = (tapLocation.x - offsetX) / scale
            let imageY = (tapLocation.y - offsetY) / scale

            let cropSize = min(imageSize.width, imageSize.height) * 0.4
            let cropRect = CGRect(
                x: max(0, imageX - cropSize / 2),
                y: max(0, imageY - cropSize / 2),
                width: min(cropSize, imageSize.width - max(0, imageX - cropSize / 2)),
                height: min(cropSize, imageSize.height - max(0, imageY - cropSize / 2))
            )

            guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
                await MainActor.run {
                    locateFaceError = "Could not crop image region"
                    isLocatingFace = false
                }
                return
            }
            let croppedImage = UIImage(cgImage: cgImage)

            let faces = try await faceDetectionService.detectFaces(in: croppedImage, options: .enhanced)

            if let face = faces.first {
                // Transform bbox from crop space to original image space
                let cropNormRect = face.normalizedBoundingBox
                let originalX = (cropRect.origin.x + cropNormRect.origin.x * cropRect.width) / imageSize.width
                let originalWidth = (cropNormRect.width * cropRect.width) / imageSize.width
                let cropBottomNorm = 1.0 - (cropRect.origin.y + cropRect.height) / imageSize.height
                let cropHeightNorm = cropRect.height / imageSize.height
                let originalY = cropBottomNorm + cropNormRect.origin.y * cropHeightNorm
                let originalHeight = cropNormRect.height * cropHeightNorm

                let translatedNormRect = CGRect(
                    x: originalX, y: originalY,
                    width: originalWidth, height: originalHeight
                )

                let newBox = FaceBoundingBox(
                    rect: translatedNormRect,
                    personId: nil,
                    personName: nil,
                    confidence: nil,
                    isAutoAccepted: false
                )

                // Create a DetectedFace for match loading
                let translatedPixelRect = CGRect(
                    x: originalX * imageSize.width,
                    y: (1.0 - originalY - originalHeight) * imageSize.height,
                    width: originalWidth * imageSize.width,
                    height: originalHeight * imageSize.height
                )
                let newDetectedFace = DetectedFace(
                    boundingBox: translatedPixelRect,
                    cropImage: face.cropImage,
                    normalizedBoundingBox: translatedNormRect
                )

                await MainActor.run {
                    boundingBoxes.append(newBox)
                    localDetectedFaces.append(newDetectedFace)
                    let newIndex = boundingBoxes.count - 1
                    lastAddedFaceIndex = newIndex
                    locateFaceMode = false
                    isLocatingFace = false

                    // Immediately open person picker for the new face
                    selectedBoxIndex = newIndex
                    loadFaceCropAndMatches()
                    showPersonPicker = true
                }
            } else {
                await MainActor.run {
                    locateFaceError = "No face found at that location"
                    isLocatingFace = false
                }
            }
        } catch {
            await MainActor.run {
                locateFaceError = "Detection failed: \(error.localizedDescription)"
                isLocatingFace = false
            }
        }
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -scheme Remet -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: **BUILD SUCCEEDED**

**Step 3: Commit**

```bash
git add Remet/Views/Encounters/EncounterReviewView.swift
git commit -m "feat(#4): implement handleLocateFaceTap for manual face detection in region"
```

---

### Task 5: Final verification and cleanup

**Files:**
- Verify: `Remet/Views/Encounters/EncounterReviewView.swift`

**Step 1: Run full test suite**

Run: `xcodebuild test -scheme Remet -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -15`
Expected: All tests pass.

**Step 2: Verify no remaining references to removed code**

Search for: `isRedetecting`, `redetectAttempts`, `redetectFaces` in EncounterReviewView.swift.
Expected: Zero matches.

**Step 3: Verify locate-face state is used**

Search for: `locateFaceMode`, `handleLocateFaceTap`, `isLocatingFace` in EncounterReviewView.swift.
Expected: Multiple matches — state declared, toggled in button, checked in tap gesture, used in banner.

**Step 4: Final commit if any cleanup needed**

```bash
git add -A && git commit -m "feat(#4): cleanup and finalize detect-missing-faces in labeling"
```
