import SwiftUI
import PDFKit

struct LibraryView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: LearningStore
    @State private var search = ""
    @State private var part = 0
    @State private var showPDF = false
    private var matches: [LearningItem] {
        store.curriculum.chapters.flatMap { chapter in
            chapter.grammar.flatMap { grammar in
                grammar.examples.enumerated().compactMap { index, sentence in
                    let haystack = [sentence.en, sentence.zh, grammar.id, grammar.title, chapter.shortTitle].joined(separator: " ")
                    guard haystack.localizedCaseInsensitiveContains(search.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
                    return LearningItem(sentence: sentence, grammar: grammar, chapter: chapter, index: index, globalIndex: 0)
                }
            }
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack {
                            Eyebrow(text: "\(store.curriculum.chapters.count) TOPICS / \(store.curriculum.grammarCount) STRUCTURES / \(store.totalCount) SENTENCES")
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            ForEach(0..<4) { value in
                                Button { withAnimation(reduceMotion ? nil : Motion.spring) { part = value } } label: {
                                    Text(value == 0 ? "全部" : "Part \(value)")
                                        .font(.system(size: 12, weight: .medium)).padding(.horizontal, 16).padding(.vertical, 11)
                                        .background(part == value ? Color.forest : Color.white.opacity(0.7), in: Capsule())
                                        .foregroundStyle(part == value ? Color.paper : Color.mutedInk)
                                }.buttonStyle(PressStyle())
                            }
                        }
                        ForEach(store.curriculum.chapters.filter { part == 0 || $0.part == part }) { chapter in
                            NavigationLink { ChapterDetailView(chapter: chapter) } label: { ChapterRow(chapter: chapter) }
                                .buttonStyle(PressStyle())
                        }
                        SectionHeading(title: "随手查阅", trailing: "FROM YOUR FIELD GUIDE").padding(.top, 14)
                        if store.curriculum.hasGuidePDF {
                        Button { showPDF = true } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "doc.richtext").font(.system(size: 23, weight: .light))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("原版 PDF").font(.system(size: 16, weight: .medium))
                                    Text("随句库生成 · 离线阅读").font(.system(size: 11)).foregroundStyle(Color.mutedInk)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.system(size: 13))
                            }.padding(20).background(Color.lime.opacity(0.35), in: RoundedRectangle(cornerRadius: 21))
                        }.buttonStyle(PressStyle())
                        }
                        ForEach(store.curriculum.supplements) { supplement in
                            NavigationLink { SupplementView(supplement: supplement) } label: {
                                HStack(spacing: 13) {
                                    Text(String(format: "%03d", supplement.page)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Color.mutedInk)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(supplement.title).font(.system(size: 14, weight: .medium)).multilineTextAlignment(.leading)
                                        Text(supplement.subtitle).font(.system(size: 11)).foregroundStyle(Color.mutedInk).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Color.mutedInk)
                                }.padding(.vertical, 7)
                            }.buttonStyle(PressStyle())
                        }
                    } else {
                        let results = matches
                        Text("找到 \(results.count) 个例句").font(.system(size: 12)).foregroundStyle(Color.mutedInk)
                        if results.isEmpty {
                            ContentUnavailableView.search(text: search)
                        } else {
                            ForEach(results) { item in
                                NavigationLink { GrammarPreviewView(grammar: item.grammar, initialIndex: item.index) } label: {
                                    VStack(alignment: .leading, spacing: 9) {
                                        Eyebrow(text: "\(item.grammar.id) · \(item.chapter.shortTitle)")
                                        Text(item.sentence.en).accessibilityIdentifier("libraryResultEnglish").font(.system(size: 19, design: .serif)).lineSpacing(4)
                                        Text(item.sentence.zh).font(.system(size: 13)).foregroundStyle(Color.mutedInk).lineSpacing(3)
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                                        .background(Color.white, in: RoundedRectangle(cornerRadius: 23))
                                }.buttonStyle(PressStyle())
                            }
                        }
                    }
                }.padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 30)
            }
            .background(Color.paper).navigationTitle("句库")
            .searchable(text: $search, prompt: "搜索中文、英文或语法编号")
            .toolbarBackground(Color.paper, for: .navigationBar)
            .sheet(isPresented: $showPDF) { PDFReaderView(page: 1) }
        }.foregroundStyle(Color.ink).tint(Color.forest)
    }
}

