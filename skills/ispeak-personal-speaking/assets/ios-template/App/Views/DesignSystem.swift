import SwiftUI
import AVFoundation

extension Color {
    static let paper = Color(red: 0.967, green: 0.957, blue: 0.932)
    static let ink = Color(red: 0.13, green: 0.24, blue: 0.22)
    static let mutedInk = Color(red: 0.44, green: 0.49, blue: 0.45)
    static let forest = Color(red: 0.19, green: 0.36, blue: 0.30)
    static let lime = Color(red: 0.86, green: 0.91, blue: 0.65)
    static let warmLine = Color(red: 0.86, green: 0.87, blue: 0.82)
    static let clay = Color(red: 0.64, green: 0.36, blue: 0.26)
}

enum Motion {
    static let spring = Animation.spring(response: 0.48, dampingFraction: 0.81)
    static func feedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol: String = "arrow.right"
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: symbol).font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Color.paper)
            .padding(.horizontal, 22).frame(minHeight: 58)
            .background(Color.forest, in: RoundedRectangle(cornerRadius: 21))
        }.buttonStyle(PressStyle())
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(2.0).foregroundStyle(Color.mutedInk)
    }
}

struct RoundButton: View {
    let symbol: String
    let label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.ink).frame(width: 44, height: 44)
                .background(.white.opacity(0.7), in: Circle())
                .overlay(Circle().stroke(Color.warmLine.opacity(0.7), lineWidth: 0.7))
        }.buttonStyle(PressStyle()).accessibilityLabel(label)
    }
}

struct MiniProgress: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.warmLine.opacity(0.7))
                Capsule().fill(Color.forest).frame(width: max(0, geo.size.width * min(1, value)))
            }
        }.frame(height: 4)
    }
}

struct SectionHeading: View {
    let title: String
    let trailing: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 20, weight: .semibold))
            Spacer()
            Text(trailing).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.mutedInk)
        }.foregroundStyle(Color.ink)
    }
}

@MainActor final class Speaker: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.43
        synthesizer.speak(utterance)
    }
    func stop() { synthesizer.stopSpeaking(at: .immediate) }
}

struct EmptyIllustration: View {
    var symbol: String = "leaf"
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 23).fill(Color.warmLine.opacity(0.5))
                .frame(width: 88, height: 112).rotationEffect(.degrees(-13)).offset(x: -13, y: 3)
            RoundedRectangle(cornerRadius: 23).fill(Color.white)
                .frame(width: 88, height: 112).rotationEffect(.degrees(8)).offset(x: 8)
                .shadow(color: Color.ink.opacity(0.06), radius: 15, y: 10)
            Image(systemName: symbol).font(.system(size: 32, weight: .light)).foregroundStyle(Color.forest)
        }.frame(height: 145).accessibilityHidden(true)
    }
}

struct SaveStatusBanner: View {
    @EnvironmentObject private var store: LearningStore
    var body: some View {
        if let error = store.saveError {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                Text(error).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if store.loadError == nil {
                    Button("重试") { store.retrySave() }.font(.system(size: 12, weight: .semibold))
                }
            }.foregroundStyle(Color.ink).padding(12).background(Color.lime)
        }
    }
}
