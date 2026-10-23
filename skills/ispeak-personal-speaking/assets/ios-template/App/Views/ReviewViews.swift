import SwiftUI

struct ReviewHomeView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var navigation: AppNavigation
    @State private var reviewing = false
    @State private var planning = false
    @State private var showGuide = false
    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                let summary = store.dailySummary(now: context.date)
                AdaptivePage {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack {
                            Text("今日背诵").font(.system(size: 22, weight: .semibold, design: .serif))
                            Spacer()
                            RoundButton(symbol: "slider.horizontal.3", label: "每日计划") { planning = true }
                                .accessibilityIdentifier("dailyPlan")
                        }
                        VStack(alignment: .leading, spacing: 9) {
                            Text("每天几句，\n慢慢记牢。")
                                .font(.system(size: 34, weight: .medium, design: .serif)).lineSpacing(3)
                            Text("新句和旧句一起练，难记的多见几次。")
                                .font(.system(size: 13)).foregroundStyle(Color.mutedInk)
                        }
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(alignment: .firstTextBaseline, spacing: 7) {
                                Text("\(summary.remaining)").font(.system(size: 66, weight: .regular, design: .serif))
                                    .contentTransition(.numericText())
                                Text("句 · 今天的安排").font(.system(size: 13)).foregroundStyle(Color.mutedInk)
                                Spacer()
                                Image(systemName: "text.bubble").font(.system(size: 29, weight: .ultraLight)).foregroundStyle(Color.forest)
                            }
                            HStack(spacing: 0) {
                                count("\(summary.newReady)", "新句初背")
                                count("\(summary.reviewReady)", "到期复习")
                                count("\(summary.reinforcement)", "需要加强")
                            }
                            if summary.remaining > 0 {
                                PrimaryButton(title: summary.newReady + summary.reviewReady > 0 ? "开始今日背诵" : "继续巩固", symbol: "arrow.right") {
                                    reviewing = true; Motion.feedback()
                                }.accessibilityIdentifier("startReview")
                            } else if store.nextLearning != nil && summary.learned < summary.newTarget {
                                Text(store.completedGrammarIDs.isEmpty ? "背诵库还在等第一节" : "再学一节，给今天添几句新表达。")
                                    .font(.system(size: 12)).foregroundStyle(Color.mutedInk)
                                PrimaryButton(title: "去学几句", symbol: "arrow.up.right") { navigation.tab = 0 }
                            } else {
                                Label("今天的计划，完成了", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Color.forest)
                                if summary.overdue > 0 {
                                    PrimaryButton(title: "再练一小组", symbol: "plus") { store.addExtraPractice(); reviewing = true }
                                        .accessibilityIdentifier("extraPractice")
                                }
                            }
                        }
                        .padding(22).background(Color.white, in: RoundedRectangle(cornerRadius: 27))
                        VStack(alignment: .leading, spacing: 13) {
                            HStack {
                                Text("今天的进度").font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Button("调整计划") { planning = true }.font(.system(size: 11)).foregroundStyle(Color.forest)
                            }
                            progressRow("新学", summary.learned, summary.newTarget)
                            progressRow("初背", summary.newDone, summary.newTarget)
                            progressRow("复习", summary.reviewDone, summary.reviewTarget)
                            if summary.overdue > 0 {
                                Text("另有 \(summary.overdue) 句待练，会保留到下次，也可以加练。")
                                    .font(.system(size: 11)).foregroundStyle(Color.clay).lineSpacing(3)
                            }
                        }
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "sparkle").foregroundStyle(Color.forest)
                            Text("背错先理解，隔开再回忆。记得越牢，下次见面的间隔越长。")
                                .font(.system(size: 12)).foregroundStyle(Color.mutedInk).lineSpacing(4)
                        }
                        HStack {
                            Button("背诵怎么安排？") { showGuide = true }.font(.system(size: 11)).foregroundStyle(Color.forest)
                            Spacer()
                            if let date = store.nextReviewDate {
                                Text("下次 \(date.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))")
                                    .font(.system(size: 11)).foregroundStyle(Color.mutedInk)
                            }
                        }
                    }.padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 18)
                }.background(Color.paper)
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $reviewing) { ReviewSessionView() }
            .sheet(isPresented: $planning) { DailyPlanView() }
            .sheet(isPresented: $showGuide) { GuideView() }
        }.foregroundStyle(Color.ink)
    }
    private func count(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.system(size: 24, weight: .medium, design: .serif))
            Text(label).font(.system(size: 11)).foregroundStyle(Color.mutedInk)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func progressRow(_ title: String, _ value: Int, _ goal: Int) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 11)).frame(width: 25, alignment: .leading)
            MiniProgress(value: goal == 0 ? 1 : Double(value) / Double(goal))
            Text("\(value) / \(goal)").font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.mutedInk)
                .frame(width: 64, alignment: .trailing)
        }
    }
}