struct ChapterListView: View {
    @EnvironmentObject private var store: LearningStore
    let part: Int
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                ForEach(store.curriculum.chapters.filter { $0.part == part }) { chapter in
                    NavigationLink { ChapterDetailView(chapter: chapter) } label: { ChapterRow(chapter: chapter) }
                        .buttonStyle(PressStyle())
                }
            }.padding(24)
        }.background(Color.paper).foregroundStyle(Color.ink).navigationTitle("Part \(part)").navigationBarTitleDisplayMode(.inline)
    }
}

struct ChapterRow: View {
    @EnvironmentObject private var store: LearningStore
    let chapter: Chapter
    var body: some View {
        HStack(spacing: 16) {
            Text(String(format: "%02d", chapter.id)).font(.system(size: 28, weight: .regular, design: .serif))
                .foregroundStyle(Color.forest).frame(width: 42)
            VStack(alignment: .leading, spacing: 7) {
                Text(chapter.shortTitle).font(.system(size: 17, weight: .medium))
                Text(chapter.title).font(.system(size: 11)).foregroundStyle(Color.mutedInk).lineLimit(1)
                if store.progress(for: chapter) > 0 { MiniProgress(value: store.progress(for: chapter)).padding(.top, 2) }
                else { Text("PART \(chapter.part) · \(chapter.grammar.count) 个语法点 · \(chapter.grammar.flatMap(\.examples).count) 句").font(.system(size: 9, design: .monospaced)).foregroundStyle(Color.mutedInk) }
            }
            Spacer(minLength: 0)
            Image(systemName: store.progress(for: chapter) == 1 ? "checkmark.circle.fill" : "chevron.right")
                .font(.system(size: 12)).foregroundStyle(Color.forest.opacity(0.7))
        }.padding(19).background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 23))
            .foregroundStyle(Color.ink)
    }
}

struct ChapterDetailView: View {
    @EnvironmentObject private var store: LearningStore
    let chapter: Chapter
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 25) {
                Eyebrow(text: "PART \(chapter.part) / CHAPTER \(String(format: "%02d", chapter.id))")
                Text(chapter.title).font(.system(size: 31, weight: .regular, design: .serif))
                Text(chapter.subtitle).font(.system(size: 14)).foregroundStyle(Color.mutedInk)
                MiniProgress(value: store.progress(for: chapter))
                SectionHeading(title: "本章语法", trailing: "\(chapter.grammar.count) STRUCTURES")
                ForEach(chapter.grammar) { grammar in
                    NavigationLink { GrammarPreviewView(grammar: grammar) } label: {
                        HStack(alignment: .top, spacing: 13) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Eyebrow(text: "\(grammar.id) / \(grammar.level)")
                                    Spacer()
                                    if store.isGrammarUnlocked(grammar.id) {
                                        Text("已学完").font(.system(size: 10)).foregroundStyle(Color.forest)
                                    }
                                }
                                Text(grammar.title).font(.system(size: 17, weight: .medium)).multilineTextAlignment(.leading)
                                Text(grammar.pattern).font(.system(size: 12, design: .monospaced)).foregroundStyle(Color.mutedInk).multilineTextAlignment(.leading)
                            }
                            Image(systemName: "chevron.right").font(.system(size: 11)).padding(.top, 29)
                        }.padding(20).background(Color.white, in: RoundedRectangle(cornerRadius: 23))
                    }.buttonStyle(PressStyle())
                }
                SectionHeading(title: "试着这样开口", trailing: "SPEAK IT · OWN IT")
                ForEach(Array(chapter.questions.enumerated()), id: \.offset) { i, question in
                    HStack(alignment: .top, spacing: 12) {
                        Text("0\(i + 1)").font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.forest).padding(.top, 4)
                        Text(question).font(.system(size: 19, design: .serif)).lineSpacing(4)
                    }
                }
                Text(chapter.practice).font(.system(size: 13)).lineSpacing(6).foregroundStyle(Color.mutedInk)
                    .padding(20).background(Color.lime.opacity(0.2), in: RoundedRectangle(cornerRadius: 22))
            }.padding(25).padding(.bottom, 20)
        }.background(Color.paper).foregroundStyle(Color.ink).navigationTitle(chapter.shortTitle).navigationBarTitleDisplayMode(.inline)
    }
}

