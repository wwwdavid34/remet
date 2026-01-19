import SwiftUI

/// A view modifier that adds a gradient fade at the top of the view
/// to create a smooth transition where content meets the status bar/navigation bar
struct StatusBarFadeModifier: ViewModifier {
    var backgroundColor: Color
    var fadeHeight: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [
                        backgroundColor,
                        backgroundColor.opacity(0.8),
                        backgroundColor.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: fadeHeight)
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .top)
            }
    }
}

extension View {
    /// Adds a fade overlay at the top of the view for status bar content separation
    /// - Parameters:
    ///   - backgroundColor: The color to fade from (should match the view's background)
    ///   - fadeHeight: The height of the fade gradient (default: 20)
    func statusBarFade(
        backgroundColor: Color = Color(.systemGroupedBackground),
        fadeHeight: CGFloat = 20
    ) -> some View {
        modifier(StatusBarFadeModifier(backgroundColor: backgroundColor, fadeHeight: fadeHeight))
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
        .background(Color(.systemGroupedBackground))
        .statusBarFade()
        .navigationTitle("Test")
        .navigationBarTitleDisplayMode(.inline)
    }
}
