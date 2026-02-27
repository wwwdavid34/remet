# Changelog

## [1.2] - 2026-02-27

### Added
- **Multi-photo import**: In-app photo picker now supports selecting up to 10 photos at once, grouped into a single encounter
- **Multi-photo sharing**: Photos shared via iOS Share Sheet are now batched into a single encounter instead of processed one-at-a-time
- **"Open Map" link**: Encounter review now shows a clickable Apple Maps link next to location coordinates
- **"New face" indicator**: Newly created persons now appear in the "People in this encounter" summary with a green "New face" label, confirming successful labeling
- **Onboarding intro screen**: Added an intro screen before encounter review during onboarding explaining how to tag faces
- 10 unit tests for PhotoImportViewModel covering routing, dedup, shared images, and reset

### Changed
- **Unified encounter review**: All encounter creation (single or multi-photo) now uses `EncounterGroupReviewView` for a consistent experience
- Onboarding first memory flow now reuses the same encounter review as normal import
- Onboarding skips live scan demo, going straight to photo import

### Removed
- Deleted `EncounterReviewView` (1203 lines) — replaced by unified `EncounterGroupReviewView`

### Fixed
- Newly created persons were invisible in the people summary after labeling a face (they had a `personId` but weren't in the query results)
- Photos with face detection errors were silently dropped instead of included with empty face arrays
- App Store validation warning about missing `LSSupportsOpeningDocumentsInPlace`

## [1.1.1] - 2026-02-21

### Added
- Share people profiles via `.remet` files (#32)
- Share Extension for importing photos from other apps
- Photo export via share sheet
- Pinch-to-zoom and "Missing?" button for manual face detection (#4)
- "Set as Contact Photo" button for linked contacts
- Per-app language setting support via `InfoPlist.xcstrings`
- `EmbeddingIntegrityService` to detect and remove orphaned embeddings
- Onboarding i18n translations for ja, zh-Hans, zh-Hant
- Regression tests for contact photo export and profile thumbnail

### Fixed
- Contact link state not immediately updating (#31)
- Unresponsive End button in practice session complete view
- Quiz result message and face image jumping on re-render
- Person not added to encounter during face propagation
- Profile thumbnail not updating in list views
- Incorrect Chinese translation for "No faces detected"
- Promo code redemption not refreshing subscription state immediately
- Pan lag and 500ms zoom delay caused by ScrollView gesture conflict
