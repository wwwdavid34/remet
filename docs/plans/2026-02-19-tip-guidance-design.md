# Tip Guidance After Onboarding — Design

## Goal

Add popover tip guidance for first-time users across 5 areas of the app using Apple's TipKit framework (iOS 17+).

## Framework

**TipKit** — native iOS 17+ framework. No third-party dependencies.

## Tip Set (11 tips)

### 1. Main View (HomeView)
| Target | Title | Message |
|--------|-------|---------|
| "New Face" button | Scan a New Face | Tap to capture and remember someone new |
| "Practice" button | Test Your Memory | Quiz yourself on the faces you've learned |
| Add (+) tab | Add an Encounter | Capture from camera or import from photo library |

### 2. Practice View (PracticeHomeView)
| Target | Title | Message |
|--------|-------|---------|
| "Spaced Review" row | Spaced Review | Review faces that are due for practice |
| "Set Filters" row | Customize Your Quiz | Filter by favorites, tags, or relationship |

### 3. Identify View (ScanTabView)
| Target | Title | Message |
|--------|-------|---------|
| "Live Camera Scan" button | Live Scan | Point your camera at someone to identify them |
| "Match from Photo" button | Match from Photo | Identify faces in an existing photo |

### 4. Labeling (EncounterReviewView)
| Target | Title | Message |
|--------|-------|---------|
| Face bounding box (first one) | Label This Face | Tap a face box to assign a name |
| "Missing?" button | Missing a Face? | Tap to manually locate an undetected face |

### 5. Person Profile (PersonDetailView)
| Target | Title | Message |
|--------|-------|---------|
| Star button | Favorite | Mark as favorite for quick access |
| Ellipsis menu | More Actions | Edit details, merge duplicates, or delete |

## Architecture

- **One file** `Remet/Tips/RemetTips.swift` containing all tip structs and events
- Each tip conforms to `Tip` protocol with title, message, image, and rules
- Each tip has a corresponding `Tips.Event` for auto-invalidation
- Tips are configured in `RemetApp.swift` via `Tips.configure([.displayFrequency(.immediate)])`

## Display Style

All tips use `.popoverTip()` modifier — popover with arrow pointing at the target button.

## Dismissal

- **Auto-invalidate**: each tip disappears permanently once the user performs the associated action (event donation)
- **Manual dismiss**: user can tap X on any tip to dismiss early
- TipKit persists state across launches via its built-in `Tips.Status` storage

## Integration

Each target view receives:
1. `.popoverTip(SomeTip())` on the specific button/view
2. Event donation (`SomeTip.someEvent.donate()`) when the action fires

## Files Changed

| File | Change |
|------|--------|
| **New:** `Remet/Tips/RemetTips.swift` | All 11 tip structs + events |
| `Remet/RemetApp.swift` | `Tips.configure()` in init |
| `Remet/Views/Home/HomeView.swift` | 3 popoverTips + donations |
| `Remet/Views/Practice/PracticeHomeView.swift` | 2 popoverTips + donations |
| `Remet/Views/Scan/ScanTabView.swift` | 2 popoverTips + donations |
| `Remet/Views/Encounters/EncounterReviewView.swift` | 2 popoverTips + donations |
| `Remet/Views/People/PersonDetailView.swift` | 2 popoverTips + donations |
