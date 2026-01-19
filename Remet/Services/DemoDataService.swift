import Foundation
import SwiftData
import UIKit

/// Service to seed demo data for App Store screenshots
final class DemoDataService {

    // MARK: - Profile Definitions

    struct ProfileData {
        let assetName: String
        let name: String
        let howWeMet: String
        let tags: [String]
        let talkingPoints: [String]
        let relationship: String?
        let contextTag: String?
        let isMe: Bool
        let email: String?
        let phone: String?
        let company: String?
        let jobTitle: String?

        init(
            assetName: String,
            name: String,
            howWeMet: String,
            tags: [String],
            talkingPoints: [String],
            relationship: String? = nil,
            contextTag: String? = nil,
            isMe: Bool = false,
            email: String? = nil,
            phone: String? = nil,
            company: String? = nil,
            jobTitle: String? = nil
        ) {
            self.assetName = assetName
            self.name = name
            self.howWeMet = howWeMet
            self.tags = tags
            self.talkingPoints = talkingPoints
            self.relationship = relationship
            self.contextTag = contextTag
            self.isMe = isMe
            self.email = email
            self.phone = phone
            self.company = company
            self.jobTitle = jobTitle
        }
    }

    static let profiles: [ProfileData] = [
        // Me profile
        ProfileData(
            assetName: "demo_me",
            name: "Me",
            howWeMet: "This is me",
            tags: ["Me", "Owner"],
            talkingPoints: [],
            isMe: true
        ),
        // 1. Alex Chen
        ProfileData(
            assetName: "demo_alex_chen",
            name: "Alex Chen",
            howWeMet: "Tech meetup",
            tags: ["Tech", "Startup"],
            talkingPoints: ["AI founder", "Soft voice"],
            relationship: "Acquaintance",
            contextTag: "Work",
            email: "alex.chen@neuralworks.ai",
            phone: "+1 (415) 555-0142",
            company: "NeuralWorks AI",
            jobTitle: "Founder & CEO"
        ),
        // 2. Maya Rodriguez
        ProfileData(
            assetName: "demo_maya_rodriguez",
            name: "Maya Rodriguez",
            howWeMet: "Friend's wedding",
            tags: ["Designer"],
            talkingPoints: ["Curly hair", "Bold laugh", "Graphic design"],
            relationship: "Friend",
            contextTag: "Event",
            email: "maya.r@creativestudio.co",
            phone: "+1 (323) 555-0198"
        ),
        // 3. Kenji Sato
        ProfileData(
            assetName: "demo_kenji_sato",
            name: "Kenji Sato",
            howWeMet: "Tokyo conference",
            tags: ["Japan", "Consulting"],
            talkingPoints: ["Minimalist style", "Precise English"],
            relationship: "Coworker",
            contextTag: "Work",
            email: "k.sato@mckinsey.com",
            company: "McKinsey & Company",
            jobTitle: "Senior Consultant"
        ),
        // 4. Emily Parker
        ProfileData(
            assetName: "demo_emily_parker",
            name: "Emily Parker",
            howWeMet: "Hiking group",
            tags: ["Outdoors"],
            talkingPoints: ["Freckles", "Trail maps", "Golden retriever"],
            relationship: "Friend",
            contextTag: "Event",
            phone: "+1 (503) 555-0167"
        ),
        // 5. Daniel Wu
        ProfileData(
            assetName: "demo_daniel_wu",
            name: "Daniel Wu",
            howWeMet: "Startup pitch night",
            tags: ["Investor", "Fintech"],
            talkingPoints: ["Firm handshake", "Talks fast"],
            relationship: "Acquaintance",
            contextTag: "Work",
            email: "daniel@sequoia.com",
            phone: "+1 (650) 555-0123",
            company: "Sequoia Capital",
            jobTitle: "Partner"
        ),
        // 6. Sarah Thompson
        ProfileData(
            assetName: "demo_sarah_thompson",
            name: "Sarah Thompson",
            howWeMet: "Yoga studio",
            tags: ["Wellness", "Yoga"],
            talkingPoints: ["Calm tone", "Sunrise classes"],
            relationship: "Acquaintance",
            contextTag: "Event",
            email: "sarah@zenflow.yoga"
        ),
        // 7. Omar Hassan
        ProfileData(
            assetName: "demo_omar_hassan",
            name: "Omar Hassan",
            howWeMet: "Co-working space",
            tags: ["Remote", "Product"],
            talkingPoints: ["Beard", "Notion power user"],
            relationship: "Coworker",
            contextTag: "Work",
            email: "omar.hassan@notion.so",
            phone: "+1 (415) 555-0189",
            company: "Notion",
            jobTitle: "Product Manager"
        ),
        // 8. Lina Muller
        ProfileData(
            assetName: "demo_lina_muller",
            name: "Lina Müller",
            howWeMet: "Berlin art gallery",
            tags: ["Art", "Europe"],
            talkingPoints: ["Minimal makeup", "Abstract art"],
            relationship: "Friend",
            contextTag: "Event",
            email: "lina.m@berlinart.de"
        ),
        // 9. Carlos Mendes
        ProfileData(
            assetName: "demo_carlos_mendes",
            name: "Carlos Mendes",
            howWeMet: "Tennis club",
            tags: ["Sports", "Brazil"],
            talkingPoints: ["Loud laugh", "Topspin serve"],
            relationship: "Friend",
            contextTag: "Event",
            phone: "+55 11 98765-4321"
        ),
        // 10. Priya Nair
        ProfileData(
            assetName: "demo_priya_nair",
            name: "Priya Nair",
            howWeMet: "Client meeting",
            tags: ["Data", "Enterprise"],
            talkingPoints: ["Soft-spoken", "Python jokes"],
            relationship: "Client",
            contextTag: "Work",
            email: "priya.nair@databricks.com",
            phone: "+1 (408) 555-0156",
            company: "Databricks",
            jobTitle: "Data Scientist"
        ),
        // 11. Michael Johnson
        ProfileData(
            assetName: "demo_michael_johnson",
            name: "Michael Johnson",
            howWeMet: "Neighborhood BBQ",
            tags: ["Dad", "Local"],
            talkingPoints: ["Smoker grill", "Craft beer"],
            relationship: "Acquaintance",
            contextTag: "Neighborhood",
            phone: "+1 (510) 555-0134"
        ),
        // 12. Yuki Tanaka
        ProfileData(
            assetName: "demo_yuki_tanaka",
            name: "Yuki Tanaka",
            howWeMet: "Language exchange",
            tags: ["Japanese", "Language"],
            talkingPoints: ["Cute stationery", "Shy smile"],
            relationship: "Friend",
            contextTag: "Event",
            email: "yuki.tanaka@gmail.com"
        ),
        // 13. Robert Klein
        ProfileData(
            assetName: "demo_robert_klein",
            name: "Robert Klein",
            howWeMet: "Academic workshop",
            tags: ["Research", "Professor"],
            talkingPoints: ["Slow speech", "Philosophy quotes"],
            relationship: "Mentor",
            contextTag: "School",
            email: "r.klein@stanford.edu",
            company: "Stanford University",
            jobTitle: "Professor of Philosophy"
        ),
        // 14. Sofia Alvarez
        ProfileData(
            assetName: "demo_sofia_alvarez",
            name: "Sofia Alvarez",
            howWeMet: "Marketing summit",
            tags: ["Marketing", "LATAM"],
            talkingPoints: ["Strong perfume", "Keynote speaker"],
            relationship: "Acquaintance",
            contextTag: "Work",
            email: "sofia@hubspot.com",
            phone: "+52 55 1234 5678",
            company: "HubSpot",
            jobTitle: "VP of Marketing, LATAM"
        ),
        // 15. Jason Lee
        ProfileData(
            assetName: "demo_jason_lee",
            name: "Jason Lee",
            howWeMet: "Hackathon",
            tags: ["Student", "AI"],
            talkingPoints: ["Energy drink", "Night coder"],
            relationship: "Acquaintance",
            contextTag: "Event",
            email: "jason.lee@berkeley.edu"
        ),
        // 16. Anna Kowalska
        ProfileData(
            assetName: "demo_anna_kowalska",
            name: "Anna Kowalska",
            howWeMet: "Train in Prague",
            tags: ["Travel", "Europe"],
            talkingPoints: ["Vintage camera", "Quiet voice"],
            relationship: "Friend",
            contextTag: "Event",
            email: "anna.k@outlook.com"
        ),
        // 17. Victor Nguyen
        ProfileData(
            assetName: "demo_victor_nguyen",
            name: "Victor Nguyen",
            howWeMet: "SaaS demo call",
            tags: ["Sales", "B2B"],
            talkingPoints: ["Polite laugh", "Follow-up emails"],
            relationship: "Acquaintance",
            contextTag: "Work",
            email: "victor.nguyen@salesforce.com",
            phone: "+1 (628) 555-0145",
            company: "Salesforce",
            jobTitle: "Account Executive"
        ),
        // 18. Rachel Kim
        ProfileData(
            assetName: "demo_rachel_kim",
            name: "Rachel Kim",
            howWeMet: "Book club",
            tags: ["Reading", "Nonfiction"],
            talkingPoints: ["Highlights books", "Deep questions"],
            relationship: "Friend",
            contextTag: "Event",
            phone: "+1 (206) 555-0172"
        ),
        // 19. Thomas Becker
        ProfileData(
            assetName: "demo_thomas_becker",
            name: "Thomas Becker",
            howWeMet: "Airport lounge",
            tags: ["Consultant", "Frequent Flyer"],
            talkingPoints: ["Early boarding", "Espresso"],
            relationship: "Acquaintance",
            contextTag: "Work",
            email: "t.becker@bcg.com",
            company: "Boston Consulting Group",
            jobTitle: "Managing Director"
        ),
        // 20. Mei Lin
        ProfileData(
            assetName: "demo_mei_lin",
            name: "Mei Lin",
            howWeMet: "Coffee shop",
            tags: ["Cafe", "Local"],
            talkingPoints: ["Latte art heart", "Remembers names"],
            relationship: "Acquaintance",
            contextTag: "Neighborhood"
        )
    ]

