import SwiftUI

struct ReviewHomeView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var navigation: AppNavigation
    @State private var reviewing = false
    @State private var showGuide = false
    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let due = store.dueSentences(now: context.date)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 27) {
                        HStack {
                            Eyebrow(text: "RECALL / MAKE IT STAY")
                            Spacer()
                            RoundButton(symbol: "questionmark", label: "背诵规则") { showGuide = true }
                        }
                        Text("学过的，\n慢慢变熟悉。") .font(.system(size: 36, weight: .medium, design: .serif)).lineSpacing(6)
                        VStack(spacing: 22) {
                            if due.isEmpty {
                                EmptyIllustration(symbol: store.completedGrammarIDs.isEmpty ? "leaf" : "checkmark")
                                VStack(spacing: 10) {
                                    Text(store.completedGrammarIDs.isEmpty ? "背诵库还在等第一节" : "此刻，没有待背句子")
                                        .font(.system(size: 20, weight: .medium))
                                    Text(emptyMessage).font(.system(size: 13)).lineSpacing(6)
                                        .multilineTextAlignment(.center).foregroundStyle(Color.mutedInk)
                                }
                                PrimaryButton(title: "去学几句", symbol: "arrow.up.right") { navigation.tab = 0 }
                            } else {
                                HStack(alignment: .firstTextBaseline, spacing: 7) {
                                    Text("\(due.count)").font(.system(size: 76, weight: .regular, design: .serif))
                                    Text("句，等你开口").font(.system(size: 15)).foregroundStyle(Color.mutedInk)
                                    Spacer()
                                    Image(systemName: "text.bubble").font(.system(size: 31, weight: .ultraLight)).foregroundStyle(Color.forest)
                                }
                                Text("看中文 → 说英文 → 自己核对")
                                    .font(.system(size: 13)).foregroundStyle(Color.mutedInk).frame(maxWidth: .infinity, alignment: .leading)
                                PrimaryButton(title: "开始背诵", symbol: "arrow.right") { reviewing = true; Motion.feedback() }
                                    .accessibilityIdentifier("startReview")
                            }
                        }.padding(24).background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 29))
                        HStack(spacing: 14) {
                            reviewStat("\(store.scheduledCount)", "等待复习")
                            reviewStat("\(store.completedReviewCount)", "完成复习")
                            reviewStat("\(store.masteredCount)", "已斩")
                        }
                        VStack(alignment: .leading, spacing: 17) {
                            SectionHeading(title: "记忆有自己的节奏", trailing: "SPACED REPETITION")
                            HStack(spacing: 0) {
                                checkpoint("首次背对", "今天", active: true)
                                checkpoint("再见一次", "7 天")
                                checkpoint("加深记忆", "14 天")
                                checkpoint("最后巩固", "30 天")
                            }
                            Text("从第一次背对的日期起算。到期自动回库，背错继续保留，斩掉永久移除。")
                                .font(.system(size: 12)).foregroundStyle(Color.mutedInk).lineSpacing(5)
                        }.padding(.top, 6)
                        if let date = store.nextReviewDate {
                            HStack(spacing: 10) {
                                Image(systemName: "calendar").foregroundStyle(Color.forest)
                                Text("下次复习：\(date.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))")
                                    .font(.system(size: 13)).foregroundStyle(Color.mutedInk)
                                Spacer()
                            }.padding(18).background(Color.lime.opacity(0.25), in: RoundedRectangle(cornerRadius: 17))
                        }
                    }.padding(.horizontal, 25).padding(.top, 17).padding(.bottom, 30)
                }.background(Color.paper)
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $reviewing) { ReviewSessionView().environmentObject(store) }
            .sheet(isPresented: $showGuide) { GuideView() }
        }.foregroundStyle(Color.ink)
    }
    private var emptyMessage: String {
        if store.completedGrammarIDs.isEmpty { return "学完一个语法点的全部句子，\n它们就会出现在这里。" }
        if store.scheduledCount > 0 { return "已背对的句子会在第 7、14、30 天回来。\n也可以继续学习，积累新的表达。" }
        return "继续学新句，或者在句库重温。\n每次开口，都算数。"
    }
    private func reviewStat(_ count: String, _ title: String) -> some View {
        VStack(spacing: 8) {
            Text(count).font(.system(size: 25, weight: .medium, design: .serif))
            Text(title).font(.system(size: 11)).foregroundStyle(Color.mutedInk)
        }.frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
    }
    private func checkpoint(_ subtitle: String, _ title: String, active: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Circle().fill(active ? Color.forest : Color.warmLine).frame(width: 7, height: 7)
            Text(title).font(.system(size: 18, weight: .medium, design: .serif))
            Text(subtitle).font(.system(size: 10)).foregroundStyle(Color.mutedInk)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ReviewSessionView: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var speaker = Speaker()
    @State private var queue: [ReviewItem] = []
    @State private var revealed = false
    @State private var changing = false
    @State private var cardOpacity = 1.0
    @State private var initialCount = 0
    @State private var passed = 0
    @State private var cut = 0
    @State private var feedback: String?

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 13) {
                RoundButton(symbol: "xmark", label: "退出背诵") { dismiss() }
                VStack(alignment: .leading, spacing: 4) {
                    Text("开口，再揭晓") .font(.system(size: 16, weight: .semibold))
                    Text("剩余 \(queue.count) 句").font(.system(size: 11)).foregroundStyle(Color.mutedInk)
                }
                Spacer()
                Text("\(passed + cut) / \(initialCount)").font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.mutedInk)
            }.padding(.top, 9)
            MiniProgress(value: initialCount == 0 ? 0 : Double(passed + cut) / Double(initialCount))
            if let item = queue.first {
                reviewCard(item).id(item.sentence.id).opacity(cardOpacity)
                VStack(spacing: 12) {
                    if let feedback {
                        Text(feedback).font(.system(size: 11)).foregroundStyle(Color.forest)
                    } else {
                        Text(revealed ? "不用一字不差，重点检查语法和表达。" : "先完整说一遍，准备好后再看答案。")
                            .font(.system(size: 11)).foregroundStyle(Color.mutedInk)
                    }
                    if revealed {
                        HStack(spacing: 12) {
                            Button { grade(.incorrect) } label: {
                                Label("背错了", systemImage: "arrow.uturn.backward")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(maxWidth: .infinity).frame(height: 57)
                                    .background(Color.clay.opacity(0.09), in: RoundedRectangle(cornerRadius: 20))
                                    .foregroundStyle(Color.clay)
                            }.accessibilityIdentifier("reviewIncorrect")
                            Button { grade(.correct) } label: {
                                Label("正确", systemImage: "checkmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(maxWidth: .infinity).frame(height: 57)
                                    .background(Color.forest, in: RoundedRectangle(cornerRadius: 20)).foregroundStyle(Color.paper)
                            }.accessibilityIdentifier("reviewCorrect")
                        }.buttonStyle(PressStyle()).disabled(changing)
                        Button { grade(.mastered) } label: {
                            HStack(spacing: 6) {
                                Text("斩").font(.system(size: 15, weight: .semibold, design: .serif))
                                Text("· 已熟练，永久移出背诵库").font(.system(size: 11))
                            }.foregroundStyle(Color.mutedInk).frame(height: 38)
                        }.buttonStyle(PressStyle()).disabled(changing).accessibilityIdentifier("reviewMastered")
                    } else {
                        PrimaryButton(title: "查看答案", symbol: "eye") {
                            Motion.feedback()
                            withAnimation(reduceMotion ? nil : Motion.spring) { revealed = true; feedback = nil }
                        }.accessibilityIdentifier("revealAnswer")
                    }
                }
            } else {
                Spacer()
                EmptyIllustration(symbol: "checkmark.seal")
                Text("这一轮，完成了。") .font(.system(size: 30, weight: .medium, design: .serif))
                Text("背对 \(passed) 句\(cut > 0 ? " · 斩掉 \(cut) 句" : "")")
                    .font(.system(size: 15)).foregroundStyle(Color.mutedInk)
                Text("下次相见，会比这次更熟悉。") .font(.system(size: 13)).foregroundStyle(Color.mutedInk)
                Spacer()
                PrimaryButton(title: "收好今天的进步", symbol: "checkmark") { dismiss() }
            }
        }
        .padding(.horizontal, 23).padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.paper).foregroundStyle(Color.ink)
        .safeAreaInset(edge: .top, spacing: 0) { SaveStatusBanner() }
        .onAppear { queue = store.dueSentences(); initialCount = queue.count }
        .onDisappear { speaker.stop() }
    }

    private func reviewCard(_ item: ReviewItem) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Eyebrow(text: "\(revealed ? "CHECK YOUR ANSWER" : "SAY IT IN ENGLISH")")
                    Spacer()
                    Image(systemName: revealed ? "eye" : "eye.slash").font(.system(size: 14)).foregroundStyle(Color.mutedInk)
                }
                if item.sentence.isPracticeScenario {
                    Text("情境练习 · 请换成自己的真实情况").font(.system(size: 11)).foregroundStyle(Color.clay)
                }
                Text(item.sentence.zh).font(.system(size: revealed ? 23 : 28, weight: .medium, design: .serif))
                    .lineSpacing(9).fixedSize(horizontal: false, vertical: true)
                    .padding(.top, revealed ? 4 : 48).accessibilityIdentifier("reviewChinese")
                if revealed {
                    Rectangle().fill(Color.warmLine).frame(height: 1)
                    VStack(alignment: .leading, spacing: 16) {
                        Text(item.sentence.en).font(.system(size: 27, weight: .regular, design: .serif))
                            .lineSpacing(5).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("reviewEnglish")
                        HStack {
                            Text("原文表达").font(.system(size: 11)).foregroundStyle(Color.mutedInk)
                            Spacer()
                            Button { speaker.speak(item.sentence.en) } label: {
                                Image(systemName: "speaker.wave.2").font(.system(size: 16)).frame(width: 44, height: 36)
                                    .background(Color.paper, in: Capsule())
                            }.buttonStyle(PressStyle()).accessibilityLabel("朗读答案")
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(item.grammar.id) · \(item.grammar.title)").font(.system(size: 12, weight: .semibold))
                        Text(item.grammar.note).font(.system(size: 12)).lineSpacing(5).foregroundStyle(Color.mutedInk)
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.lime.opacity(0.22), in: RoundedRectangle(cornerRadius: 17))
                } else {
                    Text("在心里想好还不够，\n试着真的说出声音。")
                        .font(.system(size: 13)).lineSpacing(7).foregroundStyle(Color.mutedInk).padding(.top, 17)
                }
            }.padding(26).padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 29))
        .overlay(RoundedRectangle(cornerRadius: 29).stroke(Color.warmLine.opacity(0.7), lineWidth: 0.7))
    }

    private func grade(_ outcome: ReviewOutcome) {
        guard let item = queue.first, revealed, !changing else { return }
        changing = true; speaker.stop(); Motion.feedback(outcome == .incorrect ? .soft : .light)
        store.recordReview(sentenceID: item.sentence.id, outcome: outcome)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) { cardOpacity = 0 }
        Task { @MainActor in
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(160)) }
            queue.removeFirst()
            if outcome == .incorrect {
                queue.append(item); feedback = "这句留下了，轮到后再试一次。"
            } else if outcome == .correct {
                passed += 1; feedback = "背对了，已安排下一次复习。"
            } else { cut += 1; feedback = "已斩掉，不会再自动回到背诵库。" }
            revealed = false
            withAnimation(reduceMotion ? nil : Motion.spring) { cardOpacity = 1; changing = false }
        }
    }
}
