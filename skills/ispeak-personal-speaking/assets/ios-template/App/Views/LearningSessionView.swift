import SwiftUI

struct LearningSessionView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var navigation: AppNavigation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var speaker = Speaker()
    @State private var item: LearningItem?
    @State private var completedGrammar: GrammarPoint?
    @State private var drag: CGFloat = 0
    @State private var advancing = false
    @State private var sourcePage: Int?

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 14) {
                RoundButton(symbol: "xmark", label: "退出学习") { dismiss() }
                VStack(alignment: .leading, spacing: 4) {
                    Text(item?.chapter.shortTitle ?? "学习完成").font(.system(size: 15, weight: .semibold))
                    Text("PART \(item?.chapter.part ?? 1)  /  一次学会一个结构")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.mutedInk)
                }
                Spacer(minLength: 0)
                if let item, store.curriculum.hasGuidePDF {
                    Button { sourcePage = item.grammar.page } label: {
                        Image(systemName: "book").frame(width: 40, height: 44)
                    }.buttonStyle(PressStyle()).accessibilityLabel("查看 PDF 原页")
                }
            }.padding(.top, 9)
            if let completedGrammar {
                completion(completedGrammar).transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
            } else if let item {
                HStack(spacing: 6) {
                    ForEach(0..<item.grammar.examples.count, id: \.self) { i in
                        Capsule().fill(i < item.index ? Color.forest : i == item.index ? Color.forest.opacity(0.45) : Color.warmLine)
                    }
                }.frame(height: 4).accessibilityLabel("本节第 \(item.index + 1) 句，共 \(item.grammar.examples.count) 句")
                ZStack {
                    RoundedRectangle(cornerRadius: 31).fill(Color.warmLine.opacity(0.5))
                        .padding(.horizontal, 13).offset(y: 11)
                    SentenceCard(grammar: item.grammar, sentence: item.sentence, speaker: speaker)
                        .id(item.sentence.id)
                        .offset(x: drag)
                        .rotationEffect(.degrees(reduceMotion ? 0 : Double(drag / 28)))
                        .simultaneousGesture(DragGesture(minimumDistance: 22).onChanged { value in
                            guard !advancing else { return }
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            drag = value.translation.width > 0 ? value.translation.width * 0.15 : value.translation.width
                        }.onEnded { value in
                            guard !advancing else { return }
                            guard abs(value.translation.width) > abs(value.translation.height) else {
                                withAnimation(reduceMotion ? nil : Motion.spring) { drag = 0 }
                                return
                            }
                            if value.translation.width < -75 || value.predictedEndTranslation.width < -170 { advance() }
                            else { withAnimation(reduceMotion ? nil : Motion.spring) { drag = 0 } }
                        })
                        .accessibilityAction(named: Text("学习下一句")) { advance() }
                }.padding(.bottom, 10)
                VStack(spacing: 13) {
                    HStack {
                        Text("\(item.grammar.id)  /  \(String(format: "%02d", item.index + 1)) OF \(item.grammar.examples.count)")
                            .font(.system(size: 10, design: .monospaced)).tracking(1.2)
                        Spacer()
                        Label("向左轻扫", systemImage: "arrow.left").font(.system(size: 11))
                    }.foregroundStyle(Color.mutedInk)
                    PrimaryButton(title: item.index == item.grammar.examples.count - 1 ? "学完这节" : "下一句") { advance() }
                        .disabled(advancing).accessibilityIdentifier("nextSentence")
                }
            } else {
                Spacer()
                EmptyIllustration(symbol: "checkmark.seal")
                Text("全部学完了。") .font(.system(size: 30, weight: .medium, design: .serif))
                Text("让学过的句子，在复习中变得熟悉。") .font(.system(size: 14)).foregroundStyle(Color.mutedInk)
                Spacer()
                PrimaryButton(title: "完成学习", symbol: "checkmark") { dismiss() }
            }
        }
        .padding(.horizontal, 23).padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paper).foregroundStyle(Color.ink)
        .safeAreaInset(edge: .top, spacing: 0) { SaveStatusBanner() }
        .onAppear { item = store.nextLearning }
        .onDisappear { speaker.stop() }
        .sheet(isPresented: Binding(get: { sourcePage != nil }, set: { if !$0 { sourcePage = nil } })) {
            PDFReaderView(page: sourcePage ?? 1)
        }
    }

    private func completion(_ grammar: GrammarPoint) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().stroke(Color.forest.opacity(0.1), lineWidth: 1).frame(width: 165, height: 165)
                Circle().fill(Color.lime).frame(width: 116, height: 116)
                Image(systemName: "checkmark").font(.system(size: 41, weight: .light)).foregroundStyle(Color.forest)
                Image(systemName: "sparkle").font(.system(size: 22)).foregroundStyle(Color.forest).offset(x: 77, y: -56)
            }
            Eyebrow(text: "ONE STRUCTURE CLOSER")
            Text("这一节，学会了。") .font(.system(size: 30, weight: .medium, design: .serif))
            Text(grammar.title).font(.system(size: 15, weight: .medium)).multilineTextAlignment(.center)
            Text("\(grammar.examples.count) 个例句已加入背诵库\n先用中文提示，试着把它们说出来。")
                .font(.system(size: 14)).lineSpacing(7).multilineTextAlignment(.center).foregroundStyle(Color.mutedInk)
            Spacer()
            VStack(spacing: 13) {
                PrimaryButton(title: store.nextLearning == nil ? "完成全部学习" : "继续下一节") {
                    Motion.feedback()
                    withAnimation(reduceMotion ? nil : Motion.spring) { completedGrammar = nil; item = store.nextLearning }
                    if store.nextLearning == nil { dismiss() }
                }.accessibilityIdentifier("continueSection")
                Button("先去背诵") { navigation.tab = 1; dismiss() }
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(Color.forest).frame(height: 40)
                    .buttonStyle(PressStyle()).accessibilityIdentifier("finishSection")
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func advance() {
        guard let current = item, !advancing else { return }
        advancing = true; speaker.stop(); Motion.feedback()
        // Persist the accepted action before starting its visual transition.
        store.learn(current.sentence.id)
        let finished = store.isGrammarUnlocked(current.grammar.id)
        withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.9)) { drag = -470 }
        Task { @MainActor in
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(210)) }
            if finished {
                drag = 0
                withAnimation(reduceMotion ? nil : Motion.spring) { completedGrammar = current.grammar; advancing = false }
            } else {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { item = store.nextLearning; drag = reduceMotion ? 0 : 65 }
                if !reduceMotion { try? await Task.sleep(for: .milliseconds(20)) }
                withAnimation(reduceMotion ? nil : Motion.spring) { drag = 0; advancing = false }
            }
        }
    }
}