    // MARK: - Encounter Definitions

    struct EncounterData {
        let occasion: String
        let location: String
        let photoAssets: [String]
        let peopleNames: [String]
        let daysAgo: Int
        let tags: [String]
    }

    static let encounters: [EncounterData] = [
        // Encounter 1: Tech Meetup Night
        EncounterData(
            occasion: "Tech Meetup Night",
            location: "San Francisco, CA",
            photoAssets: ["demo_encounter_Photo1A", "demo_encounter_Photo1B", "demo_encounter_Photo1C"],
            peopleNames: ["Alex Chen", "Daniel Wu", "Jason Lee", "Omar Hassan"],
            daysAgo: 14,
            tags: ["Tech", "Startup", "AI"]
        ),
        // Encounter 2: Friend's Wedding
        EncounterData(
            occasion: "Sarah & Mike's Wedding",
            location: "Napa Valley, CA",
            photoAssets: ["demo_encounter_Photo2A", "demo_encounter_Photo2B", "demo_encounter_Photo2C"],
            peopleNames: ["Maya Rodriguez", "Michael Johnson", "Sofia Alvarez"],
            daysAgo: 30,
            tags: ["Friends", "Wedding", "Celebration"]
        ),
        // Encounter 3: Conference / Business Trip
        EncounterData(
            occasion: "Tech Conference 2024",
            location: "Tokyo, Japan",
            photoAssets: ["demo_encounter_Photo3A", "demo_encounter_Photo3B", "demo_encounter_Photo3C"],
            peopleNames: ["Kenji Sato", "Priya Nair", "Victor Nguyen", "Thomas Becker"],
            daysAgo: 45,
            tags: ["Japan", "Consulting", "Enterprise"]
        ),
        // Encounter 4: Local & Everyday Life
        EncounterData(
            occasion: "Weekend Coffee Meetup",
            location: "Local Cafe",
            photoAssets: ["demo_encounter_Photo4A", "demo_encounter_Photo4B", "demo_encounter_Photo4C"],
            peopleNames: ["Emily Parker", "Rachel Kim", "Mei Lin"],
            daysAgo: 7,
            tags: ["Local", "Cafe", "Friends"]
        ),
        // Encounter 5: Travel & Serendipity
        EncounterData(
            occasion: "European Adventure",
            location: "Prague, Czech Republic",
            photoAssets: ["demo_encounter_Photo5A", "demo_encounter_Photo5B", "demo_encounter_Photo5C"],
            peopleNames: ["Lina Müller", "Carlos Mendes", "Anna Kowalska", "Yuki Tanaka"],
            daysAgo: 60,
            tags: ["Travel", "Europe", "Art"]
        )
    ]

