import SwiftUI

/// Quick action for the floating action button menu
struct QuickAction: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
}

/// Floating Action Button with long-press quick action menu
/// Provides always-accessible capture and scan functionality
struct FloatingActionButton: View {
    let primaryAction: () -> Void
    let quickActions: [QuickAction]
    var expandOnTap: Bool = false  // If true, tap expands menu instead of calling primaryAction

    @State private var isExpanded = false
    @State private var isPressed = false
    @State private var dragOffset: CGSize = .zero

    // Haptic feedback
    private let impactMed = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Dimmed background when expanded
            if isExpanded {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded = false
                        }
                    }
            }

            VStack(alignment: .trailing, spacing: 12) {
                // Quick action buttons (shown when expanded)
                if isExpanded {
                    ForEach(Array(quickActions.enumerated()), id: \.element.id) { index, action in
                        quickActionButton(action: action, index: index)
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity).combined(with: .offset(x: 20)),
                                removal: .scale.combined(with: .opacity)
                            ))
                    }
                }

                // Main FAB
                mainButton
            }
            .padding(.trailing, 16)
            .padding(.bottom, 8) // Aligned with tab bar
        }
    }

    // MARK: - Main Button

    private var mainButton: some View {
        Button {
            if isExpanded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded = false
                }
            } else if expandOnTap {
                // Tap expands menu
                impactMed.impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded = true
                }
            } else {
                // Tap calls primary action
                impactMed.impactOccurred()
                primaryAction()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isExpanded ? "xmark" : "camera.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColors.coral)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))

                Text(isExpanded ? String(localized: "Close") : String(localized: "Capture"))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.coral)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .liquidGlassBackground(isCapsule: true)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    impactHeavy.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded = true
                    }
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isExpanded {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
        .accessibilityLabel("Add person")
        .accessibilityHint("Tap to open camera, hold for more options")
    }

    // MARK: - Quick Action Button

    @ViewBuilder
    private func quickActionButton(action: QuickAction, index: Int) -> some View {
        Button {
            impactMed.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded = false
            }
            // Slight delay so animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                action.action()
            }
        } label: {
            HStack(spacing: 12) {
                Text(action.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())

                ZStack {
                    Circle()
                        .fill(action.color)
                        .frame(width: 48, height: 48)
                        .shadow(color: action.color.opacity(0.3), radius: 4, x: 0, y: 2)

                    Image(systemName: action.icon)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Modifier to add FAB to any view
struct FloatingActionButtonModifier: ViewModifier {
    let primaryAction: () -> Void
    let quickActions: [QuickAction]
    var expandOnTap: Bool = false

    func body(content: Content) -> some View {
        ZStack {
            content

            FloatingActionButton(
                primaryAction: primaryAction,
                quickActions: quickActions,
                expandOnTap: expandOnTap
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
}

extension View {
    /// Adds a floating action button overlay
    func floatingActionButton(
        primaryAction: @escaping () -> Void,
        quickActions: [QuickAction],
        expandOnTap: Bool = false
    ) -> some View {
        modifier(FloatingActionButtonModifier(
            primaryAction: primaryAction,
            quickActions: quickActions,
            expandOnTap: expandOnTap
        ))
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()

        VStack {
            Text("Sample Content")
            Spacer()
        }
    }
    .floatingActionButton(
        primaryAction: { print("Primary tap") },
        quickActions: [
            QuickAction(icon: "camera.fill", label: "New Face", color: AppColors.coral) { print("Camera") },
            QuickAction(icon: "eye", label: "Who's This?", color: AppColors.teal) { print("Scan") },
            QuickAction(icon: "photo.on.rectangle", label: "From Photo", color: AppColors.softPurple) { print("Photo") }
        ]
    )
}
