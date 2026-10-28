import AppIntents
import SwiftUI
import Translation
import WidgetKit

enum VocabLang: String, AppEnum {
    case spanish, french, italian

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Language"
    static var caseDisplayRepresentations: [VocabLang: DisplayRepresentation] = [
        .spanish: "Español",
        .french: "Français",
        .italian: "Italiano",
    ]

    var code: String {
        switch self {
        case .spanish: "es"
        case .french: "fr"
        case .italian: "it"
        }
    }

    var flag: String {
        switch self {
        case .spanish: "🇪🇸"
        case .french: "🇫🇷"
        case .italian: "🇮🇹"
        }
    }

    var label: String {
        switch self {
        case .spanish: "PALABRA"
        case .french: "MOT"
        case .italian: "PAROLA"
        }
    }
}

struct VocabIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Word of the Hour"
    static var description = IntentDescription("A new word every hour, translated by Apple's on-device translator.")

    @Parameter(title: "Language", default: .spanish)
    var language: VocabLang
}

// MARK: - Interactive buttons (run inside the widget extension)

enum VocabState {
    static let defaults = UserDefaults.standard
    static var offset: Int {
        get { defaults.integer(forKey: "vocabOffset") }
        set { defaults.set(newValue, forKey: "vocabOffset") }
    }
    static var hidden: Bool {
        get { defaults.bool(forKey: "vocabHidden") }
        set { defaults.set(newValue, forKey: "vocabHidden") }
    }
}

struct NextWordIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Word"
    func perform() async throws -> some IntentResult {
        VocabState.offset += 1
        return .result()
    }
}

struct FlipWordIntent: AppIntent {
    static var title: LocalizedStringResource = "Show or Hide English"
    func perform() async throws -> some IntentResult {
        VocabState.hidden.toggle()
        return .result()
    }
}

// MARK: - Timeline

struct VocabCard {
    let word: String
    let english: String
    let example: String
    let exampleEnglish: String
}

struct VocabEntry: TimelineEntry {
    let date: Date
    let lang: VocabLang
    let card: VocabCard
    let earlier: [VocabCard]
    let hidden: Bool
    let apple: Bool
}

struct VocabProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> VocabEntry {
        let w = Words.spanish[0]
        return VocabEntry(date: .now, lang: .spanish, card: card(w), earlier: [], hidden: false, apple: false)
    }

    func snapshot(for configuration: VocabIntent, in context: Context) async -> VocabEntry {
        await entries(for: configuration.language, hours: 1, family: context.family).first!
    }

    func timeline(for configuration: VocabIntent, in context: Context) async -> Timeline<VocabEntry> {
        Timeline(entries: await entries(for: configuration.language, hours: 8, family: context.family), policy: .atEnd)
    }

    static func index(at date: Date, count: Int) -> Int {
        let cal = Calendar.current
        let day = cal.ordinality(of: .day, in: .era, for: date) ?? 0
        let hour = cal.component(.hour, from: date)
        let raw = day * 24 + hour + VocabState.offset
        return ((raw % count) + count) % count
    }

    private func card(_ w: Word) -> VocabCard {
        VocabCard(word: w.word, english: w.english, example: w.example, exampleEnglish: w.exampleEnglish)
    }

    private func entries(for lang: VocabLang, hours: Int, family: WidgetFamily) async -> [VocabEntry] {
        let list = Words.list(lang)
        let cal = Calendar.current
        let thisHour = cal.dateInterval(of: .hour, for: .now)?.start ?? .now
        let showEarlier = family == .systemLarge ? 3 : 0

        // Every word this timeline will show, current hour first.
        var dates: [Date] = [.now]
        for h in 1..<max(hours, 1) {
            dates.append(cal.date(byAdding: .hour, value: h, to: thisHour)!)
        }
        let plan: [(Date, Int, [Int])] = dates.map { d in
            let i = Self.index(at: d, count: list.count)
            let back = showEarlier == 0 ? [] : (1...showEarlier).map { ((i - $0) % list.count + list.count) % list.count }
            return (d, i, back)
        }

        // Apple's on-device translator (same models as the Translate app); built-in English if it's unavailable.
        let needed = Set(plan.flatMap { [$0.1] + $0.2 })
        let translated = await appleTranslate(needed.map { list[$0] }, from: lang)
        let cardFor: (Int) -> VocabCard = { i in
            let w = list[i]
            if let t = translated[w.word] {
                return VocabCard(word: w.word, english: t.0, example: w.example, exampleEnglish: t.1)
            }
            return card(w)
        }
        let apple = !translated.isEmpty

        return plan.map { d, i, back in
            VocabEntry(date: d, lang: lang, card: cardFor(i), earlier: back.map(cardFor),
                       hidden: VocabState.hidden, apple: apple)
        }
    }

    private func appleTranslate(_ words: [Word], from lang: VocabLang) async -> [String: (String, String)] {
        let source = Locale.Language(identifier: lang.code)
        let target = Locale.Language(identifier: "en")
        guard await LanguageAvailability().status(from: source, to: target) == .installed else { return [:] }
        let session = TranslationSession(installedSource: source, target: target)
        var requests: [TranslationSession.Request] = []
        for (n, w) in words.enumerated() {
            requests.append(.init(sourceText: w.word, clientIdentifier: "w\(n)"))
            requests.append(.init(sourceText: w.example, clientIdentifier: "e\(n)"))
        }
        guard let responses = try? await session.translations(from: requests) else { return [:] }
        var byID: [String: String] = [:]
        for r in responses {
            if let id = r.clientIdentifier { byID[id] = r.targetText }
        }
        var out: [String: (String, String)] = [:]
        for (n, w) in words.enumerated() {
            if let a = byID["w\(n)"], let b = byID["e\(n)"] { out[w.word] = (a, b) }
        }
        return out
    }
}

