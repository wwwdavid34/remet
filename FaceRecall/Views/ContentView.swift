import SwiftUI
import UIKit

struct ContentView: View {
    init() {
        // Configure tab bar with system appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

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
                    Label("Capture", systemImage: "camera.fill")
                }

            PracticeHomeView()
                .tabItem {
                    Label("Practice", systemImage: "brain.head.profile")
                }

            GlobalSearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
        }
        .tint(AppColors.coral)
    }
}

#Preview {
    ContentView()
}
