import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            EncounterListView()
                .tabItem {
                    Label("Encounters", systemImage: "person.2.crop.square.stack")
                }

            PeopleListView()
                .tabItem {
                    Label("People", systemImage: "person.3")
                }

            PhotoImportView()
                .tabItem {
                    Label("Import", systemImage: "photo.badge.plus")
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
