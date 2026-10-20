import SwiftUI

struct StudyHomeView: View {
    @EnvironmentObject private var store: LearningStore
    @State private var studying = false
    @State private var showGuide = false
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        HStack(spacing: 9) {
                            Image(systemName: "square.stack.3d.up.fill").font(.system(size: 20)).foregroundStyle(Color.forest)
                            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "iSpeak").font(.system(size: 23, weight: .semibold, design: .serif))
                        }
                        Spacer()
                        Button { showGuide = true } label: {
                            Text("使用指南").font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .overlay(Capsule().stroke(Color.warmLine, lineWidth: 1))
                        }.buttonStyle(PressStyle()).accessibilityIdentifier("guide")
                    }
                    VStack(alignment: .leading, spacing: 13) {
                        Eyebrow(text: "ISPEAK / PERSONAL FIELD GUIDE")
                        Text("把句子，\n说成自己的。").font(.system(size: 39, weight: .medium, design: .serif)).lineSpacing(6)
                        Text("一次一句。从看懂，到脱口而出。")
                            .font(.system(size: 14)).foregroundStyle(Color.mutedInk)
                    }.padding(.top, 4)
                    studyCard
                    HStack(spacing: 0) {
                        stat("\(store.learnedCount)", "已学习")
                        Rectangle().fill(Color.warmLine).frame(width: 1, height: 28)
                        stat("\(store.dueSentences().count)", "待背诵")
                        Rectangle().fill(Color.warmLine).frame(width: 1, height: 28)
                        stat("\(store.curriculum.grammarCount)", "语法点")
                    }.padding(.vertical, 3)
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeading(title: "你的学习路线", trailing: "\(store.curriculum.chapters.count) TOPICS · \(store.totalCount) SENTENCES")
                        if store.curriculum.chapterCount(part: 1) > 0 {
                        routeRow("01", "熟悉话题，打好基础", "PART 1 · \(store.curriculum.chapterCount(part: 1)) 个话题", "sun.horizon", 1)
                        }
                        if store.curriculum.chapterCount(part: 2) > 0 {
                        routeRow("02", "用自己的经历讲故事", "PART 2 · \(store.curriculum.chapterCount(part: 2)) 个话题", "text.bubble", 2)
                        }
                        if store.curriculum.chapterCount(part: 3) > 0 {
                        routeRow("03", "让观点表达更进一步", "PART 3 · \(store.curriculum.chapterCount(part: 3)) 个话题", "sparkle", 3)
                        }
                    }
                    HStack(spacing: 7) {
                        Image(systemName: "internaldrive").font(.system(size: 11))
                        Text("离线可用 · 进度自动保存在这台设备")
                            .font(.system(size: 11))
                    }.foregroundStyle(Color.mutedInk).frame(maxWidth: .infinity).padding(.top, 2)
                }.padding(.horizontal, 25).padding(.top, 16).padding(.bottom, 30)
            }
            .background(Color.paper).toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $studying) { LearningSessionView().environmentObject(store) }
            .sheet(isPresented: $showGuide) { GuideView() }
        }.foregroundStyle(Color.ink)
    }

    private var studyCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(store.learnedCount == 0 ? "从第一句开始" : "接着上次的进度")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.lime)
                Spacer()
                Text("\(store.learnedCount) / \(store.totalCount)").accessibilityIdentifier("learningProgressCount").font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.paper.opacity(0.65))
            }
            if let next = store.nextLearning {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(next.chapter.shortTitle).font(.system(size: 25, weight: .medium, design: .serif))
                        Text("\(next.grammar.id)  ·  \(next.grammar.title)")
                            .font(.system(size: 12)).lineLimit(2).foregroundStyle(Color.paper.opacity(0.7))
                    }
                    Spacer(minLength: 12)
                    Image(systemName: "arrow.up.right").font(.system(size: 21, weight: .light)).foregroundStyle(Color.lime)
                }
            } else {
                Text("\(store.totalCount) 句，都学过了。") .font(.system(size: 26, weight: .medium, design: .serif))
                Text("去背诵，让学过的句子真正留下来。") .font(.system(size: 12)).foregroundStyle(Color.paper.opacity(0.7))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.13))
                    Capsule().fill(Color.lime).frame(width: max(4, geo.size.width * Double(store.learnedCount) / Double(max(1, store.totalCount))))
                }
            }.frame(height: 3)
            Button {
                Motion.feedback(); studying = true
            } label: {
                HStack {
                    Text(store.nextLearning == nil ? "学习已完成" : "\(store.learnedCount == 0 ? "开始" : "继续")学习")
                    Spacer()
                    Text("本节 \(store.nextLearning?.grammar.examples.count ?? 5) 句").font(.system(size: 12, weight: .regular)).opacity(0.7)
                    Image(systemName: "arrow.right")
                }.font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink)
                    .padding(17).background(Color.lime, in: RoundedRectangle(cornerRadius: 17))
            }.buttonStyle(PressStyle()).disabled(store.nextLearning == nil).accessibilityIdentifier("startLearning")
        }
        .foregroundStyle(Color.paper).padding(23)
        .background(Color.forest, in: RoundedRectangle(cornerRadius: 29))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 25, weight: .medium, design: .serif))
            Text(label).font(.system(size: 11)).foregroundStyle(Color.mutedInk)
        }.frame(maxWidth: .infinity)
    }
    private func routeRow(_ number: String, _ title: String, _ subtitle: String, _ icon: String, _ part: Int) -> some View {
        NavigationLink {
            ChapterListView(part: part)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 20, weight: .light))
                    .frame(width: 47, height: 50).background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 14, weight: .medium))
                    Text(subtitle).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.mutedInk)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Color.mutedInk)
            }.padding(.vertical, 3)
        }.buttonStyle(PressStyle())
    }
}

struct GuideView: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Eyebrow(text: "A LITTLE, EVERY DAY")
                    Text("先学，再背。") .font(.system(size: 34, weight: .medium, design: .serif))
                    guide("01", "学一句", "上半张看语法，下半张读例句。向左滑，或点“下一句”。每个语法点是一节，学完这节的全部例句就解锁对应背诵。默认完整课程每节 5 句。")
                    guide("02", "自己检验", "背诵先只显示中文。开口说出英文，再查看答案。“正确”安排复习；“背错了”留在库中，轮到后再试。")
                    guide("03", "在记忆变淡前再见", "从首次背对当天起，在第 7、14、30 天回到背诵库。错过日期会保留待背状态；第 30 天背对后完成这轮复习。")
                    guide("斩", "已经熟练，就斩掉", "查看答案后可选择“斩”。它会永久移出当前背诵库，不再自动回来；学过的内容仍可在句库查阅。")
                    Text("你的个人口语句库：\(store.curriculum.chapters.count) 个话题、\(store.curriculum.grammarCount) 个语法点、\(store.totalCount) 个双语例句。标为“情境练习”的句子只是练习，不代表你的真实经历。")
                        .font(.system(size: 13)).foregroundStyle(Color.mutedInk).lineSpacing(5)
                }.padding(26)
            }.background(Color.paper)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() }.tint(Color.forest) } }
        }
    }
    private func guide(_ index: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 17) {
            Text(index).font(.system(size: 14, design: .monospaced)).foregroundStyle(Color.forest)
                .frame(width: 32, height: 32).background(Color.lime.opacity(0.5), in: Circle())
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 18, weight: .semibold))
                Text(body).font(.system(size: 14)).foregroundStyle(Color.mutedInk).lineSpacing(6)
            }
        }.foregroundStyle(Color.ink)
    }
}
