import SwiftUI
import SwiftData

/// Main app container with native tab bar + circle add button (App Store search style).
struct ContentView: View {
    @Query private var people: [Person]

    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showQuickCapture = false
    @State private var showPhotoImport = false
    @State private var showAddMenu = false

    var body: some View {
        tabView
            .onChange(of: selectedTab) { _, newValue in
                guard newValue == 3 else {
                    previousTab = newValue
                    return
                }
                selectedTab = previousTab
                showAddMenu = true
            }
            .ignoresSafeArea(.keyboard)
            .confirmationDialog(String(localized: "Add"), isPresented: $showAddMenu, titleVisibility: .visible) {
                Button(String(localized: "Take Photo")) {
                    showQuickCapture = true
                }
                Button(String(localized: "Import Photo")) {
                    showPhotoImport = true
                }
                Button(String(localized: "Cancel"), role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showQuickCapture) {
                QuickCaptureView()
            }
            .sheet(isPresented: $showPhotoImport) {
                PhotoImportView()
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
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Person.self, Encounter.self], inMemory: true)
}
