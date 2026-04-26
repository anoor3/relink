//
//  relinkApp.swift
//  relink
//
//  Created by Abdullah Noor on 4/25/26.
//

import SwiftUI

@main
struct relinkApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .onAppear {
                    DemoSeeder.seedIfNeeded(userID: "user_1")
                    RichDemoSeeder.seedIfNeeded(userID: "user_1")
                    // Best-effort: sync local people to Nia for semantic search.
                    if NiaClient.shared.isConfigured {
                        let persons = LocalStore.shared.getPersons(userID: "user_1")
                        for person in persons {
                            Task { try? await NiaClient.shared.savePersonContext(person: person) }
                        }
                    }
                }
        }
    }
}