struct SentenceCard: View {
    let grammar: GrammarPoint
    let sentence: Sentence
    @ObservedObject var speaker: Speaker
    @ScaledMetric(relativeTo: .title) private var englishSize = 28.0
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Eyebrow(text: "THE GRAMMAR")
                        Spacer()
                        Text(grammar.level).font(.system(size: 10, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 9).padding(.vertical, 5).background(Color.lime.opacity(0.6), in: Capsule())
                    }
                    Text(grammar.title).font(.system(size: 21, weight: .semibold)).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    Text(grammar.pattern).font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.forest).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                    Text(grammar.note).font(.system(size: 12)).foregroundStyle(Color.mutedInk).lineSpacing(5)
                }
                Rectangle().fill(Color.warmLine).frame(height: 0.7)
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text(sentence.kind == "问" ? "问一句" : sentence.kind == "否" ? "否定表达" : "肯定表达")
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(Color.mutedInk)
                        if sentence.isPracticeScenario {
                            Text("情境练习").font(.system(size: 10)).foregroundStyle(Color.clay)
                        }
                        Spacer()
                        Button { speaker.speak(sentence.en) } label: {
                            Image(systemName: "speaker.wave.2").font(.system(size: 16)).foregroundStyle(Color.forest)
                                .frame(width: 44, height: 36).background(Color.paper, in: Capsule())
                        }.buttonStyle(PressStyle()).accessibilityLabel("朗读英文例句")
                    }
                    Text(sentence.en).font(.system(size: englishSize, weight: .regular, design: .serif))
                        .lineSpacing(5).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                        .accessibilityIdentifier("englishSentence")
                    Text(sentence.zh).font(.system(size: 16)).lineSpacing(6).foregroundStyle(Color.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.padding(25).padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 30))
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.warmLine.opacity(0.7), lineWidth: 0.7))
        .shadow(color: Color.ink.opacity(0.035), radius: 18, y: 10)
        .foregroundStyle(Color.ink)
    }
}