struct DailyPlanView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var reminders: ReminderManager
    @Environment(\.dismiss) private var dismiss
    @State private var plan = DailyPlanSettings()
    @State private var reminderDate = Date()
    @State private var notice: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("每日新学 / 初背", selection: $plan.newPerDay) {
                        ForEach([0, 5, 10, 15, 20, 30, 50], id: \.self) { Text("\($0) 句").tag($0) }
                    }.accessibilityIdentifier("newDailyGoal")
                    Picker("每日到期复习", selection: $plan.reviewsPerDay) {
                        ForEach([10, 20, 30, 50, 80, 100], id: \.self) { Text("\($0) 句").tag($0) }
                    }.accessibilityIdentifier("reviewDailyGoal")
                    Picker("出场顺序", selection: $plan.order) {
                        Text("新旧混合").tag(ReviewOrder.mixed)
                        Text("先复习").tag(ReviewOrder.reviewsFirst)
                    }.accessibilityIdentifier("reviewOrder")
                } header: { Text("适合自己的节奏") } footer: {
                    Text("新学仍按原来的顺序进行，每学完一节才解锁初背。计划是每天的目标，不会阻止你继续学习；没完成的复习会保留。")
                }
                Section {
                    Toggle("每日提醒", isOn: $plan.reminderEnabled).accessibilityIdentifier("reminderToggle")
                    if plan.reminderEnabled {
                        DatePicker("提醒时间", selection: $reminderDate, displayedComponents: .hourAndMinute)
                    }
                    if let notice { Text(notice).font(.footnote).foregroundStyle(Color.clay) }
                } footer: { Text("开启后只在这台设备提醒你练习。通知不会展示你的私人例句。") }
                Section {
                    Label("背错：隔开其他句子，再测两次", systemImage: "arrow.uturn.backward")
                    Label("有点难：更快回来巩固", systemImage: "leaf")
                    Label("背对：逐步拉长复习间隔", systemImage: "checkmark")
                } header: { Text("根据你的回忆结果调整") }
                .font(.system(size: 13))
            }
            .scrollContentBackground(.hidden).background(Color.paper)
            .navigationTitle("每日计划").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        Task {
                            let time = Calendar.current.dateComponents([.hour, .minute], from: reminderDate)
                            plan.reminderHour = time.hour ?? 20; plan.reminderMinute = time.minute ?? 0
                            if plan.reminderEnabled && !store.settings.reminderEnabled {
                                let allowed = await reminders.requestPermission()
                                if !allowed {
                                    plan.reminderEnabled = false
                                    notice = "系统通知尚未允许，可稍后在 iPhone 设置中开启。"
                                    store.updatePlan(plan)
                                    return
                                }
                            }
                            store.updatePlan(plan); dismiss()
                        }
                    }.fontWeight(.semibold).accessibilityIdentifier("saveDailyPlan")
                }
            }
            .onAppear {
                plan = store.settings
                reminderDate = Calendar.current.date(bySettingHour: plan.reminderHour, minute: plan.reminderMinute, second: 0, of: Date()) ?? Date()
            }
        }.tint(Color.forest)
    }
}

