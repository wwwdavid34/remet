# Profile Sharing via .remet File

**Goal:** Allow users to share a person's profile (name + face photo) with other Remet users via the standard iOS share sheet.

**Use case:** "I met someone interesting and want to share their face + name so my friend can recognize them too."

## File Format

The `.remet` file is a ZIP archive containing:

```
<person-name>.remet (zip)
├── profile.json    ← { "name": "Jane Doe", "version": 1 }
└── face.jpg        ← Profile face crop (JPEG, ~30-80KB)
```

- `profile.json` contains only `name` (String) and `version` (Int, currently 1) for future compatibility.
- `face.jpg` is the existing `faceCropData` from the person's profile embedding, exported as JPEG.
- Only name and profile face are shared. No contact info, notes, tags, encounters, or other private data.

## Export Flow (Sender)

1. On `PersonDetailView`, a share button (SF Symbol `square.and.arrow.up`) appears when the person has a profile face.
2. Tapping it creates a temporary `.remet` file in the system temp directory.
3. iOS share sheet (`UIActivityViewController`) is presented with the file.
4. Temporary file is cleaned up after sharing completes.

## Import Flow (Receiver)

1. Receiver taps the `.remet` file from iMessage, AirDrop, email, Files, etc.
2. iOS opens Remet (registered as handler for `.remet` UTI).
3. Remet shows a modal preview: face image + name + "Import" button.
4. Tapping Import:
   - Creates a `Person` with the name.
   - Runs face detection on the image via `FaceDetectionService`.
   - Generates a `FaceEmbedding` via `FaceEmbeddingService`.
   - Sets it as the profile embedding.
   - Initializes `SpacedRepetitionData`.
   - Saves to SwiftData.
5. Navigates to the newly created person's detail view.

## App Configuration

- Register a custom Uniform Type Identifier: `com.remet.profile` conforming to `public.data` and `public.content`.
- Register as Document Type handler for `.remet` files with the `com.remet.profile` UTI.
- Handle incoming files via `onOpenURL` in the app's root view or scene delegate.

## Decisions

- **Profile face only** (no embedding vectors) — the recipient's app regenerates the embedding from the face image on import.
- **Name only** (no contact info, notes, tags, etc.) — keeps sharing privacy-friendly.
- **No duplicate detection** — import always creates a new Person. Users can merge manually if needed.
- **Premium gating:** Not required for v1. Sharing is a growth mechanism.