    // MARK: - Tag Colors

    static let tagColors: [String: String] = [
        // Profile tags
        "Tech": TagColor.blue.hex,
        "Startup": TagColor.indigo.hex,
        "Designer": TagColor.purple.hex,
        "Japan": TagColor.red.hex,
        "Consulting": TagColor.teal.hex,
        "Outdoors": TagColor.green.hex,
        "Investor": TagColor.indigo.hex,
        "Fintech": TagColor.cyan.hex,
        "Wellness": TagColor.mint.hex,
        "Yoga": TagColor.pink.hex,
        "Remote": TagColor.orange.hex,
        "Product": TagColor.blue.hex,
        "Art": TagColor.purple.hex,
        "Europe": TagColor.orange.hex,
        "Sports": TagColor.green.hex,
        "Brazil": TagColor.yellow.hex,
        "Data": TagColor.cyan.hex,
        "Enterprise": TagColor.indigo.hex,
        "Dad": TagColor.brown.hex,
        "Local": TagColor.mint.hex,
        "Japanese": TagColor.red.hex,
        "Language": TagColor.teal.hex,
        "Research": TagColor.indigo.hex,
        "Professor": TagColor.brown.hex,
        "Marketing": TagColor.pink.hex,
        "LATAM": TagColor.orange.hex,
        "Student": TagColor.yellow.hex,
        "AI": TagColor.blue.hex,
        "Travel": TagColor.orange.hex,
        "Sales": TagColor.green.hex,
        "B2B": TagColor.indigo.hex,
        "Reading": TagColor.purple.hex,
        "Nonfiction": TagColor.brown.hex,
        "Consultant": TagColor.teal.hex,
        "Frequent Flyer": TagColor.cyan.hex,
        "Cafe": TagColor.brown.hex,
        "Me": TagColor.red.hex,
        "Owner": TagColor.blue.hex,
        // Encounter tags
        "Friends": TagColor.pink.hex,
        "Wedding": TagColor.purple.hex,
        "Celebration": TagColor.yellow.hex
    ]

