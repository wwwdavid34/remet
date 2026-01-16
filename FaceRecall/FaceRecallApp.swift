import SwiftUI
import SwiftData

@Observable
class AppState {
    var sharedImageURL: URL?
    var shouldProcessSharedImage = false
}

@main
struct RemetApp: App {
    @State private var appState = AppState()
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showSplash = true

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Person.self,
            FaceEmbedding.self,
            ImportedPhoto.self,
            Encounter.self,
            Tag.self,
            InteractionNote.self,
            SpacedRepetitionData.self,
            QuizAttempt.self
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
            Group {
                if showSplash {
                    SplashView()
                } else {
                    ContentView()
                        .environment(appState)
                        .environment(subscriptionManager)
                        .onOpenURL { url in
                            handleIncomingURL(url)
                        }
                }
            }
            .task {
                // Record first launch for grace period tracking
                AppSettings.shared.recordFirstLaunchIfNeeded()
                // Load subscription products
                await subscriptionManager.loadProducts()

                // Dismiss splash after a brief delay
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation(.easeOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleIncomingURL(_ url: URL) {
        // Handle remet://import?url=<encoded_url>
        guard url.scheme == "remet",
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
