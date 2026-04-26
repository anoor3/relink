import Foundation

enum RichDemoSeeder {
    private static let seededKey = "relink_demo_rich_seeded_v1"

    static func seedIfNeeded(userID: String = "user_1") {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: seededKey) == false else { return }

        let store = LocalStore.shared
        let now = Date()

        let sharedEmail = "abdullahnoor.edu1@gmail.com"
        let sharedPhone = "123456789"

        let people: [Person] = [
            Person(
                id: "p_demo_rich_olivia",
                userID: userID,
                name: "Olivia Hart",
                company: "NorthBridge Ventures",
                role: "Investor",
                topicsDiscussed: ["seed rounds", "AI agents", "B2B distribution"],
                personalDetails: ["Based in NYC", "Runs a monthly founder dinner"],
                signals: ["Actively looking for AI-native startups", "Asked for a deck"],
                sentiment: "warm",
                followUpIntent: "Send the deck + a crisp 1-page on the wedge and go-to-market.",
                relationshipStrength: 7,
                tags: ["Investor", "Seed", "AI"],
                email: sharedEmail,
                phoneNumber: sharedPhone,
                linkedInURL: "https://linkedin.com/in/oliviahart",
                photoFilename: nil,
                contactIdentifier: nil,
                lastContact: Calendar.current.date(byAdding: .day, value: -12, to: now),
                createdAt: now,
                interactions: []
            ),
            Person(
                id: "p_demo_rich_marcus",
                userID: userID,
                name: "Marcus Reed",
                company: "ForgeWorks",
                role: "Founder",
                topicsDiscussed: ["developer tools", "open-source", "PLG"],
                personalDetails: ["Lives in Austin", "New baby"],
                signals: ["Hiring a founding engineer", "Wants intros to design leaders"],
                sentiment: "warm",
                followUpIntent: "Introduce him to 1-2 design leads and ask if he wants feedback on onboarding.",
                relationshipStrength: 8,
                tags: ["Founder", "DevTools", "PLG"],
                email: sharedEmail,
                phoneNumber: sharedPhone,
                linkedInURL: "https://linkedin.com/in/marcusreed",
                photoFilename: nil,
                contactIdentifier: nil,
                lastContact: Calendar.current.date(byAdding: .day, value: -35, to: now),
                createdAt: now,
                interactions: []
            ),
            Person(
                id: "p_demo_rich_sienna",
                userID: userID,
                name: "Sienna Park",
                company: "Pulse Robotics",
                role: "CTO",
                topicsDiscussed: ["robotics", "edge inference", "reliability"],
                personalDetails: ["Climbs on weekends", "Used to live in Seoul"],
                signals: ["Exploring partnerships", "Mentioned a pilot in Q3"],
                sentiment: "warm",
                followUpIntent: "Share a concise reliability checklist + ask about the Q3 pilot timeline.",
                relationshipStrength: 6,
                tags: ["CTO", "Robotics", "Edge AI"],
                email: sharedEmail,
                phoneNumber: sharedPhone,
                linkedInURL: "https://linkedin.com/in/siennapark",
                photoFilename: nil,
                contactIdentifier: nil,
                lastContact: Calendar.current.date(byAdding: .day, value: -58, to: now),
                createdAt: now,
                interactions: []
            ),
            Person(
                id: "p_demo_rich_noah",
                userID: userID,
                name: "Noah Bennett",
                company: "CloudNine",
                role: "Staff Engineer",
                topicsDiscussed: ["LLM infra", "evals", "cost optimization"],
                personalDetails: ["Ex-Google", "Plays jazz piano"],
                signals: ["Open to advising early-stage teams", "Asked about your architecture"],
                sentiment: "warm",
                followUpIntent: "Ask if he can do a 20-minute review of your eval strategy and cost plan.",
                relationshipStrength: 7,
                tags: ["Infra", "LLMs", "Advisor"],
                email: sharedEmail,
                phoneNumber: sharedPhone,
                linkedInURL: "https://linkedin.com/in/noahbennett",
                photoFilename: nil,
                contactIdentifier: nil,
                lastContact: Calendar.current.date(byAdding: .day, value: -9, to: now),
                createdAt: now,
                interactions: []
            ),
            Person(
                id: "p_demo_rich_ava",
                userID: userID,
                name: "Ava Sinclair",
                company: "Ridge Capital",
                role: "Partner",
                topicsDiscussed: ["fintech", "risk", "go-to-market"],
                personalDetails: ["Based in London", "Loves tennis"],
                signals: ["Asked who else in your network is building in fintech", "Interested in a warm intro"],
                sentiment: "neutral",
                followUpIntent: "Send 2 warm intros (with context) and ask what sectors she’s leaning into this quarter.",
                relationshipStrength: 6,
                tags: ["Investor", "Fintech"],
                email: sharedEmail,
                phoneNumber: sharedPhone,
                linkedInURL: "https://linkedin.com/in/avasinclair",
                photoFilename: nil,
                contactIdentifier: nil,
                lastContact: Calendar.current.date(byAdding: .day, value: -102, to: now),
                createdAt: now,
                interactions: []
            ),
            Person(
                id: "p_demo_rich_leo",
                userID: userID,
                name: "Leo Nakamura",
                company: "Arcade Labs",
                role: "Builder",
                topicsDiscussed: ["consumer AI", "viral loops", "product craft"],
                personalDetails: ["Lives in SF", "Design background"],
                signals: ["Wants to collaborate", "Asked for user feedback"],
                sentiment: "warm",
                followUpIntent: "Offer to test his product and share 3 concrete feedback points.",
                relationshipStrength: 9,
                tags: ["Builder", "Consumer", "Design"],
                email: sharedEmail,
                phoneNumber: sharedPhone,
                linkedInURL: "https://linkedin.com/in/leonakamura",
                photoFilename: nil,
                contactIdentifier: nil,
                lastContact: Calendar.current.date(byAdding: .day, value: -3, to: now),
                createdAt: now,
                interactions: []
            ),
        ]

        for person in people {
            store.upsertPerson(person)
            let memo = Interaction(
                id: "i_demo_rich_\(person.id)",
                personID: person.id,
                type: "voice_memo",
                content: "Demo note: met \(person.name). Key topics: \((person.topicsDiscussed ?? []).joined(separator: ", ")).",
                createdAt: person.lastContact ?? now
            )
            store.addInteraction(personID: person.id, interaction: memo)
        }

        defaults.set(true, forKey: seededKey)
    }
}

