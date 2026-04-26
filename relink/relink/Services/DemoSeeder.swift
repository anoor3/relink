import Foundation

enum DemoSeeder {
    private static let seededKey = "relink_demo_seeded_v1"

    static func seedIfNeeded(userID: String = "user_1") {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: seededKey) == false else { return }

        let store = LocalStore.shared
        let existing = store.getPersons(userID: userID)
        guard existing.isEmpty else {
            defaults.set(true, forKey: seededKey)
            return
        }

        let now = Date()

        let people: [Person] = [
            Person(
                id: "p_demo_rohan",
                userID: userID,
                name: "Jordan Miller",
                company: "FinEdge",
                role: "Co-founder",
                topicsDiscussed: ["AI in fintech", "risk scoring"],
                personalDetails: ["Lives in Bangalore"],
                signals: ["Posted about AI distribution recently"],
                sentiment: "warm",
                followUpIntent: "Reply to his post and offer a quick catch-up",
                relationshipStrength: 8,
                tags: ["Fintech", "AI/ML", "Startups"],
                email: "jordan@example.com",
                photoFilename: nil,
                lastContact: Calendar.current.date(byAdding: .day, value: -68, to: now),
                createdAt: now,
                interactions: []
            ),
            Person(
                id: "p_demo_ananya",
                userID: userID,
                name: "Sofia Chen",
                company: "Stripe",
                role: "Product at Stripe",
                topicsDiscussed: ["payments", "product strategy"],
                personalDetails: ["Running her first marathon"],
                signals: ["Her company just raised a new internal growth initiative"],
                sentiment: "warm",
                followUpIntent: "Ask how the new team is going",
                relationshipStrength: 7,
                tags: ["Product", "Payments"],
                email: "sofia@example.com",
                photoFilename: nil,
                lastContact: Calendar.current.date(byAdding: .day, value: -45, to: now),
                createdAt: now,
                interactions: []
            ),
            Person(
                id: "p_demo_kabir",
                userID: userID,
                name: "Ethan Brooks",
                company: "Sequoia",
                role: "Investor",
                topicsDiscussed: ["AI infrastructure", "developer tools"],
                personalDetails: ["Wants intros to strong infra founders"],
                signals: ["Asked for a few founder intros"],
                sentiment: "neutral",
                followUpIntent: "Send 1-2 founder updates and ask what he’s leaning into",
                relationshipStrength: 6,
                tags: ["Investor", "AI Infra"],
                email: "ethan@example.com",
                photoFilename: nil,
                lastContact: Calendar.current.date(byAdding: .day, value: -120, to: now),
                createdAt: now,
                interactions: []
            ),
            Person(
                id: "p_demo_neha",
                userID: userID,
                name: "Maya Thompson",
                company: "Accel",
                role: "Partner",
                topicsDiscussed: ["fintech", "go-to-market"],
                personalDetails: ["Based in Delhi"],
                signals: ["Interested in seed-stage fintech"],
                sentiment: "warm",
                followUpIntent: "Share a fintech founder you met recently",
                relationshipStrength: 7,
                tags: ["Investor", "Fintech"],
                email: "maya@example.com",
                photoFilename: nil,
                lastContact: Calendar.current.date(byAdding: .day, value: -60, to: now),
                createdAt: now,
                interactions: []
            ),
            Person(
                id: "p_demo_ritesh",
                userID: userID,
                name: "Lucas Garcia",
                company: "Angel Network",
                role: "Angel Investor",
                topicsDiscussed: ["consumer apps", "distribution"],
                personalDetails: ["Recently moved to Mumbai"],
                signals: ["Open to co-investing"],
                sentiment: "warm",
                followUpIntent: "Follow up with a founder deck and ask for feedback",
                relationshipStrength: 6,
                tags: ["Angel", "Consumer"],
                email: "lucas@example.com",
                photoFilename: nil,
                lastContact: Calendar.current.date(byAdding: .day, value: -40, to: now),
                createdAt: now,
                interactions: []
            ),
        ]

        for person in people {
            store.upsertPerson(person)

            let memo = Interaction(
                id: "i_demo_\(person.id)",
                personID: person.id,
                type: "voice_memo",
                content: "Met \(person.name) and talked about \((person.topicsDiscussed ?? []).joined(separator: ", ")).",
                createdAt: person.lastContact ?? now
            )
            store.addInteraction(personID: person.id, interaction: memo)
        }

        defaults.set(true, forKey: seededKey)
    }
}
