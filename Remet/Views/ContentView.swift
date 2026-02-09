import SwiftUI
import SwiftData

/// Main app container with native tab bar and add action tab.
struct ContentView: View {
    @Query private var people: [Person]

    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showQuickCapture = false
    @State private var showPhotoImport = false
    @State private var showAddMenu = false

    var body: some View {
        TabView(selection: $selectedTab) {
            PeopleHomeView()
                .tag(0)
                .tabItem {
                    Label(String(localized: "People"), systemImage: "person.3")
                }

            PracticeHomeView()
                .tag(1)
                .tabItem {
                    Label(String(localized: "Practice"), systemImage: "brain.head.profile")
                }

            ScanTabView()
                .tag(2)
                .tabItem {
                    Label(String(localized: "Identify"), systemImage: "eye")
                }

            Color.clear
                .tag(3)
                .tabItem {
                    Label(String(localized: "Add"), systemImage: "plus")
                }
        }
        .onChange(of: selectedTab) { _, newValue in
            guard newValue == 3 else {
                previousTab = newValue
                return
            }

            selectedTab = previousTab
            DispatchQueue.main.async {
                showAddMenu = true
            }
        }
        .confirmationDialog(String(localized: "Add"), isPresented: $showAddMenu, titleVisibility: .visible) {
            Button(String(localized: "Take Photo")) {
                showQuickCapture = true
            }
            Button(String(localized: "Import Photo")) {
                showPhotoImport = true
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $showQuickCapture) {
            QuickCaptureView()
        }
        .sheet(isPresented: $showPhotoImport) {
            PhotoImportView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Person.self, Encounter.self], inMemory: true)
}
