# Tip Guidance After Onboarding — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add 11 TipKit popover tips across 5 app areas to guide first-time users after onboarding.

**Architecture:** A single `RemetTips.swift` file defines all tip structs (conforming to `Tip`) and their corresponding `Tips.Event` triggers. Each tip auto-invalidates when the user performs the associated action. Tips are configured once in `RemetApp.swift` via `Tips.configure()`. Each target view gets a `.popoverTip()` modifier on the relevant button and donates the event when the action fires.

**Tech Stack:** SwiftUI, TipKit (iOS 17+ native framework)

---

### Task 1: Create RemetTips.swift and Configure TipKit

**Files:**
- Create: `Remet/Tips/RemetTips.swift`
- Modify: `Remet/RemetApp.swift`

**Step 1: Create `Remet/Tips/RemetTips.swift`**

This file defines all 11 tip structs and their events. Each struct conforms to `Tip` and uses a `#Rule` that checks whether its event has been donated (donated = user performed the action = tip should no longer show).

```swift
import TipKit

// MARK: - Home View Tips

struct NewFaceTip: Tip {
    static let tapped = Tips.Event(id: "newFaceTapped")

    var title: Text { Text("Scan a New Face") }
    var message: Text? { Text("Tap to capture and remember someone new") }
    var image: Image? { Image(systemName: "person.badge.plus") }

    var rules: [Rule] {
        #Rule(Self.tapped) { $0.donations.count == 0 }
    }
}

struct PracticeTip: Tip {
    static let tapped = Tips.Event(id: "practiceTapped")

    var title: Text { Text("Test Your Memory") }
    var message: Text? { Text("Quiz yourself on the faces you've learned") }
    var image: Image? { Image(systemName: "brain.head.profile") }

    var rules: [Rule] {
        #Rule(Self.tapped) { $0.donations.count == 0 }
    }
}

struct AddEncounterTip: Tip {
    static let tapped = Tips.Event(id: "addTabTapped")

    var title: Text { Text("Add an Encounter") }
    var message: Text? { Text("Capture from camera or import from photo library") }
    var image: Image? { Image(systemName: "plus.circle") }

    var rules: [Rule] {
        #Rule(Self.tapped) { $0.donations.count == 0 }
    }
}

// MARK: - Practice View Tips

struct SpacedReviewTip: Tip {
    static let tapped = Tips.Event(id: "spacedReviewTapped")

    var title: Text { Text("Spaced Review") }
    var message: Text? { Text("Review faces that are due for practice") }
    var image: Image? { Image(systemName: "clock.badge") }

    var rules: [Rule] {
        #Rule(Self.tapped) { $0.donations.count == 0 }
    }
}

struct SetFiltersTip: Tip {
    static let tapped = Tips.Event(id: "setFiltersTapped")

    var title: Text { Text("Customize Your Quiz") }
    var message: Text? { Text("Filter by favorites, tags, or relationship") }
    var image: Image? { Image(systemName: "line.3.horizontal.decrease.circle") }

    var rules: [Rule] {
        #Rule(Self.tapped) { $0.donations.count == 0 }
    }
}

// MARK: - Identify View Tips

struct LiveScanTip: Tip {
    static let tapped = Tips.Event(id: "liveScanTapped")

    var title: Text { Text("Live Scan") }
    var message: Text? { Text("Point your camera at someone to identify them") }
    var image: Image? { Image(systemName: "camera.viewfinder") }

    var rules: [Rule] {
        #Rule(Self.tapped) { $0.donations.count == 0 }
    }
}

struct MatchFromPhotoTip: Tip {
    static let tapped = Tips.Event(id: "matchFromPhotoTapped")

    var title: Text { Text("Match from Photo") }
    var message: Text? { Text("Identify faces in an existing photo") }
    var image: Image? { Image(systemName: "photo.on.rectangle.angled") }

    var rules: [Rule] {
        #Rule(Self.tapped) { $0.donations.count == 0 }
    }
}

// MARK: - Labeling Tips

struct FaceBoxTip: Tip {
    static let tapped = Tips.Event(id: "faceBoxTapped")

    var title: Text { Text("Label This Face") }
    var message: Text? { Text("Tap a face box to assign a name") }
    var image: Image? { Image(systemName: "person.crop.rectangle") }

    var rules: [Rule] {
        #Rule(Self.tapped) { $0.donations.count == 0 }
    }
}

struct RedetectTip: Tip {
    static let tapped = Tips.Event(id: "redetectTapped")

    var title: Text { Text("Missing a Face?") }
    var message: Text? { Text("Re-analyze the photo for missed faces") }
    var image: Image? { Image(systemName: "arrow.clockwise") }

    var rules: [Rule] {
        #Rule(Self.tapped) { $0.donations.count == 0 }
    }
}

// MARK: - Person Detail Tips

struct FavoriteTip: Tip {
    static let tapped = Tips.Event(id: "favoriteToggled")

    var title: Text { Text("Favorite") }
    var message: Text? { Text("Mark as favorite for quick access") }
    var image: Image? { Image(systemName: "star") }

    var rules: [Rule] {
        #Rule(Self.tapped) { $0.donations.count == 0 }
    }
}

struct MoreActionsTip: Tip {
    static let tapped = Tips.Event(id: "menuOpened")

    var title: Text { Text("More Actions") }
    var message: Text? { Text("Edit details, merge duplicates, or delete") }
    var image: Image? { Image(systemName: "ellipsis.circle") }

    var rules: [Rule] {
        #Rule(Self.tapped) { $0.donations.count == 0 }
    }
}
```

