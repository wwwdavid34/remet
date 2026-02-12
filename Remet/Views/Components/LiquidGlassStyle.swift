import SwiftUI

/// Helper for iOS version detection and conditional liquid glass styling
enum iOSVersion {
    /// Check if running on iOS 26 or later (liquid glass design system)
    static var is26OrLater: Bool {
        if #available(iOS 26, *) {
            return true
        }
        return false
    }

    /// Check if running on iOS 18 or later
    static var is18OrLater: Bool {
        if #available(iOS 18, *) {
            return true
        }
        return false
    }
}

// MARK: - Glass Intensity Variants

/// Different intensities of liquid glass effect
enum LiquidGlassIntensity {
    /// Subtle glass with minimal blur - for backgrounds, secondary elements
    case thin
    /// Standard glass effect - default for most UI elements
    case regular
    /// Prominent glass with stronger blur - for important elements, modals
    case prominent

    /// Fallback material for pre-iOS 26
    var fallbackMaterial: Material {
        switch self {
        case .thin: return .ultraThinMaterial
        case .regular: return .thinMaterial
        case .prominent: return .regularMaterial
        }
    }

    /// Shadow opacity for fallback styling
    var shadowOpacity: Double {
        switch self {
        case .thin: return 0.08
        case .regular: return 0.12
        case .prominent: return 0.15
        }
    }
}

// MARK: - Liquid Glass Background Modifier

struct LiquidGlassBackgroundModifier: ViewModifier {
    var cornerRadius: CGFloat
    var isCapsule: Bool
    var intensity: LiquidGlassIntensity
    var isInteractive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            // iOS 26+ - native liquid glass effect
            if isCapsule {
                content
                    .padding(.horizontal, 4)
                    .glassEffect(.regular.interactive(), in: .capsule)
            } else {
                content
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            // Pre-iOS 26 fallback
            fallbackGlassContent(content)
        }
    }

    @ViewBuilder
    private func fallbackGlassContent(_ content: Content) -> some View {
        // Pre-iOS 26 - material-based glass effect with enhanced styling
        if isCapsule {
            content
                .background {
                    Capsule()
                        .fill(intensity.fallbackMaterial)
                        .shadow(color: Color.black.opacity(intensity.shadowOpacity), radius: 20, x: 0, y: 10)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(intensity.fallbackMaterial)
                        .shadow(color: Color.black.opacity(intensity.shadowOpacity), radius: 12, x: 0, y: 6)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
        }
    }
}

// MARK: - Tinted Glass Modifier

/// Glass effect with a color tint - useful for status indicators and branded elements
struct TintedGlassModifier: ViewModifier {
    let tintColor: Color
    let tintOpacity: Double
    var cornerRadius: CGFloat
    var isCapsule: Bool
    var isInteractive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            nativeContent(content)
        } else {
            fallbackContent(content)
        }
    }

    @available(iOS 26, *)
    @ViewBuilder
    private func nativeContent(_ content: Content) -> some View {
        if isCapsule {
            if isInteractive {
                content.glassEffect(.regular.tint(tintColor.opacity(tintOpacity)).interactive(), in: .capsule)
            } else {
                content.glassEffect(.regular.tint(tintColor.opacity(tintOpacity)), in: .capsule)
            }
        } else {
            if isInteractive {
                content.glassEffect(.regular.tint(tintColor.opacity(tintOpacity)).interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                content.glassEffect(.regular.tint(tintColor.opacity(tintOpacity)), in: .rect(cornerRadius: cornerRadius))
            }
        }
    }

    @ViewBuilder
    private func fallbackContent(_ content: Content) -> some View {
        if isCapsule {
            content
                .background {
                    ZStack {
                        Capsule()
                            .fill(.ultraThinMaterial)
                        Capsule()
                            .fill(tintColor.opacity(tintOpacity))
                    }
                    .shadow(color: tintColor.opacity(0.15), radius: 8, x: 0, y: 4)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    tintColor.opacity(0.3),
                                    Color.white.opacity(0.2),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
        } else {
            content
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(tintColor.opacity(tintOpacity))
                    }
                    .shadow(color: tintColor.opacity(0.15), radius: 8, x: 0, y: 4)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    tintColor.opacity(0.3),
                                    Color.white.opacity(0.2),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
        }
    }
}

// MARK: - Glass Card Modifier

