//
//  ContentView.swift
//  relink
//
//  Created by Abdullah Noor on 4/25/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var tabRouter = TabRouter()

    var body: some View {
        TabView(selection: $tabRouter.selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)

            PeopleView()
                .tabItem { Label("People", systemImage: "person.2") }
                .tag(AppTab.people)

            RecordView()
                .tabItem { Label("Record", systemImage: "mic.circle.fill") }
                .tag(AppTab.record)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(AppTab.search)

            InboxView()
                .tabItem { Label("Inbox", systemImage: "tray") }
                .tag(AppTab.inbox)
        }
        .tint(.purple)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color(.systemBackground), for: .tabBar)
        .environmentObject(tabRouter)
    }
}

#Preview {
    ContentView()
}
