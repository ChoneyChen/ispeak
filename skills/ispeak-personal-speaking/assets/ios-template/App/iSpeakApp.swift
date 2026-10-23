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
                let loaded = LearningStore(curriculum: try Curriculum.load(), storageURL: storageURL)
                if args.contains("-ui-testing") && args.contains("-ui-seed-review") && loaded.learnedCount == 0 {
                    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
                    let examples = loaded.curriculum.allSentences.prefix(15)
                    for sentence in examples { loaded.learn(sentence.id, now: yesterday) }
                    for sentence in examples.prefix(5) { loaded.recordReview(sentenceID: sentence.id, outcome: .correct, now: yesterday) }
                }
                store = loaded
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
    @StateObject private var reminders = ReminderManager()
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TabView(selection: $navigation.tab) {
            StudyHomeView().tabItem { Label("学习", systemImage: "square.stack") }.tag(0)
            ReviewHomeView().tabItem { Label("背诵", systemImage: "arrow.triangle.2.circlepath") }.tag(1)
            LibraryView().tabItem { Label("句库", systemImage: "books.vertical") }.tag(2)
        }
        .tint(Color.forest)
        .environmentObject(navigation)
        .environmentObject(reminders)
        .task { reminders.refresh(store) }
        .onChange(of: store.progress) { _, _ in reminders.refresh(store) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { reminders.refresh(store) } }
        .safeAreaInset(edge: .top, spacing: 0) { SaveStatusBanner() }
    }
}