**Step 2: Add `import TipKit` and `Tips.configure()` to `RemetApp.swift`**

In `Remet/RemetApp.swift`, add `import TipKit` at the top (line 2), and add `Tips.configure()` inside the `.task` block right after `AppSettings.shared.recordFirstLaunchIfNeeded()` (around line 88):

```swift
// After line 88: AppSettings.shared.recordFirstLaunchIfNeeded()
try? Tips.configure([
    .displayFrequency(.immediate)
])
```

**Step 3: Build to verify**

Run: `xcodebuild build -scheme Remet -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -skipPackagePluginValidation -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Remet/Tips/RemetTips.swift Remet/RemetApp.swift
git commit -m "feat: add TipKit tip definitions and configure in app entry point"
```

---

### Task 2: Add Tips to HomeView and ContentView

**Files:**
- Modify: `Remet/Views/Home/HomeView.swift`
- Modify: `Remet/Views/ContentView.swift`

**Context:** HomeView has two `HomeActionButton` calls at lines 86-107 for "New Face" and "Practice". ContentView has a glass menu at lines 138-157 with "Take Photo" and "Import from Library" rows. The Add tab tip goes on the `menuContent` VStack since tab bar items can't host popovers.

**Step 1: Add tips to HomeView**

In `Remet/Views/Home/HomeView.swift`:

1. Add `import TipKit` at the top.

2. Add tip instances as properties in the view:
```swift
private let newFaceTip = NewFaceTip()
private let practiceTip = PracticeTip()
```

3. On the "New Face" `HomeActionButton` (lines 86-93), add `.popoverTip(newFaceTip)` after the closing `)` of the button and donate the event inside the action closure:
```swift
HomeActionButton(
    title: "New Face",
    subtitle: "Capture someone new",
    icon: "person.badge.plus",
    gradient: [AppColors.coral, AppColors.coral.opacity(0.7)]
) {
    NewFaceTip.tapped.donate()
    showQuickCapture = true
}
.popoverTip(newFaceTip)
```

4. On the "Practice" `HomeActionButton` (lines 95-107), add `.popoverTip(practiceTip)` and donate the event:
```swift
HomeActionButton(
    title: "Practice",
    subtitle: peopleWithFaces.isEmpty ? "Add 3 faces to unlock" : "Train your memory",
    icon: "brain.head.profile",
    gradient: [AppColors.teal, AppColors.teal.opacity(0.7)],
    isLocked: peopleWithFaces.isEmpty
) {
    PracticeTip.tapped.donate()
    if peopleWithFaces.isEmpty {
        showQuickCapture = true
    } else {
        showPractice = true
    }
}
.popoverTip(practiceTip)
```

**Step 2: Add tip to ContentView glass menu**

In `Remet/Views/ContentView.swift`:

1. Add `import TipKit` at the top.

2. Add tip instance:
```swift
private let addEncounterTip = AddEncounterTip()
```

3. On the "Take Photo" `menuRow` call (line 140), donate the event inside the action:
```swift
menuRow(icon: "camera.fill", label: String(localized: "Take Photo")) {
    AddEncounterTip.tapped.donate()
    dismissAddActions()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        showQuickCapture = true
    }
}
```

4. On the "Import from Library" `menuRow` call (line 150), also donate:
```swift
menuRow(icon: "photo.on.rectangle", label: String(localized: "Import from Library")) {
    AddEncounterTip.tapped.donate()
    dismissAddActions()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        showPhotoImport = true
    }
}
```

