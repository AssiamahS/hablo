import Foundation
import Translation

enum Lang: String, CaseIterable, Codable {
    case en, es

    var language: Locale.Language { Locale.Language(identifier: rawValue) }
    var name: String { self == .en ? "English" : "Spanish" }
    var flag: String { self == .en ? "🇺🇸" : "🇪🇸" }
    var other: Lang { self == .en ? .es : .en }
}

enum Engine: String {
    case onDevice = "On-device"
    case online = "Online"
}

/// On-device Apple Translation first (languages downloaded once in the Hablo app),
/// falls back to a free web endpoint when the models are missing and Full Access is on.
@MainActor
final class Translator {
    static let shared = Translator()

    private var sessions: [Lang: TranslationSession] = [:]
    private var cache: [String: String] = [:]

    func isInstalled(_ source: Lang) async -> Bool {
        let status = await LanguageAvailability().status(from: source.language, to: source.other.language)
        return status == .installed
    }

    func translate(_ text: String, from source: Lang) async throws -> (String, Engine) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", .onDevice) }
        let key = "\(source.rawValue)|\(trimmed)"
        if let hit = cache[key] { return (hit, .onDevice) }

        do {
            let session = session(for: source)
            let out = try await session.translate(trimmed).targetText
            remember(key, out)
            return (out, .onDevice)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            sessions[source] = nil
            let out = try await Self.online(trimmed, from: source)
            remember(key, out)
            return (out, .online)
        }
    }

    private func session(for source: Lang) -> TranslationSession {
        if let s = sessions[source] { return s }
        let s = TranslationSession(installedSource: source.language, target: source.other.language)
        sessions[source] = s
        return s
    }

    private func remember(_ key: String, _ value: String) {
        if cache.count > 200 { cache.removeAll() }
        cache[key] = value
    }

    private static func online(_ text: String, from source: Lang) async throws -> String {
        var comps = URLComponents(string: "https://api.mymemory.translated.net/get")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "langpair", value: "\(source.rawValue)|\(source.other.rawValue)"),
        ]
        var req = URLRequest(url: comps.url!)
        req.timeoutInterval = 6
        let (data, _) = try await URLSession.shared.data(for: req)
        struct Reply: Decodable {
            struct Body: Decodable { let translatedText: String }
            let responseData: Body
        }
        return try JSONDecoder().decode(Reply.self, from: data).responseData.translatedText
    }
}
