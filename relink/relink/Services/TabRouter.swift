import Foundation

enum AppTab: Hashable {
    case home
    case people
    case record
    case search
    case inbox
}

@MainActor
final class TabRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home
}