/// Card-specific glass styling with appropriate padding and shadow
struct GlassCardModifier: ViewModifier {
    var intensity: LiquidGlassIntensity
    var cornerRadius: CGFloat
    var isInteractive: Bool
    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if isInteractive {
                content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(intensity.fallbackMaterial)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.15 : 0.4),
                                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.15),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(
                    color: colorScheme == .dark ? .clear : .black.opacity(intensity.shadowOpacity),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        }
    }
}

// MARK: - Glass Navigation Bar Modifier

/// Applies glass effect to navigation bar area
struct GlassNavigationBarModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        // iOS 26 will use transparent nav bar with content-based glass
        content
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

// MARK: - Card Button Style

/// Button style for card-shaped elements (person rows, encounter cards, quiz mode buttons).
/// Provides subtle press feedback and ensures the entire card frame is tappable.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(
                configuration.isPressed
                    ? .easeIn(duration: 0.05)
                    : .spring(response: 0.3, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}

// MARK: - Liquid Glass Button Style

struct LiquidGlassButtonStyle: ButtonStyle {
    var isSelected: Bool
    var selectedColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .background(
                Capsule()
                    .fill(isSelected ? selectedColor.opacity(0.12) : Color.clear)
            )
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    /// Applies liquid glass background effect - enhanced on iOS 26+, standard on older versions
    /// - Parameters:
    ///   - cornerRadius: Corner radius for rounded rectangle shape (ignored if isCapsule is true)
    ///   - isCapsule: Use capsule shape instead of rounded rectangle
    ///   - intensity: Glass blur intensity (thin, regular, prominent)
    ///   - isInteractive: Adds touch ripple effect on iOS 26+
    func liquidGlassBackground(
        cornerRadius: CGFloat = 16,
        isCapsule: Bool = false,
        intensity: LiquidGlassIntensity = .regular,
        isInteractive: Bool = true
    ) -> some View {
        modifier(LiquidGlassBackgroundModifier(
            cornerRadius: cornerRadius,
            isCapsule: isCapsule,
            intensity: intensity,
            isInteractive: isInteractive
        ))
    }

    /// Applies a tinted glass effect - glass with a subtle color overlay
    /// - Parameters:
    ///   - tintColor: The color to tint the glass
    ///   - tintOpacity: How strong the tint should be (0.05-0.2 recommended)
    ///   - cornerRadius: Corner radius for the shape
    ///   - isCapsule: Use capsule shape
    func tintedGlassBackground(
        _ tintColor: Color,
        tintOpacity: Double = 0.1,
        cornerRadius: CGFloat = 16,
        isCapsule: Bool = false,
        interactive: Bool = true
    ) -> some View {
        modifier(TintedGlassModifier(
            tintColor: tintColor,
            tintOpacity: tintOpacity,
            cornerRadius: cornerRadius,
            isCapsule: isCapsule,
            isInteractive: interactive
        ))
    }

    /// Applies glass card styling - optimized for card components
    /// - Parameters:
    ///   - intensity: Glass blur intensity
    ///   - cornerRadius: Corner radius
    func glassCard(intensity: LiquidGlassIntensity = .regular, cornerRadius: CGFloat = 16, interactive: Bool = true) -> some View {
        modifier(GlassCardModifier(intensity: intensity, cornerRadius: cornerRadius, isInteractive: interactive))
    }

    /// Applies glass effect to navigation bar
    func glassNavigationBar() -> some View {
        modifier(GlassNavigationBarModifier())
    }

    /// Applies liquid glass button styling
    func liquidGlassButtonStyle(isSelected: Bool = false, selectedColor: Color = .accentColor) -> some View {
        self.buttonStyle(LiquidGlassButtonStyle(isSelected: isSelected, selectedColor: selectedColor))
    }
}

// MARK: - Liquid Glass Tab Icon

/// Tab icon that uses enhanced styling on iOS 26+
struct LiquidGlassTabIcon: View {
    let systemName: String
    let label: String
    let isSelected: Bool
    var selectedColor: Color = .accentColor

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if #available(iOS 18, *) {
                    // iOS 18+ - use symbol effect for bounce
                    Image(systemName: isSelected ? systemName + ".fill" : systemName)
                        .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                        .symbolRenderingMode(.hierarchical)
                        .symbolEffect(.bounce, value: isSelected)
                } else {
                    // Fallback - standard icon
                    Image(systemName: isSelected ? systemName + ".fill" : systemName)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .symbolRenderingMode(.hierarchical)
                }
            }

            Text(label)
                .font(.caption2)
                .fontWeight(isSelected ? .semibold : .regular)
        }
        .foregroundStyle(isSelected ? selectedColor : .secondary)
    }
}