struct ReviewSessionView: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var speaker = Speaker()
    @State private var queue: [String] = []
    @State private var revealed = false
    @State private var changing = false
    @State private var cardOpacity = 1.0
    @State private var initialCount = 0
    @State private var passed = 0
    @State private var cut = 0
    @State private var feedback: String?
    @State private var sessionDay = ""
    @State private var started = false
    @State private var details: ReviewItem?
    @Environment(\.dynamicTypeSize) private var dynamicType
    @ScaledMetric(relativeTo: .title) private var answerSize = 27.0
    @ScaledMetric(relativeTo: .title2) private var cueSize = 29.0
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let pending = queue.filter { id in
                guard let entry = store.progress.reviews[id] else { return false }
                return !entry.isMastered && !entry.isComplete && (entry.needsReinforcement || store.canReview(id, now: context.date))
            }
            let current = pending.first { store.canReview($0, now: context.date) }.flatMap { store.reviewItem(for: $0) }
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    RoundButton(symbol: "xmark", label: "退出背诵") { dismiss() }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("开口，再揭晓").font(.system(size: 16, weight: .semibold))
                            if let current {
                                let entry = store.progress.reviews[current.id]
                                Text(entry?.needsReinforcement == true ? "加强" : entry?.firstCorrectAt == nil ? "初背" : "复习")
                                    .font(.system(size: 10)).foregroundStyle(Color.forest)
                                    .accessibilityIdentifier("reviewKind")
                            }
                        }
                        Text("剩余 \(pending.count) 句").font(.system(size: 11)).foregroundStyle(Color.mutedInk)
                    }
                    Spacer()
                    Text("\(min(initialCount, passed + cut)) / \(initialCount)").font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.mutedInk)
                }.padding(.top, 7)
                MiniProgress(value: initialCount == 0 ? 0 : Double(passed + cut) / Double(initialCount))
                if let item = current {
                    reviewCard(item).id(item.id).opacity(cardOpacity)
                    VStack(spacing: 10) {
                        Text(feedback ?? (revealed ? "意思准确、语法正确，就算背对。" : "先完整说出英文，再看答案。"))
                            .font(.system(size: 11)).foregroundStyle(Color.mutedInk).lineLimit(2).multilineTextAlignment(.center)
                        if revealed {
                            HStack(spacing: 8) {
                                gradeButton("背错了", symbol: "arrow.uturn.backward", color: .clay, id: "reviewIncorrect") { grade(.incorrect, item: item) }
                                gradeButton("有点难", symbol: "leaf", color: .forest, id: "reviewHard") { grade(.hard, item: item) }
                                Button { grade(.correct, item: item) } label: {
                                    Label("正确", systemImage: "checkmark").font(.system(size: 14, weight: .semibold))
                                        .frame(maxWidth: .infinity).frame(height: 55)
                                        .background(Color.forest, in: RoundedRectangle(cornerRadius: 17)).foregroundStyle(Color.paper)
                                }.accessibilityIdentifier("reviewCorrect")
                            }.buttonStyle(PressStyle()).disabled(changing)
                            Button { grade(.mastered, item: item) } label: {
                                Text("斩 · 已熟练，永久移出").font(.system(size: 11)).foregroundStyle(Color.mutedInk).frame(height: 34)
                            }.buttonStyle(PressStyle()).disabled(changing).accessibilityIdentifier("reviewMastered")
                        } else {
                            PrimaryButton(title: "查看答案", symbol: "eye") {
                                Motion.feedback(); speaker.stop()
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { revealed = true; feedback = nil }
                            }.accessibilityIdentifier("revealAnswer")
                            Color.clear.frame(height: 34).accessibilityHidden(true)
                        }
                    }
                } else if !pending.isEmpty {
                    Spacer()
                    EmptyIllustration(symbol: "leaf")
                    Text("留一点间隔，再试一次。").font(.system(size: 25, weight: .medium, design: .serif)).multilineTextAlignment(.center)
                    Text("需要加强的句子已保留，不会算作完成。")
                        .font(.system(size: 13)).foregroundStyle(Color.mutedInk).multilineTextAlignment(.center)
                    if let next = pending.compactMap({ store.dueDate(for: $0) }).min() {
                        Text(next, style: .relative).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.forest)
                            .accessibilityIdentifier("retryWaiting")
                    }
                    Spacer()
                    PrimaryButton(title: "稍后继续", symbol: "pause") { dismiss() }
                } else {
                    Spacer()
                    EmptyIllustration(symbol: "checkmark.seal")
                    Text("这一轮，完成了。").font(.system(size: 29, weight: .medium, design: .serif))
                    Text("背对 \(passed) 句\(cut > 0 ? " · 斩掉 \(cut) 句" : "")")
                        .font(.system(size: 14)).foregroundStyle(Color.mutedInk)
                    Text("已按记忆情况，安排下一次复习。")
                        .font(.system(size: 12)).foregroundStyle(Color.mutedInk)
                    Spacer()
                    PrimaryButton(title: "收好今天的进步", symbol: "checkmark") { dismiss() }
                }
            }
            .padding(.horizontal, 22).padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.paper).foregroundStyle(Color.ink)
            .onChange(of: store.dayKey(context.date)) { _, day in
                if started && day != sessionDay { dismiss() }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { SaveStatusBanner() }
        .onAppear {
            guard !started else { return }
            queue = store.beginDailySession().map(\.id); initialCount = queue.count
            sessionDay = store.dayKey(Date()); started = true
        }
        .onDisappear { speaker.stop() }
        .sheet(item: $details) { item in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(item.grammar.title).font(.title2.weight(.semibold))
                        Text(item.grammar.pattern).font(.system(size: 16, design: .serif)).foregroundStyle(Color.forest)
                        Text(item.grammar.note).font(.body).lineSpacing(6)
                        Divider()
                        Text(item.sentence.en).font(.system(size: 25, design: .serif))
                        Text(item.sentence.zh).foregroundStyle(Color.mutedInk)
                    }.padding(25)
                }.background(Color.paper).navigationTitle("这句怎么说").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { details = nil } } }
            }.tint(Color.forest)
        }
    }
    private func gradeButton(_ title: String, symbol: String, color: Color, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity).frame(height: 55)
                .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 17)).foregroundStyle(color)
        }.accessibilityIdentifier(id)
    }
    private func reviewCard(_ item: ReviewItem) -> some View {
        GeometryReader { _ in
            if dynamicType.isAccessibilitySize {
                ScrollView { cardContent(item, scale: 1) }
            } else {
            ViewThatFits(in: .vertical) {
                cardContent(item, scale: 1).fixedSize(horizontal: false, vertical: true)
                cardContent(item, scale: 0.84).fixedSize(horizontal: false, vertical: true)
                ScrollView { cardContent(item, scale: 0.84) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 27))
        .overlay(RoundedRectangle(cornerRadius: 27).stroke(Color.warmLine.opacity(0.7), lineWidth: 0.7))
        .clipped()
    }
    private func cardContent(_ item: ReviewItem, scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 21 * scale) {
            HStack {
                Text(revealed ? "核对表达" : "只看中文，试着说出来")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Color.mutedInk)
                Spacer()
                Image(systemName: revealed ? "eye" : "eye.slash").font(.system(size: 13)).foregroundStyle(Color.mutedInk)
            }
            Text(item.sentence.zh).font(.system(size: (revealed ? cueSize * 0.76 : cueSize) * scale, weight: .medium, design: .serif))
                .lineSpacing(6 * scale).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("reviewChinese")
            if revealed {
                Rectangle().fill(Color.warmLine).frame(height: 0.7)
                Text(item.sentence.en).font(.system(size: answerSize * scale, weight: .regular, design: .serif))
                    .lineSpacing(4 * scale).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("reviewEnglish")
                HStack {
                    Button { details = item } label: {
                        Label("看语法", systemImage: "text.book.closed").font(.system(size: 11))
                            .padding(.vertical, 12).padding(.trailing, 15)
                    }.accessibilityIdentifier("reviewGrammar")
                    Spacer()
                    Button { speaker.speak(item.sentence.en) } label: {
                        Image(systemName: "speaker.wave.2").font(.system(size: 16)).frame(width: 44, height: 40)
                            .background(Color.paper, in: Capsule())
                    }.accessibilityLabel("朗读答案")
                }.foregroundStyle(Color.forest).buttonStyle(PressStyle())
            } else {
                Text("不必赶时间，先把意思完整说出来。")
                    .font(.system(size: 12)).foregroundStyle(Color.mutedInk).lineSpacing(4)
            }
        }.padding(25 * scale).frame(maxWidth: .infinity, alignment: .leading)
    }
    private func grade(_ outcome: ReviewOutcome, item: ReviewItem) {
        guard revealed, !changing else { return }
        guard store.recordReview(sentenceID: item.id, outcome: outcome) else { return }
        changing = true; speaker.stop(); Motion.feedback(outcome == .incorrect ? .soft : .light)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.13)) { cardOpacity = 0 }
        Task { @MainActor in
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(140)) }
            queue.removeAll { $0 == item.id }
            if store.progress.reviews[item.id]?.needsReinforcement == true {
                queue.insert(item.id, at: min(2, queue.count))
                feedback = outcome == .incorrect ? "这句会隔开再测两次，先试下一句。" : "这句还不够熟，稍后再试。"
            } else if outcome == .mastered {
                cut += 1; feedback = "已斩，不再自动复习。"
            } else {
                passed += 1; feedback = outcome == .hard ? "已缩短下次复习的间隔。" : "已安排下一次复习。"
            }
            revealed = false
            withAnimation(reduceMotion ? nil : Motion.spring) { cardOpacity = 1; changing = false }
        }
    }
}
