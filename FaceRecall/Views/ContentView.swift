import SwiftUI
import SwiftData
import UIKit

/// Main app container with floating pill tab bar + floating action button
/// Core philosophy: Quick capture and review should be 1 tap away
struct ContentView: View {
    @Query private var people: [Person]

    @State private var selectedTab = 0
    @State private var showQuickCapture = false
    @State private var showPhotoImport = false

    private var tabItems: [FloatingTabItem] {
        [
            FloatingTabItem(id: 0, icon: "person.3", label: String(localized: "People")),
            FloatingTabItem(id: 1, icon: "brain.head.profile", label: String(localized: "Practice")),
            FloatingTabItem(id: 2, icon: "eye", label: String(localized: "Identify"))
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case 0:
                    PeopleHomeView()
                case 1:
                    PracticeHomeView()
                case 2:
                    ScanTabView()
                default:
                    PeopleHomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating pill tab bar
            FloatingTabBar(selectedTab: $selectedTab, items: tabItems)

            // Floating Action Button - tap shows menu for capture options
            FloatingActionButton(
                primaryAction: { },
                quickActions: captureActions,
                expandOnTap: true
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $showQuickCapture) {
            QuickCaptureView()
        }
        .sheet(isPresented: $showPhotoImport) {
            PhotoImportView()
        }
    }

    // MARK: - Capture Actions (for FAB menu)

    private var captureActions: [QuickAction] {
        [
            QuickAction(
                icon: "camera.fill",
                label: String(localized: "Take Photo"),
                color: AppColors.coral
            ) {
                showQuickCapture = true
            },
            QuickAction(
                icon: "photo.on.rectangle",
                label: String(localized: "Import Photo"),
                color: AppColors.teal
            ) {
                showPhotoImport = true
            }
        ]
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Person.self, Encounter.self], inMemory: true)
}
