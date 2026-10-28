import AppIntents
import Foundation

/// Opens Hablo straight to the translator box. Compiled into the app and the widget
/// extension so the Control Center button can launch it.
struct OpenTranslatorIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Translator"
    static var description = IntentDescription("Open Hablo ready to type.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "openTranslator")
        return .result()
    }
}
