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

// MARK: - Liquid Glass Background Modifier

struct LiquidGlassBackgroundModifier: ViewModifier {
    var cornerRadius: CGFloat
    var isCapsule: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            // iOS 26+ native liquid glass effect
            if isCapsule {
                content
                    .background(.regularMaterial, in: Capsule())
                    .glassBackgroundEffect(in: Capsule())
            } else {
                content
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
            }
        } else {
            // Fallback for older iOS - custom translucent effect
            if isCapsule {
                content
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                    )
                    .overlay(
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
                    )
            } else {
                content
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                    )
                    .overlay(
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
                    )
            }
        }
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
            .background(glassBackground(isPressed: configuration.isPressed))
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }

    @ViewBuilder
    private func glassBackground(isPressed: Bool) -> some View {
        if #available(iOS 26, *) {
            // iOS 26+ uses native glass effect for selected state
            if isSelected {
                Capsule()
                    .fill(selectedColor.opacity(0.15))
                    .glassBackgroundEffect(in: Capsule())
            } else {
                Color.clear
            }
        } else {
            // Fallback for older iOS
            Capsule()
                .fill(isSelected ? selectedColor.opacity(0.12) : Color.clear)
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies liquid glass background effect - native on iOS 26+, custom fallback on older versions
    /// - Parameters:
    ///   - cornerRadius: Corner radius for rounded rectangle shape (ignored if isCapsule is true)
    ///   - isCapsule: Use capsule shape instead of rounded rectangle
    func liquidGlassBackground(cornerRadius: CGFloat = 16, isCapsule: Bool = false) -> some View {
        modifier(LiquidGlassBackgroundModifier(cornerRadius: cornerRadius, isCapsule: isCapsule))
    }

    /// Applies liquid glass button styling
    func liquidGlassButtonStyle(isSelected: Bool = false, selectedColor: Color = AppColors.coral) -> some View {
        self.buttonStyle(LiquidGlassButtonStyle(isSelected: isSelected, selectedColor: selectedColor))
    }
}

// MARK: - Liquid Glass Tab Icon

/// Tab icon that uses iOS 26 liquid glass styling when available
struct LiquidGlassTabIcon: View {
    let systemName: String
    let label: String
    let isSelected: Bool
    var selectedColor: Color = AppColors.coral

    var body: some View {
        VStack(spacing: 4) {
            if #available(iOS 26, *) {
                // iOS 26+ - use symbol effect and glass styling
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

            Text(label)
                .font(.caption2)
                .fontWeight(isSelected ? .semibold : .regular)
        }
        .foregroundStyle(isSelected ? selectedColor : .secondary)
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("iOS Version: \(iOSVersion.is26OrLater ? "26+" : "< 26")")

        HStack(spacing: 20) {
            LiquidGlassTabIcon(systemName: "person.3", label: "People", isSelected: true)
            LiquidGlassTabIcon(systemName: "brain.head.profile", label: "Practice", isSelected: false)
        }
        .padding()
        .liquidGlassBackground(isCapsule: true)

        Text("Card Example")
            .padding()
            .frame(maxWidth: .infinity)
            .liquidGlassBackground(cornerRadius: 16)
            .padding(.horizontal)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
}