// MARK: - Views

struct VocabView: View {
    let entry: VocabEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 6)
            main
            if family == .systemLarge && !entry.earlier.isEmpty {
                Spacer(minLength: 10)
                earlier
            }
            Spacer(minLength: 8)
            buttons
        }
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(entry.lang.flag).font(.system(size: 13))
            Text("\(entry.lang.label) · \(entry.date.formatted(.dateTime.hour()))")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .opacity(0.85)
            Spacer()
            if entry.apple {
                Image(systemName: "apple.logo").font(.system(size: 10)).opacity(0.6)
            }
        }
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.card.word)
                .font(.system(size: family == .systemLarge ? 34 : 26, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            english(entry.card.english)
                .font(.system(size: family == .systemLarge ? 20 : 16, weight: .semibold))
            Text(entry.card.example)
                .font(.system(size: 13, weight: .medium))
                .italic()
                .opacity(0.9)
                .lineLimit(family == .systemLarge ? 2 : 1)
                .padding(.top, 4)
            english(entry.card.exampleEnglish)
                .font(.system(size: 12))
                .opacity(0.75)
                .lineLimit(family == .systemLarge ? 2 : 1)
        }
    }

    @ViewBuilder
    private func english(_ s: String) -> some View {
        if entry.hidden {
            Text(s).redacted(reason: .placeholder).opacity(0.5)
        } else {
            Text(s).opacity(0.92)
        }
    }

    private var earlier: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EARLIER")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
                .opacity(0.6)
            ForEach(Array(entry.earlier.enumerated()), id: \.offset) { _, c in
                HStack {
                    Text(c.word).font(.system(size: 14, weight: .bold))
                    Spacer()
                    english(c.english).font(.system(size: 13))
                }
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.14)))
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            Button(intent: FlipWordIntent()) {
                Label(entry.hidden ? "Show" : "Quiz", systemImage: entry.hidden ? "eye" : "eye.slash")
            }
            Spacer()
            Button(intent: NextWordIntent()) {
                Label("Next", systemImage: "arrow.right")
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .buttonStyle(.plain)
        .labelStyle(PillLabel())
    }
}

private struct PillLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
            configuration.title
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(.white.opacity(0.22)))
    }
}

struct VocabWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "HabloVocab", intent: VocabIntent.self, provider: VocabProvider()) { entry in
            VocabView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 0.17, green: 0.42, blue: 0.95), Color(red: 0.36, green: 0.72, blue: 0.98)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
        }
        .configurationDisplayName("Word of the Hour")
        .description("A new word every hour with its English meaning. Tap Quiz to hide the English, Next to skip.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
