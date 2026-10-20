import SwiftUI

@main
struct ISpeakApp: App {
    var body: some Scene {
        WindowGroup {
            AppBootstrap().preferredColorScheme(.light)
        }
    }
}

struct AppBootstrap: View {
    @State private var store: LearningStore?
    @State private var loadError: String?
    var body: some View {
        Group {
            if let store { RootView().environmentObject(store) }
            else if let loadError {
                ContentUnavailableView("句库暂时无法打开", systemImage: "book.closed", description: Text(loadError))
            } else { ProgressView().tint(.forest) }
        }
        .task {
            guard store == nil else { return }
            do {
                let args = ProcessInfo.processInfo.arguments
                var storageURL: URL?
                if args.contains("-ui-testing") {
                    storageURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                        .appendingPathComponent("iSpeakUITests/progress.json")
                    if args.contains("-ui-reset"), let storageURL, FileManager.default.fileExists(atPath: storageURL.path) {
                        try FileManager.default.removeItem(at: storageURL)
                    }
                }
                store = LearningStore(curriculum: try Curriculum.load(), storageURL: storageURL)
            }
            catch { loadError = error.localizedDescription }
        }
    }
}

@MainActor final class AppNavigation: ObservableObject {
    @Published var tab = 0
}

struct RootView: View {
    @EnvironmentObject private var store: LearningStore
    @StateObject private var navigation = AppNavigation()
    var body: some View {
        TabView(selection: $navigation.tab) {
            StudyHomeView().tabItem { Label("学习", systemImage: "square.stack") }.tag(0)
            ReviewHomeView().tabItem { Label("背诵", systemImage: "arrow.triangle.2.circlepath") }.tag(1)
            LibraryView().tabItem { Label("句库", systemImage: "books.vertical") }.tag(2)
        }
        .tint(Color.forest)
        .environmentObject(navigation)
        .safeAreaInset(edge: .top, spacing: 0) { SaveStatusBanner() }
    }
}
