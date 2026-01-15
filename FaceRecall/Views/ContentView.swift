import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            PeopleListView()
                .tabItem {
                    Label("People", systemImage: "person.3")
                }

            PracticeHomeView()
                .tabItem {
                    Label("Practice", systemImage: "brain.head.profile")
                }

            AddView()
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}