    // MARK: - Seed Methods

    @MainActor
    static func seedDemoData(modelContext: ModelContext) async {
        let faceDetectionService = FaceDetectionService()
        let embeddingService = FaceEmbeddingService()

        // First, create all tags (from profiles and encounters)
        var tagMap: [String: Tag] = [:]
        let profileTags = Set(profiles.flatMap { $0.tags })
        let encounterTags = Set(encounters.flatMap { $0.tags })
        let allTagNames = profileTags.union(encounterTags)

        for tagName in allTagNames {
            let colorHex = tagColors[tagName] ?? TagColor.blue.hex
            let tag = Tag(name: tagName, colorHex: colorHex)
            modelContext.insert(tag)
            tagMap[tagName] = tag
        }

        // Create people with their profiles
        var personMap: [String: Person] = [:]

        for profile in profiles {
            let person = Person(
                name: profile.name,
                relationship: profile.relationship,
                contextTag: profile.contextTag
            )
            person.isMe = profile.isMe
            person.howWeMet = profile.howWeMet
            person.talkingPoints = profile.talkingPoints
            person.email = profile.email
            person.phone = profile.phone
            person.company = profile.company
            person.jobTitle = profile.jobTitle

            // Load profile photo, detect face, and generate embedding
            if let image = UIImage(named: profile.assetName) {
                // Try face detection first (works on device, may fail on simulator)
                var usedFaceDetection = false

                do {
                    let detectedFaces = try await faceDetectionService.detectFaces(
                        in: image,
                        options: .enhanced
                    )

                    if let face = detectedFaces.first,
                       let faceCropData = face.cropImage.jpegData(compressionQuality: 0.8) {
                        // Generate real embedding vector
                        let embeddingVector = try await embeddingService.generateEmbedding(for: face.cropImage)
                        let vectorData = embeddingVector.withUnsafeBytes { Data($0) }

                        let embedding = FaceEmbedding(
                            vector: vectorData,
                            faceCropData: faceCropData
                        )
                        embedding.person = person
                        person.embeddings.append(embedding)
                        person.profileEmbeddingId = embedding.id
                        modelContext.insert(embedding)
                        usedFaceDetection = true
                    }
                } catch {
                    // Face detection failed (common on simulator)
                }

                // Fallback: use resized profile photo directly
                if !usedFaceDetection {
                    // Create a square crop from center of image for better thumbnail
                    let croppedImage = createSquareCrop(from: image)
                    if let imageData = croppedImage.jpegData(compressionQuality: 0.8) {
                        let embedding = FaceEmbedding(
                            vector: Data(),
                            faceCropData: imageData
                        )
                        embedding.person = person
                        person.embeddings.append(embedding)
                        person.profileEmbeddingId = embedding.id
                        modelContext.insert(embedding)
                    }
                }
            }

            // Assign tags
            for tagName in profile.tags {
                if let tag = tagMap[tagName] {
                    person.tags.append(tag)
                }
            }

            // Create spaced repetition data
            let srData = SpacedRepetitionData()
            srData.person = person
            person.spacedRepetitionData = srData
            modelContext.insert(srData)

            modelContext.insert(person)
            personMap[profile.name] = person
        }

        // Create encounters
        for encounterData in encounters {
            let date = Calendar.current.date(byAdding: .day, value: -encounterData.daysAgo, to: Date()) ?? Date()

            let encounter = Encounter(
                occasion: encounterData.occasion,
                location: encounterData.location,
                date: date
            )

            // Add photos
            for (index, assetName) in encounterData.photoAssets.enumerated() {
                if let image = UIImage(named: assetName),
                   let imageData = image.jpegData(compressionQuality: 0.8) {
                    let photoDate = Calendar.current.date(byAdding: .minute, value: index * 5, to: date) ?? date
                    let photo = EncounterPhoto(imageData: imageData, date: photoDate)
                    photo.encounter = encounter
                    encounter.photos.append(photo)
                    modelContext.insert(photo)

                    // Set thumbnail from first photo
                    if index == 0 {
                        encounter.thumbnailData = image.jpegData(compressionQuality: 0.5)
                    }
                }
            }

            // Link people
            for personName in encounterData.peopleNames {
                if let person = personMap[personName] {
                    encounter.people.append(person)
                    person.encounters.append(encounter)
                }
            }

            // Assign tags to encounter
            for tagName in encounterData.tags {
                if let tag = tagMap[tagName] {
                    encounter.tags.append(tag)
                }
            }

            modelContext.insert(encounter)
        }

        // Save
        // Seed quiz history for impressive Practice stats
        await seedQuizHistory(modelContext: modelContext, personMap: personMap)

        try? modelContext.save()
    }

