import SwiftUI

/// Tab item for the floating tab bar
struct FloatingTabItem: Identifiable {
    let id: Int
    let icon: String
    let label: String
}

/// Floating pill-shaped tab bar with translucent background
/// Designed for iOS liquid glass aesthetic
struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    let items: [FloatingTabItem]

    // Haptic feedback
    private let impact = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                tabButton(for: item)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
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
        .padding(.leading, 16)
        .padding(.trailing, 108) // Leave room for FAB
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func tabButton(for item: FloatingTabItem) -> some View {
        let isSelected = selectedTab == item.id

        Button {
            impact.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = item.id
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? item.icon + ".fill" : item.icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)

                Text(item.label)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundStyle(isSelected ? AppColors.coral : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? AppColors.coral.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Container view that manages floating tab bar navigation
struct FloatingTabBarContainer<Content: View>: View {
    @Binding var selectedTab: Int
    let items: [FloatingTabItem]
    let content: Content

    init(
        selectedTab: Binding<Int>,
        items: [FloatingTabItem],
        @ViewBuilder content: () -> Content
    ) {
        self._selectedTab = selectedTab
        self.items = items
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(selectedTab: $selectedTab, items: items)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedTab = 0

        var body: some View {
            FloatingTabBarContainer(
                selectedTab: $selectedTab,
                items: [
                    FloatingTabItem(id: 0, icon: "person.3", label: "People"),
                    FloatingTabItem(id: 1, icon: "brain.head.profile", label: "Practice"),
                    FloatingTabItem(id: 2, icon: "eye", label: "Identify")
                ]
            ) {
                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()

                    Text("Tab \(selectedTab)")
                        .font(.largeTitle)
                }
            }
        }
    }

    return PreviewWrapper()
}
