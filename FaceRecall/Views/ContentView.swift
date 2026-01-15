import SwiftUI

struct ContentView: View {
    init() {
        // Set tab bar appearance with theme colors
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground

        // Selected item color
        UITabBar.appearance().tintColor = UIColor(AppColors.coral)

        // Unselected item color
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColors.textMuted)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppColors.textMuted)]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            PeopleListView()
                .tabItem {
                    Label("People", systemImage: "person.3.fill")
                }

            AddView()
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }

            PracticeHomeView()
                .tabItem {
                    Label("Practice", systemImage: "brain.head.profile")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(AppColors.coral)
    }
}

#Preview {
    ContentView()
}
