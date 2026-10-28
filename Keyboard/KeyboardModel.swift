import SwiftUI
import UIKit

enum Shift { case off, on, caps }
enum Layer { case letters, numbers, symbols }

@MainActor
final class KeyboardModel: ObservableObject {
    // Host bridge, wired by KeyboardViewController.
    var insert: (String) -> Void = { _ in }
    var deleteBackward: () -> Void = {}
    var contextBefore: () -> String? = { nil }
    var nextKeyboard: () -> Void = {}
    var dismiss: () -> Void = {}

    @Published var translateOn: Bool {
        didSet { UserDefaults.standard.set(translateOn, forKey: "translateOn") }
    }
    @Published var source: Lang {
        didSet { UserDefaults.standard.set(source.rawValue, forKey: "source") }
    }
    @Published var buffer = ""
    @Published var output = ""
    @Published var engine: Engine?
    @Published var busy = false
    @Published var problem: String?
    @Published var shift: Shift = .on
    @Published var layer: Layer = .letters
    @Published var needsGlobe = true
    @Published var hasFullAccess = false
    @Published var modelsReady = true

    private var job: Task<Void, Never>?
    private let tap = UIImpactFeedbackGenerator(style: .light)

    init() {
        let d = UserDefaults.standard
        translateOn = d.object(forKey: "translateOn") as? Bool ?? true
        source = Lang(rawValue: d.string(forKey: "source") ?? "") ?? .en
    }

    var target: Lang { source.other }

    func refreshAvailability() {
        Task { modelsReady = await Translator.shared.isInstalled(source) }
    }

    // MARK: keys

    func type(_ raw: String) {
        haptic()
        let s = shift == .off ? raw : raw.uppercased()
        if translateOn {
            buffer += s
            schedule()
        } else {
            insert(s)
        }
        if shift == .on { shift = .off }
    }

    func space() {
        type(" ")
        if layer != .letters { layer = .letters }
        autoShift()
    }

    func delete() {
        haptic()
        if translateOn {
            guard !buffer.isEmpty else { deleteBackward(); return }
            buffer.removeLast()
            schedule()
        } else {
            deleteBackward()
        }
        autoShift()
    }

    func returnKey() {
        haptic()
        if translateOn && !buffer.isEmpty {
            send()
        } else {
            insert("\n")
            shift = .on
        }
    }

    func toggleShift() {
        haptic()
        switch shift {
        case .off: shift = .on
        case .on: shift = .off
        case .caps: shift = .off
        }
    }

    func capsLock() { shift = .caps }

    func swap() {
        haptic()
        source = target
        if !output.isEmpty {
            buffer = output
        }
        refreshAvailability()
        schedule()
    }

    func clear() {
        haptic()
        job?.cancel()
        buffer = ""
        output = ""
        engine = nil
        problem = nil
        busy = false
        shift = .on
    }

    // MARK: translation

    private func schedule() {
        job?.cancel()
        problem = nil
        let text = buffer
        let from = source
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            output = ""
            engine = nil
            busy = false
            return
        }
        busy = true
        job = Task {
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            await run(text, from: from)
        }
    }

    private func run(_ text: String, from: Lang) async {
        do {
            let (out, eng) = try await Translator.shared.translate(text, from: from)
            guard !Task.isCancelled, text == buffer else { return }
            output = out
            engine = eng
            problem = nil
        } catch is CancellationError {
            return
        } catch {
            guard text == buffer else { return }
            problem = hasFullAccess
                ? "Couldn't translate. Open Hablo to download \(from.name) ⇄ \(from.other.name)."
                : "Open Hablo to download languages, or allow Full Access."
        }
        busy = false
    }

    /// Insert the translation into the host text field.
    func send() {
        let text = buffer
        let from = source
        Task {
            if output.isEmpty || busy {
                job?.cancel()
                await run(text, from: from)
            }
            guard !output.isEmpty else { return }
            insert(output)
            buffer = ""
            output = ""
            engine = nil
            shift = .on
        }
    }

    /// Translate whatever is already typed in the host field, in place.
    func translateField() {
        haptic()
        guard let before = contextBefore(), !before.trimmingCharacters(in: .whitespaces).isEmpty else {
            problem = "Nothing in the text field to translate."
            return
        }
        busy = true
        let from = source
        Task {
            do {
                let (out, eng) = try await Translator.shared.translate(before, from: from)
                for _ in before { deleteBackward() }
                insert(out)
                engine = eng
                problem = nil
            } catch {
                problem = "Couldn't translate the field."
            }
            busy = false
        }
    }

    private func autoShift() {
        guard shift != .caps else { return }
        let tail = translateOn ? buffer : (contextBefore() ?? "")
        let trimmed = tail.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || [".", "!", "?", "¿", "¡"].contains(trimmed.last.map(String.init) ?? "") && tail.hasSuffix(" ") {
            shift = .on
        }
    }

    private func haptic() {
        if hasFullAccess { tap.impactOccurred(intensity: 0.6) }
    }
}
