import SwiftUI
import SwiftData

@Observable
class AppState {
    var sharedImageURL: URL?
    var shouldProcessSharedImage = false
}

@main
struct FaceRecallApp: App {
    @State private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Person.self,
            FaceEmbedding.self,
            ImportedPhoto.self,
            Encounter.self,
            Tag.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleIncomingURL(_ url: URL) {
        // Handle facerecall://import?url=<encoded_url>
        guard url.scheme == "facerecall",
              url.host == "import",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let urlParam = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let imageURL = URL(string: urlParam) else {
            return
        }

        appState.sharedImageURL = imageURL
        appState.shouldProcessSharedImage = true
    }
}