// MARK: - Glass Stat Badge

/// A stat badge with glass styling - perfect for dashboards
struct GlassStatBadge: View {
    let value: String
    let label: String
    let icon: String?
    let tintColor: Color

    init(value: String, label: String, icon: String? = nil, tintColor: Color = .blue) {
        self.value = value
        self.label = label
        self.icon = icon
        self.tintColor = tintColor
    }

    var body: some View {
        VStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tintColor)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .tintedGlassBackground(tintColor, tintOpacity: 0.08, cornerRadius: 14)
    }
}

// MARK: - Glass Search Field

/// Search field with glass styling
struct GlassSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    var onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .submitLabel(.search)
                .onSubmit { onSubmit?() }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .glassCard(intensity: .thin, cornerRadius: 12)
    }
}

// MARK: - Glass Chip

/// Small chip/tag with glass styling
struct GlassChip: View {
    let text: String
    var icon: String?
    var tintColor: Color?
    var isSelected: Bool = false
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(text)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? (tintColor ?? .accentColor) : .secondary)
        }
        .buttonStyle(.plain)
        .background {
            if isSelected, let tintColor = tintColor {
                Capsule()
                    .fill(tintColor.opacity(0.15))
                    .overlay {
                        Capsule()
                            .strokeBorder(tintColor.opacity(0.3), lineWidth: 0.5)
                    }
            } else {
                Capsule()
                    .fill(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - Previews

#Preview("Glass Components") {
    ScrollView {
        VStack(spacing: 24) {
            // Header
            Text("Liquid Glass UI")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)

            // Tab bar style
            HStack(spacing: 20) {
                LiquidGlassTabIcon(systemName: "person.3", label: "People", isSelected: true, selectedColor: .orange)
                LiquidGlassTabIcon(systemName: "brain.head.profile", label: "Practice", isSelected: false)
                LiquidGlassTabIcon(systemName: "eye", label: "Scan", isSelected: false)
            }
            .padding()
            .liquidGlassBackground(isCapsule: true)

            // Stat badges
            HStack(spacing: 12) {
                GlassStatBadge(value: "12", label: "People", icon: "person.3.fill", tintColor: .orange)
                GlassStatBadge(value: "87%", label: "Accuracy", icon: "chart.bar.fill", tintColor: .green)
            }
            .padding(.horizontal)

            // Cards with different intensities
            VStack(spacing: 12) {
                Text("Thin Glass")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .glassCard(intensity: .thin, cornerRadius: 12)

                Text("Regular Glass")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .glassCard(intensity: .regular, cornerRadius: 12)

                Text("Prominent Glass")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .glassCard(intensity: .prominent, cornerRadius: 12)
            }
            .padding(.horizontal)

            // Tinted glass
            HStack(spacing: 12) {
                Text("Success")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .tintedGlassBackground(.green, tintOpacity: 0.1, cornerRadius: 12)

                Text("Warning")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .tintedGlassBackground(.orange, tintOpacity: 0.1, cornerRadius: 12)
            }
            .padding(.horizontal)

            // Chips
            HStack(spacing: 8) {
                GlassChip(text: "Work", icon: "briefcase", tintColor: .blue, isSelected: true)
                GlassChip(text: "Friends", icon: "person.2", tintColor: .purple, isSelected: false)
                GlassChip(text: "Family", icon: "house", tintColor: .orange, isSelected: false)
            }
            .padding(.horizontal)

            Spacer(minLength: 100)
        }
    }
    .background {
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.2), .orange.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview("Dark Mode") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            LiquidGlassTabIcon(systemName: "person.3", label: "People", isSelected: true, selectedColor: .orange)
            LiquidGlassTabIcon(systemName: "brain.head.profile", label: "Practice", isSelected: false)
        }
        .padding()
        .liquidGlassBackground(isCapsule: true)

        Text("Glass Card")
            .padding()
            .frame(maxWidth: .infinity)
            .glassCard(cornerRadius: 16)
            .padding(.horizontal)

        GlassStatBadge(value: "5", label: "Due Today", icon: "clock", tintColor: .orange)
            .padding(.horizontal)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(UIColor.systemBackground))
    .preferredColorScheme(.dark)
}
