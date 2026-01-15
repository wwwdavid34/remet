import Foundation
import SwiftData
import SwiftUI

@Model
final class Tag {
    var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date

    // Inverse relationships
    @Relationship(inverse: \Person.tags)
    var people: [Person] = []

    @Relationship(inverse: \Encounter.tags)
    var encounters: [Encounter] = []

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = TagColor.blue.hex,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    var usageCount: Int {
        people.count + encounters.count
    }
}

// Predefined tag colors
enum TagColor: String, CaseIterable, Identifiable {
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case cyan
    case blue
    case indigo
    case purple
    case pink
    case brown

    var id: String { rawValue }

    var hex: String {
        switch self {
        case .red: return "#FF3B30"
        case .orange: return "#FF9500"
        case .yellow: return "#FFCC00"
        case .green: return "#34C759"
        case .mint: return "#00C7BE"
        case .teal: return "#30B0C7"
        case .cyan: return "#32ADE6"
        case .blue: return "#007AFF"
        case .indigo: return "#5856D6"
        case .purple: return "#AF52DE"
        case .pink: return "#FF2D55"
        case .brown: return "#A2845E"
        }
    }

    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .mint: return .mint
        case .teal: return .teal
        case .cyan: return .cyan
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .brown: return .brown
        }
    }
}

// Color extension for hex support
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// Preset tags for common use cases
enum PresetTag: String, CaseIterable {
    case work = "Work"
    case family = "Family"
    case friends = "Friends"
    case business = "Business"
    case travel = "Travel"
    case event = "Event"
    case conference = "Conference"
    case school = "School"
    case sports = "Sports"
    case hobby = "Hobby"

    var suggestedColor: TagColor {
        switch self {
        case .work: return .blue
        case .family: return .red
        case .friends: return .green
        case .business: return .indigo
        case .travel: return .orange
        case .event: return .purple
        case .conference: return .teal
        case .school: return .yellow
        case .sports: return .mint
        case .hobby: return .pink
        }
    }
}
