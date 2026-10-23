import SwiftUI

struct StudyHomeView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var studying = false
    @State private var showGuide = false
    var body: some View {
        NavigationStack {
            AdaptivePage {
                VStack(alignment: .leading, spacing: 17) {
                    HStack {
                        Label("句屿", systemImage: "square.stack.3d.up.fill")
                            .font(.system(size: 21, weight: .semibold, design: .serif))
                        Spacer()
                        RoundButton(symbol: "questionmark", label: "使用指南") { showGuide = true }
                            .accessibilityIdentifier("guide")
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        Text("把句子，\n说成自己的。")
                            .font(.system(size: 34, weight: .medium, design: .serif)).lineSpacing(2)
                        Text("一次一句。先看懂，再开口。")
                            .font(.system(size: 13)).foregroundStyle(Color.mutedInk)
                    }
                    studyCard
                    HStack(spacing: 0) {
                        stat("\(store.learnedCount)", "已学习")
                        Rectangle().fill(Color.warmLine).frame(width: 1, height: 25)
                        stat("\(store.dueSentences().count)", "待背诵")
                        Rectangle().fill(Color.warmLine).frame(width: 1, height: 25)
                        stat("\(store.curriculum.grammarCount)", "语法点")
                    }
                    VStack(spacing: 3) {
                        route("日常问答", "身份、家乡与习惯", "sun.horizon", 1)
                        route("讲述经历", "把故事说清楚", "text.bubble", 2)
                        route("表达观点", "让想法更有层次", "sparkle", 3)
                    }
                    Text("今天已新学 \(store.activity().learnedIDs.count) / \(store.settings.newPerDay) 句 · 目标之外也能继续学")
                        .font(.system(size: 10)).foregroundStyle(Color.mutedInk).frame(maxWidth: .infinity)
                }.padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 13)
            }
            .background(Color.paper).toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $studying) { LearningSessionView() }
            .sheet(isPresented: $showGuide) { GuideView() }
        }.foregroundStyle(Color.ink)
    }
    private var studyCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(store.learnedCount == 0 ? "从第一句开始" : "接着上次的进度").font(.system(size: 11)).foregroundStyle(Color.lime)
                Spacer()
                Text("\(store.learnedCount) / \(store.totalCount)").font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.paper.opacity(0.7))
            }
            if let next = store.nextLearning {
                VStack(alignment: .leading, spacing: 6) {
                    Text(next.chapter.shortTitle).font(.system(size: 24, weight: .medium, design: .serif))
                    Text(next.grammar.title).font(.system(size: 12)).foregroundStyle(Color.paper.opacity(0.75)).lineLimit(2)
                }
            } else {
                Text("全部学过了。").font(.system(size: 24, weight: .medium, design: .serif))
            }
            MiniProgress(value: Double(store.learnedCount) / Double(max(1, store.totalCount)), color: .lime)
            Button { studying = true; Motion.feedback() } label: {
                HStack {
                    Text(store.nextLearning == nil ? "学习已完成" : store.learnedCount == 0 ? "开始学习" : "继续学习")
                    Spacer()
                    Text("本节 \(store.nextLearning?.totalInGrammar ?? 5) 句").font(.system(size: 11)).opacity(0.7)
                    Image(systemName: "arrow.right")
                }.font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink).padding(16)
                    .background(Color.lime, in: RoundedRectangle(cornerRadius: 16))
            }.buttonStyle(PressStyle()).disabled(store.nextLearning == nil).accessibilityIdentifier("startLearning")
        }.padding(22).foregroundStyle(Color.paper).background(Color.forest, in: RoundedRectangle(cornerRadius: 27))
    }
    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 5) {
            Text(value).font(.system(size: 22, weight: .medium, design: .serif))
            Text(label).font(.system(size: 10)).foregroundStyle(Color.mutedInk)
        }.frame(maxWidth: .infinity)
    }
    private func route(_ title: String, _ detail: String, _ symbol: String, _ part: Int) -> some View {
        NavigationLink { ChapterListView(part: part) } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 16, weight: .light)).frame(width: 28)
                Text(title).font(.system(size: 13, weight: .medium))
                Spacer()
                Text(detail).font(.system(size: 10)).foregroundStyle(Color.mutedInk)
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Color.mutedInk)
            }.padding(.vertical, 10)
        }.buttonStyle(PressStyle())
    }
}

struct GuideView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Text("先学，再背。") .font(.system(size: 32, weight: .medium, design: .serif))
                    guide("1", "学习照旧，一次一句", "上半张看语法，下半张读例句。向左滑或点“下一句”；学完一个语法点的全部例句，才解锁这一节的初背。")
                    guide("2", "定一个能坚持的计划", "设定每日新学和复习目标。新解锁的句子与到期旧句混合练习，也可以选择先复习。学习入口不会被每日目标锁住。")
                    guide("3", "先开口，再核对", "只看中文说英文，再揭晓答案。意思准确、语法正确即可，不必逐字相同。背错的句子隔开其他句子或稍等一会儿，再做两次回忆。")
                    guide("4", "难句多练，熟句少见", "正常背对后，间隔从 1 天开始，逐步到 3、7、14、30 天及更长；有点难会缩短间隔，背错则回到短期巩固。错过的复习保留，不会自动算作完成。")
                    guide("斩", "确定熟练，就斩掉", "永久移出自动背诵，仍能在句库查阅。旧版已学、已斩和已完成记录均保留。")
                }.padding(25)
            }.background(Color.paper)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() }.tint(Color.forest) } }
        }
    }
    private func guide(_ index: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(index).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.forest)
                .frame(width: 29, height: 29).background(Color.lime.opacity(0.5), in: Circle())
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 17, weight: .semibold))
                Text(body).font(.system(size: 13)).foregroundStyle(Color.mutedInk).lineSpacing(6)
            }
        }.foregroundStyle(Color.ink)
    }
}
