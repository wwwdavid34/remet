import TipKit

// MARK: - Home View Tips

struct NewFaceTip: Tip {
    var title: Text { Text("Scan a New Face") }
    var message: Text? { Text("Tap to capture and remember someone new") }
    var image: Image? { Image(systemName: "person.badge.plus") }
}

struct PracticeTip: Tip {
    var title: Text { Text("Test Your Memory") }
    var message: Text? { Text("Quiz yourself on the faces you've learned") }
    var image: Image? { Image(systemName: "brain.head.profile") }
}

struct AddEncounterTip: Tip {
    var title: Text { Text("Add an Encounter") }
    var message: Text? { Text("Capture from camera or import from photo library") }
    var image: Image? { Image(systemName: "plus.circle") }
}

// MARK: - Practice View Tips

struct SpacedReviewTip: Tip {
    var title: Text { Text("Spaced Review") }
    var message: Text? { Text("Review faces that are due for practice") }
    var image: Image? { Image(systemName: "clock.badge") }
}

struct SetFiltersTip: Tip {
    var title: Text { Text("Customize Your Quiz") }
    var message: Text? { Text("Filter by favorites, tags, or relationship") }
    var image: Image? { Image(systemName: "line.3.horizontal.decrease.circle") }
}

// MARK: - Identify View Tips

struct LiveScanTip: Tip {
    var title: Text { Text("Live Scan") }
    var message: Text? { Text("Point your camera at someone to identify them") }
    var image: Image? { Image(systemName: "camera.viewfinder") }
}

struct MatchFromPhotoTip: Tip {
    var title: Text { Text("Match from Photo") }
    var message: Text? { Text("Identify faces in an existing photo") }
    var image: Image? { Image(systemName: "photo.on.rectangle.angled") }
}

// MARK: - Labeling Tips

struct FaceBoxTip: Tip {
    var title: Text { Text("Label This Face") }
    var message: Text? { Text("Tap a face box to assign a name") }
    var image: Image? { Image(systemName: "person.crop.rectangle") }
}

struct RedetectTip: Tip {
    var title: Text { Text("Missing a Face?") }
    var message: Text? { Text("Re-analyze the photo for missed faces") }
    var image: Image? { Image(systemName: "arrow.clockwise") }
}

// MARK: - Person Detail Tips

struct FavoriteTip: Tip {
    var title: Text { Text("Favorite") }
    var message: Text? { Text("Mark as favorite for quick access") }
    var image: Image? { Image(systemName: "star") }
}

struct MoreActionsTip: Tip {
    var title: Text { Text("More Actions") }
    var message: Text? { Text("Edit details, merge duplicates, or delete") }
    var image: Image? { Image(systemName: "ellipsis.circle") }
}