    /// Seed demo quiz history to make Practice stats look impressive for screenshots
    @MainActor
    private static func seedQuizHistory(modelContext: ModelContext, personMap: [String: Person]) async {
        // People who have been "mastered" (multiple correct reviews)
        let masteredPeople = ["Maya Rodriguez", "Emily Parker", "Carlos Mendes", "Lina Müller", "Rachel Kim"]

        // People with some attempts but not mastered
        let practicedPeople = ["Alex Chen", "Kenji Sato", "Daniel Wu", "Omar Hassan", "Sofia Alvarez",
                               "Michael Johnson", "Priya Nair", "Victor Nguyen"]

        for name in masteredPeople {
            guard let person = personMap[name],
                  let srData = person.spacedRepetitionData else { continue }

            // Create 3-5 successful quiz attempts over past weeks
            let attemptCount = Int.random(in: 3...5)
            for i in 0..<attemptCount {
                let daysAgo = (attemptCount - i) * 3 + Int.random(in: 0...2)
                let attemptDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()

                let attempt = QuizAttempt(
                    wasCorrect: true,
                    responseTimeMs: Int.random(in: 1500...4000),
                    attemptedAt: attemptDate
                )
                attempt.person = person
                person.quizAttempts.append(attempt)
                modelContext.insert(attempt)
            }

            // Update spaced repetition data for mastered state
            srData.totalAttempts = attemptCount
            srData.correctAttempts = attemptCount
            srData.repetitions = attemptCount
            srData.easeFactor = 2.5 + Double(attemptCount) * 0.1
            srData.interval = 7 * attemptCount // Longer intervals for mastered
            srData.lastReviewDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())
            srData.nextReviewDate = Calendar.current.date(byAdding: .day, value: srData.interval - 2, to: Date()) ?? Date()
        }

