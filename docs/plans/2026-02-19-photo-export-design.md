# Photo Export — Design

## Goal

Allow users to export encounter photos to other apps via the standard iOS share sheet.

## Placement

1. **EncounterDetailView** — "Share Photo" in the ellipsis menu (shares currently visible carousel photo)
2. **FullPhotoView / MultiPhotoFullView** — Share button in toolbar

## Implementation

- `ShareSheet`: a `UIViewControllerRepresentable` wrapping `UIActivityViewController`
- Activity item: `UIImage(data: photo.imageData)`
- Presented as `.sheet(isPresented:)` triggered by `@State` flag

## Files

| File | Change |
|------|--------|
| New: `Remet/Views/Components/ShareSheet.swift` | UIActivityViewController wrapper |
| Modify: `Remet/Views/Encounters/EncounterDetailView.swift` | Add "Share Photo" to ellipsis menu |
| Modify: Full-screen photo view files | Add share toolbar button |
