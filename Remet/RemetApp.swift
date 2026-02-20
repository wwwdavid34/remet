import SwiftUI
import SwiftData

@Observable
class AppState {
    var sharedImageURL: URL?
    var shouldProcessSharedImage = false
    var sharedFacebookURL: URL?
}

@main
struct RemetApp: App {
    @State private var appState = AppState()
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var cloudSyncManager = CloudSyncManager.shared
    @State private var showSplash = true

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Person.self,
            FaceEmbedding.self,
            ImportedPhoto.self,
            Encounter.self,
            EncounterPhoto.self,
            Tag.self,
            InteractionNote.self,
            SpacedRepetitionData.self,
            QuizAttempt.self
        ])

        // First try with CloudKit enabled for sync capability
        do {
            let cloudConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private(CloudSyncManager.containerIdentifier)
            )
            let container = try ModelContainer(for: schema, configurations: [cloudConfig])
            print("=== ModelContainer Created with CloudKit ===")
            return container
        } catch {
            // Log CloudKit error details
            print("=== CloudKit ModelContainer Failed ===")
            print("Error: \(error)")
            print("Error Type: \(type(of: error))")
            print("Will attempt local-only storage...")
            print("========================================")

            // Fall back to local storage (sync will be disabled)
            do {
                let localConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .none
                )
                let container = try ModelContainer(for: schema, configurations: [localConfig])
                print("=== ModelContainer Created (Local Only) ===")
                return container
            } catch {
                print("=== Local ModelContainer Also Failed ===")
                print("Error: \(error)")
                print("=========================================")
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashView()
                } else if !AppSettings.shared.hasCompletedOnboarding {
                    OnboardingContainerView()
                } else {
                    ContentView()
                        .environment(appState)
                        .environment(subscriptionManager)
                        .environment(cloudSyncManager)
                        .onOpenURL { url in
                            handleIncomingURL(url)
                        }
                }
            }
            .task {
                // Pre-load FaceNet model during splash so it's ready for scan/import
                FaceEmbeddingService.shared.preload()
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
        guard url.scheme == "remet",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }

        if url.host == "import",
           let urlParam = components.queryItems?.first(where: { $0.name == "url" })?.value,
           let imageURL = URL(string: urlParam) {
            appState.sharedImageURL = imageURL
            appState.shouldProcessSharedImage = true
        } else if url.host == "facebook",
                  let urlParam = components.queryItems?.first(where: { $0.name == "url" })?.value,
                  let facebookURL = URL(string: urlParam) {
            appState.sharedFacebookURL = facebookURL
        }
    }
}