5. Attach `.popoverTip(addEncounterTip)` to the `menuContent` VStack (line 139). Add it after the `.frame(width: 230)` modifier:
```swift
.frame(width: 230)
.popoverTip(addEncounterTip)
```

**Step 3: Build to verify**

Run: `xcodebuild build -scheme Remet -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -skipPackagePluginValidation -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Remet/Views/Home/HomeView.swift Remet/Views/ContentView.swift
git commit -m "feat: add TipKit popovers to HomeView and ContentView add menu"
```

---

### Task 3: Add Tips to PracticeHomeView and ScanTabView

**Files:**
- Modify: `Remet/Views/Practice/PracticeHomeView.swift`
- Modify: `Remet/Views/Search/ScanTabView.swift`

**Context:** PracticeHomeView has a `QuizModeButton(mode: .spaced, ...)` at line 249 and a filter button at line 291. ScanTabView has a "Live Camera Scan" button at line 104 and a "Match from Photo" button at line 140.

**Step 1: Add tips to PracticeHomeView**

In `Remet/Views/Practice/PracticeHomeView.swift`:

1. Add `import TipKit` at the top.

2. Add tip instances:
```swift
private let spacedReviewTip = SpacedReviewTip()
private let setFiltersTip = SetFiltersTip()
```

3. On the Spaced Review `QuizModeButton` (lines 249-257), add `.popoverTip(spacedReviewTip)` after it and donate in the action:
```swift
QuizModeButton(
    mode: .spaced,
    count: countForMode(.spaced),
    isDisabled: false,
    isRecommended: true
) {
    SpacedReviewTip.tapped.donate()
    selectedMode = .spaced
    showingQuiz = true
}
.popoverTip(spacedReviewTip)
```

4. On the "Set Filters" Button (lines 291-292), add `.popoverTip(setFiltersTip)` and donate:
```swift
Button {
    SetFiltersTip.tapped.donate()
    showCustomFilters = true
} label: {
    // ... existing label unchanged ...
}
.popoverTip(setFiltersTip)
```

**Step 2: Add tips to ScanTabView**

In `Remet/Views/Search/ScanTabView.swift`:

1. Add `import TipKit` at the top.

2. Add tip instances:
```swift
private let liveScanTip = LiveScanTip()
private let matchFromPhotoTip = MatchFromPhotoTip()
```

3. On the "Live Camera Scan" Button (lines 104-137), add `.popoverTip(liveScanTip)` after `.buttonStyle(.plain)` and donate in the action:
```swift
Button {
    LiveScanTip.tapped.donate()
    showMemoryScan = true
} label: {
    // ... existing label unchanged ...
}
.buttonStyle(.plain)
.popoverTip(liveScanTip)
```

4. On the "Match from Photo" Button (lines 140-187), add `.popoverTip(matchFromPhotoTip)` after `.buttonStyle(.plain)` and donate in the action:
```swift
Button {
    MatchFromPhotoTip.tapped.donate()
    if subscriptionManager.isPremium {
        showImageMatch = true
    } else {
        showPremiumRequired = true
    }
} label: {
    // ... existing label unchanged ...
}
.buttonStyle(.plain)
.popoverTip(matchFromPhotoTip)
```

**Step 3: Build to verify**

Run: `xcodebuild build -scheme Remet -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -skipPackagePluginValidation -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Remet/Views/Practice/PracticeHomeView.swift Remet/Views/Search/ScanTabView.swift
git commit -m "feat: add TipKit popovers to Practice and Identify views"
```

---

### Task 4: Add Tips to EncounterReviewView and PersonDetailView

**Files:**
- Modify: `Remet/Views/Encounters/EncounterReviewView.swift`
- Modify: `Remet/Views/People/PersonDetailView.swift`

**Context:** EncounterReviewView has face bounding box overlays (line 90-101) with `.onTapGesture` and a "Re-detect" button (line 120-130). PersonDetailView has a star/favorite button (line 84-91) and an ellipsis Menu (line 93-117).

**Step 1: Add tips to EncounterReviewView**

In `Remet/Views/Encounters/EncounterReviewView.swift`:

1. Add `import TipKit` at the top.

2. Add tip instances:
```swift
private let faceBoxTip = FaceBoxTip()
private let redetectTip = RedetectTip()
```

3. For the face bounding box tip, attach `.popoverTip(faceBoxTip)` to the **first** `FaceBoundingBoxOverlay` only (to avoid 5 popovers on 5 faces). Modify the overlay ForEach (around line 90) — add the popover conditionally on `index == 0`:

```swift
FaceBoundingBoxOverlay(
    box: box,
    isSelected: selectedBoxIndex == index,
    imageSize: image.size,
    viewSize: geometry.size
)
.onTapGesture {
    FaceBoxTip.tapped.donate()
    selectedBoxIndex = index
    showPersonPicker = true
}
.popoverTip(index == 0 ? faceBoxTip : nil)
```

Note: If `.popoverTip(nil)` doesn't compile, use a conditional wrapper:
```swift
.ifLet(index == 0 ? faceBoxTip : nil) { view, tip in
    view.popoverTip(tip)
}
```
Or simply wrap in `if index == 0` with a ViewBuilder approach. The simplest working approach may be to use `.popoverTip(faceBoxTip)` on only the first overlay by splitting the ForEach or using an overlay on the entire photo section instead.

4. On the "Re-detect" button (around line 120), add `.popoverTip(redetectTip)` and donate:
```swift
Button {
    RedetectTip.tapped.donate()
    redetectFaces()
} label: {
    HStack(spacing: 4) {
        Image(systemName: "arrow.clockwise")
        Text("Re-detect")
    }
    .font(.caption)
    .foregroundStyle(AppColors.teal)
}
.popoverTip(redetectTip)
```

**Step 2: Add tips to PersonDetailView**

In `Remet/Views/People/PersonDetailView.swift`:

1. Add `import TipKit` at the top.

2. Add tip instances:
```swift
private let favoriteTip = FavoriteTip()
private let moreActionsTip = MoreActionsTip()
```

3. On the star button (lines 84-91), add `.popoverTip(favoriteTip)` and donate:
```swift
Button {
    FavoriteTip.tapped.donate()
    withAnimation(.bouncy(duration: 0.3)) {
        person.isFavorite.toggle()
    }
} label: {
    Image(systemName: person.isFavorite ? "star.fill" : "star")
        .foregroundStyle(person.isFavorite ? .yellow : .secondary)
}
.popoverTip(favoriteTip)
```

4. On the ellipsis Menu (lines 93-117), add `.popoverTip(moreActionsTip)`. Since `Menu` is a container, the popover attaches to its label. Donate when any menu action is triggered. The simplest approach is to donate when the Edit action is triggered (the most common action), but we can also use `.onAppear` inside the Menu content to detect menu open. The most reliable approach: donate in each menu action:

```swift
Menu {
    Button {
        MoreActionsTip.tapped.donate()
        showEditSheet = true
    } label: {
        Label(String(localized: "Edit Details"), systemImage: "pencil")
    }

    Button {
        MoreActionsTip.tapped.donate()
        showMergeWithPicker = true
    } label: {
        Label(String(localized: "Merge with..."), systemImage: "arrow.triangle.merge")
    }

    if !person.isMe {
        Divider()

        Button(role: .destructive) {
            MoreActionsTip.tapped.donate()
            showDeleteConfirmation = true
        } label: {
            Label(String(localized: "Delete Person"), systemImage: "trash")
        }
    }
} label: {
    Image(systemName: "ellipsis.circle")
}
.popoverTip(moreActionsTip)
```

**Step 3: Build to verify**

Run: `xcodebuild build -scheme Remet -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -skipPackagePluginValidation -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Remet/Views/Encounters/EncounterReviewView.swift Remet/Views/People/PersonDetailView.swift
git commit -m "feat: add TipKit popovers to labeling and person detail views"
```

---

### Task 5: Final Build Verification and Cleanup

**Files:**
- All files from Tasks 1-4

**Step 1: Full build**

Run: `xcodebuild build -scheme Remet -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -skipPackagePluginValidation -quiet 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 2: Run existing tests to ensure no regressions**

Run: `xcodebuild test -scheme Remet -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -skipPackagePluginValidation -only-testing:RemetTests -quiet 2>&1 | tail -20`
Expected: All tests pass

**Step 3: Verify no stale references**

Run grep for any remaining issues:
```bash
# Ensure all tip files import TipKit
grep -r "import TipKit" Remet/

# Ensure Tips.configure is called
grep -r "Tips.configure" Remet/
```

Expected: 7 files with `import TipKit` (RemetTips.swift + 5 views + RemetApp.swift), 1 file with `Tips.configure`.

**Step 4: Verify tip struct count**

```bash
grep -c "struct.*Tip:" Remet/Tips/RemetTips.swift
```
Expected: 11