        for name in practicedPeople {
            guard let person = personMap[name],
                  let srData = person.spacedRepetitionData else { continue }

            // Create 1-3 attempts, mix of correct and incorrect
            let attemptCount = Int.random(in: 1...3)
            var correctCount = 0

            for i in 0..<attemptCount {
                let daysAgo = (attemptCount - i) * 2 + Int.random(in: 0...1)
                let attemptDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
                let wasCorrect = i == attemptCount - 1 || Bool.random() // Last attempt usually correct

                if wasCorrect { correctCount += 1 }

                let attempt = QuizAttempt(
                    wasCorrect: wasCorrect,
                    responseTimeMs: Int.random(in: 2000...6000),
                    attemptedAt: attemptDate,
                    userGuess: wasCorrect ? nil : "Someone else"
                )
                attempt.person = person
                person.quizAttempts.append(attempt)
                modelContext.insert(attempt)
            }

            // Update spaced repetition - these are due for review
            srData.totalAttempts = attemptCount
            srData.correctAttempts = correctCount
            srData.repetitions = correctCount
            srData.lastReviewDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())
            srData.nextReviewDate = Date() // Due now
        }

        // Remaining people have no quiz history - they're "new" and due for first review
        // (already set up with nextReviewDate = Date() by default)
    }

    /// Create a square crop from the center-top of the image (for face photos)
    private static func createSquareCrop(from image: UIImage) -> UIImage {
        let size = min(image.size.width, image.size.height)
        // Crop from top-center (faces are usually in upper portion of portrait photos)
        let x = (image.size.width - size) / 2
        let y = image.size.height * 0.05 // Start slightly from top
        let cropRect = CGRect(x: x, y: y, width: size, height: size)

        guard let cgImage = image.cgImage,
              let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return image
        }

        // Resize to reasonable thumbnail size
        let targetSize = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            UIImage(cgImage: croppedCGImage).draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// Clear all existing data before seeding
    @MainActor
    static func clearAllData(modelContext: ModelContext) {
        // Fetch and delete all items for each model type
        // Delete in order to respect relationships

        // QuizAttempts
        let quizAttempts = (try? modelContext.fetch(FetchDescriptor<QuizAttempt>())) ?? []
        for item in quizAttempts { modelContext.delete(item) }

        // InteractionNotes
        let notes = (try? modelContext.fetch(FetchDescriptor<InteractionNote>())) ?? []
        for item in notes { modelContext.delete(item) }

        // SpacedRepetitionData
        let srData = (try? modelContext.fetch(FetchDescriptor<SpacedRepetitionData>())) ?? []
        for item in srData { modelContext.delete(item) }

        // FaceEmbeddings
        let embeddings = (try? modelContext.fetch(FetchDescriptor<FaceEmbedding>())) ?? []
        for item in embeddings { modelContext.delete(item) }

        // EncounterPhotos
        let photos = (try? modelContext.fetch(FetchDescriptor<EncounterPhoto>())) ?? []
        for item in photos { modelContext.delete(item) }

        // Encounters
        let encounters = (try? modelContext.fetch(FetchDescriptor<Encounter>())) ?? []
        for item in encounters { modelContext.delete(item) }

        // People
        let people = (try? modelContext.fetch(FetchDescriptor<Person>())) ?? []
        for item in people { modelContext.delete(item) }

        // Tags
        let tags = (try? modelContext.fetch(FetchDescriptor<Tag>())) ?? []
        for item in tags { modelContext.delete(item) }

        // ImportedPhotos
        let imported = (try? modelContext.fetch(FetchDescriptor<ImportedPhoto>())) ?? []
        for item in imported { modelContext.delete(item) }

        try? modelContext.save()
    }
}
