import SwiftUI

/// UIKit view that blocks all touches from passing through to views below
private struct TouchBlockingView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

/// Quick action for the floating action button menu
struct QuickAction: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
}

// MARK: - FAB Button Style

/// Button style that provides press animation for the FAB
struct FABButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - FAB Button Label

/// The visual label for the FAB button
struct FABButtonLabel: View {
    let isExpanded: Bool

    var body: some View {
        if #available(iOS 26, *) {
            // iOS 26 - native liquid glass
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
            .glassEffect(.regular.interactive(), in: .capsule)
            .contentShape(Capsule())
        } else {
            // Pre-iOS 26 fallback
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
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
            .contentShape(Capsule())
        }
    }
}

/// Floating Action Button with long-press quick action menu
/// Provides always-accessible capture and scan functionality
struct FloatingActionButton: View {
    let primaryAction: () -> Void
    let quickActions: [QuickAction]
    var expandOnTap: Bool = false  // If true, tap expands menu instead of calling primaryAction

    @State private var isExpanded = false

    // Haptic feedback
    private let impactMed = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Dimmed background when expanded
            if isExpanded {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
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
            // Reduced padding to compensate for expanded button hit area (+8pt padding on button)
            .padding(.trailing, 8)
            .padding(.bottom, 0)
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
            FABButtonLabel(isExpanded: isExpanded)
                // Expand the tappable area with invisible padding
                // This ensures taps near the button don't fall through to elements beneath
                .padding(8)
                .background {
                    TouchBlockingView()
                        .clipShape(Capsule())
                }
                .contentShape(Capsule())
        }
        .buttonStyle(FABButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    impactHeavy.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded = true
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
                quickActionLabel(action.label)

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

    @ViewBuilder
    private func quickActionLabel(_ label: String) -> some View {
        if #available(iOS 26, *) {
            // iOS 26 - native liquid glass
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)
        } else {
            // Pre-iOS 26 fallback
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
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
