import SwiftUI
import SwiftData
import TipKit

/// Main app container with native tab bar + circle add button.
/// Tapping (+) shows a Calculator-style glass popup menu above the tab bar.
struct ContentView: View {
    @Query private var people: [Person]

    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showAddActions = false
    @State private var showQuickCapture = false
    @State private var showPhotoImport = false
    @Environment(AppState.self) private var appState: AppState?

    private let addEncounterTip = AddEncounterTip()

    var body: some View {
        ZStack {
            tabView
            addActionsOverlay
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $showQuickCapture) {
            QuickCaptureView()
        }
        .sheet(isPresented: $showPhotoImport) {
            PhotoImportView()
        }
        .onAppear {
            if appState?.shouldProcessSharedImages == true {
                showPhotoImport = true
            }
        }
        .onChange(of: appState?.shouldProcessSharedImages) { _, shouldProcess in
            if shouldProcess == true {
                showPhotoImport = true
            }
        }
    }

    // MARK: - Tab View

    @ViewBuilder
    private var tabView: some View {
        if #available(iOS 18, *) {
            TabView(selection: $selectedTab) {
                Tab(String(localized: "People"), systemImage: "person.3", value: 0) {
                    PeopleHomeView()
                }
                Tab(String(localized: "Practice"), systemImage: "brain.head.profile", value: 1) {
                    PracticeHomeView()
                }
                Tab(String(localized: "Identify"), systemImage: "eye", value: 2) {
                    ScanTabView()
                }
                Tab(value: 3, role: .search) {
                    Color.clear
                } label: {
                    Label(String(localized: "Add"), systemImage: "plus")
                }
            }
            .onChange(of: selectedTab) { _, newValue in
                if newValue == 3 {
                    selectedTab = previousTab
                    withAnimation(.bouncy) {
                        showAddActions = true
                    }
                } else {
                    previousTab = newValue
                }
            }
        } else {
            TabView(selection: $selectedTab) {
                PeopleHomeView()
                    .tag(0)
                    .tabItem { Label(String(localized: "People"), systemImage: "person.3") }
                PracticeHomeView()
                    .tag(1)
                    .tabItem { Label(String(localized: "Practice"), systemImage: "brain.head.profile") }
                ScanTabView()
                    .tag(2)
                    .tabItem { Label(String(localized: "Identify"), systemImage: "eye") }
                Color.clear
                    .tag(3)
                    .tabItem { Label(String(localized: "Add"), systemImage: "plus") }
            }
            .onChange(of: selectedTab) { _, newValue in
                if newValue == 3 {
                    selectedTab = previousTab
                    withAnimation(.bouncy) {
                        showAddActions = true
                    }
                } else {
                    previousTab = newValue
                }
            }
        }
    }

    // MARK: - Add Actions Overlay (Calculator-style glass menu)

    private var addActionsOverlay: some View {
        ZStack(alignment: .bottomTrailing) {
            // Dimmed backdrop — tap to dismiss
            Color.black.opacity(showAddActions ? 0.3 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(showAddActions)
                .onTapGesture { dismissAddActions() }

            // Glass popup menu positioned above (+) button
            if showAddActions {
                if #available(iOS 26, *) {
                    // Let .glassEffectTransition(.materialize) handle the glass visual;
                    // only fade the content overlay itself
                    glassMenu
                        .padding(.trailing, 16)
                        .padding(.bottom, 80)
                        .transition(.opacity)
                } else {
                    glassMenu
                        .padding(.trailing, 16)
                        .padding(.bottom, 80)
                        .transition(
                            .blurReplace
                            .combined(with: .scale(0.3, anchor: .bottomTrailing))
                        )
                }
            }
        }
    }

    // MARK: - Glass Menu

    @ViewBuilder
    private var glassMenu: some View {
        if #available(iOS 26, *) {
            menuContent
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                .glassEffectTransition(.materialize)
        } else {
            menuContent
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        }
    }

    private var menuContent: some View {
        VStack(spacing: 0) {
            menuRow(icon: "camera.fill", label: String(localized: "Take Photo")) {
                AddEncounterTip().invalidate(reason: .actionPerformed)
                NewFaceTip().invalidate(reason: .actionPerformed)
                dismissAddActions()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showQuickCapture = true
                }
            }

            Divider()
                .padding(.leading, 52)

            menuRow(icon: "photo.on.rectangle", label: String(localized: "Import from Library")) {
                AddEncounterTip().invalidate(reason: .actionPerformed)
                NewFaceTip().invalidate(reason: .actionPerformed)
                dismissAddActions()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showPhotoImport = true
                }
            }
        }
        .frame(width: 230)
        .safeAreaInset(edge: .top) {
            TipView(addEncounterTip)
        }
    }

    private func menuRow(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .frame(width: 28)
                Text(label)
                    .font(.body)
                Spacer()
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dismissAddActions() {
        withAnimation(.smooth(duration: 0.25)) {
            showAddActions = false
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Person.self, Encounter.self], inMemory: true)
}
