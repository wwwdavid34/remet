import SwiftUI

/// A view modifier that adds a solid + gradient mask at the top of the view
/// to create clear separation where content meets the status bar
struct StatusBarFadeModifier: ViewModifier {
    var backgroundColor: Color
    var solidHeight: CGFloat
    var fadeHeight: CGFloat

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                // This pushes content down so it doesn't start behind status bar
                Color.clear.frame(height: 0)
            }
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    // Solid color covering the status bar area
                    backgroundColor
                        .frame(height: solidHeight)

                    // Gradient fade below the solid area
                    LinearGradient(
                        stops: [
                            .init(color: backgroundColor, location: 0),
                            .init(color: backgroundColor.opacity(0.95), location: 0.3),
                            .init(color: backgroundColor.opacity(0.7), location: 0.6),
                            .init(color: backgroundColor.opacity(0.3), location: 0.85),
                            .init(color: backgroundColor.opacity(0), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: fadeHeight)
                }
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .top)
            }
    }
}

extension View {
    /// Adds a solid + fade overlay at the top of the view for status bar content separation
    /// - Parameters:
    ///   - backgroundColor: The color to fade from (should match the view's background)
    ///   - solidHeight: Height of solid color behind status bar (default: 44 for status bar)
    ///   - fadeHeight: Height of the fade gradient below solid area (default: 24)
    func statusBarFade(
        backgroundColor: Color = Color(UIColor.systemGroupedBackground),
        solidHeight: CGFloat = 44,
        fadeHeight: CGFloat = 24
    ) -> some View {
        modifier(StatusBarFadeModifier(
            backgroundColor: backgroundColor,
            solidHeight: solidHeight,
            fadeHeight: fadeHeight
        ))
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(0..<20) { i in
                    Text("Item \(i)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .statusBarFade()
        .navigationTitle("Test")
        .navigationBarTitleDisplayMode(.inline)
    }
}
