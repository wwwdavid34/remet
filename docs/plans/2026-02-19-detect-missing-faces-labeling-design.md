# Design: Detect Missing Faces in Encounter Labeling

**Issue:** #4 — Missing "Detect missing faces" in encounter labeling
**Branch:** `feat/4-detect-missing-faces-labeling`
**Date:** 2026-02-19

## Problem

The "Missing faces?" tap-to-detect feature exists in QuickCaptureView and EncounterGroupReviewView, but is absent from EncounterReviewView (single-photo import). The "Re-detect" button in EncounterReviewView rarely changes outcomes and should be replaced.

## Scope

Modify `EncounterReviewView` to:

1. **Add "Missing?" locate-face mode** — user taps photo to detect a face in that region
2. **Add pinch-to-zoom** — zoomable photo for precise tap targeting
3. **Remove "Re-detect"** — replace with "Missing?" in all locations (header and empty state)

## Design

### State Changes

**Add:**
- `locateFaceMode: Bool` — toggles tap-to-detect mode
- `locateFaceError: String?` — error message from detection
- `isLocatingFace: Bool` — loading spinner during detection
- `lastAddedFaceIndex: Int?` — tracks last manually added face for undo

**Remove:**
- `isRedetecting: Bool`
- `redetectAttempts: Int`
- `redetectFaces()` method

### Zoomable Photo

Wrap the photo in a zoomable container supporting:
- `MagnifyGesture` for pinch-to-zoom (1x–5x range)
- `DragGesture` for panning when zoomed
- Double-tap to reset zoom
- Face bounding box overlays scale with zoom
- Tap gesture in `locateFaceMode` adjusts for zoom/pan offset

### UI Changes

**Header (facesSection):**
- Replace "Re-detect" button with "Missing?" toggle
- When active: shows "Cancel" with coral color
- Loading spinner during detection

**Locate-face banner:**
- Coral background banner: "Tap where you see a face in the photo"
- Shows error text if detection fails
- Displayed above face list when `locateFaceMode` is active

**Empty state (no faces detected):**
- Replace "Re-detect Faces" / "Try Again" with "Missing?" button
- Same tap-to-detect flow

### handleLocateFaceTap()

Ported from QuickCaptureView, adapted for EncounterReviewView:

1. Convert tap location to image coordinates (accounting for zoom/pan)
2. Crop 40% region around tap point
3. Run `FaceDetectionService.detectFaces(in:options:.enhanced)`
4. Transform detected face bbox back to original image space
5. Create `FaceBoundingBox` (unlabeled, not auto-accepted)
6. Append to `boundingBoxes`
7. Extract face crop, load match suggestions, show person picker
8. Exit locate-face mode on success

### Reference Implementations

- QuickCaptureView: `handleLocateFaceTap()` at line 813, "Missing?" button at line 659
- EncounterEditView: `handleLocateFaceTap()` at line 805
- EncounterGroupReviewView: locate face mode at line 639

### Data Flow

```
User taps "Missing?" → locateFaceMode = true
User taps photo → handleLocateFaceTap()
  → Crop region → FaceDetectionService.detectFaces(.enhanced)
  → Create FaceBoundingBox → append to boundingBoxes
  → Extract face crop → FaceMatchingService.findMatches()
  → Show person picker → user assigns person
  → addEmbeddingToPerson() → propagateLabelToSimilarFaces()
```