struct GrammarPreviewView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: LearningStore
    let grammar: GrammarPoint
    var initialIndex: Int = 0
    @State private var index = 0
    @StateObject private var speaker = Speaker()
    @State private var showPDF = false
    var body: some View {
        VStack(spacing: 19) {
            HStack {
                Eyebrow(text: "句库预览 / \(index + 1) OF \(grammar.examples.count)")
                Spacer()
                Text(store.statusLabel(for: grammar.examples[index].id)).font(.system(size: 11)).foregroundStyle(Color.mutedInk)
            }
            SentenceCard(grammar: grammar, sentence: grammar.examples[index], speaker: speaker)
            HStack(spacing: 16) {
                RoundButton(symbol: "arrow.left", label: "上一句") { change(-1) }.disabled(index == 0).opacity(index == 0 ? 0.3 : 1)
                Text("预览不计入学习进度").font(.system(size: 11)).foregroundStyle(Color.mutedInk).frame(maxWidth: .infinity)
                RoundButton(symbol: "arrow.right", label: "下一句") { change(1) }.disabled(index == grammar.examples.count - 1).opacity(index == grammar.examples.count - 1 ? 0.3 : 1)
            }
        }.padding(23).background(Color.paper).navigationTitle(grammar.id).navigationBarTitleDisplayMode(.inline)
            .toolbar { if store.curriculum.hasGuidePDF { ToolbarItem(placement: .topBarTrailing) { Button { showPDF = true } label: { Image(systemName: "book") }.accessibilityLabel("查看原页") } } }
            .sheet(isPresented: $showPDF) { PDFReaderView(page: grammar.page) }
            .onAppear { index = min(max(0, initialIndex), grammar.examples.count - 1) }
            .onDisappear { speaker.stop() }
    }
    private func change(_ delta: Int) {
        speaker.stop(); Motion.feedback()
        withAnimation(reduceMotion ? nil : Motion.spring) { index = min(max(0, index + delta), grammar.examples.count - 1) }
    }
}

struct SupplementView: View {
    @EnvironmentObject private var store: LearningStore
    let supplement: Supplement
    @State private var showPDF = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: "FIELD GUIDE / PAGE \(supplement.page)")
                Text(supplement.title).font(.system(size: 30, weight: .medium, design: .serif))
                Text(supplement.subtitle).font(.system(size: 13)).foregroundStyle(Color.mutedInk)
                Rectangle().fill(Color.warmLine).frame(height: 1)
                Text(supplement.body).font(.system(size: 16)).lineSpacing(8).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.padding(25)
        }.background(Color.paper).foregroundStyle(Color.ink).navigationBarTitleDisplayMode(.inline)
            .toolbar { if store.curriculum.hasGuidePDF { ToolbarItem(placement: .topBarTrailing) { Button("原页") { showPDF = true } } } }
            .sheet(isPresented: $showPDF) { PDFReaderView(page: supplement.page) }
    }
}

struct PDFReaderView: View {
    @Environment(\.dismiss) private var dismiss
    var page = 1
    var body: some View {
        NavigationStack {
            Group {
                if let url = Bundle.main.url(forResource: "Guide", withExtension: "pdf") {
                    PDFDocumentView(url: url, page: page)
                } else {
                    ContentUnavailableView("没有找到原版教材", systemImage: "doc", description: Text("请重新安装完整应用。"))
                }
            }
            .navigationTitle("个人教材 · 第 \(page) 页").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() }.tint(Color.forest) } }
        }
    }
}

struct PDFDocumentView: UIViewRepresentable {
    let url: URL
    let page: Int
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(url: url)
        view.accessibilityIdentifier = "sourcePDF"
        view.accessibilityValue = "\(view.document?.pageCount ?? 0) pages"
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = UIColor(Color.paper)
        if let target = view.document?.page(at: max(0, page - 1)) {
            DispatchQueue.main.async { view.go(to: target) }
        }
        return view
    }
    func updateUIView(_ uiView: PDFView, context: Context) { }
}
