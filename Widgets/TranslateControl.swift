import AppIntents
import SwiftUI
import WidgetKit

struct TranslateControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "HabloTranslateControl") {
            ControlWidgetButton(action: OpenTranslatorIntent()) {
                Label("Translate", systemImage: "translate")
            }
        }
        .displayName("Hablo Translate")
        .description("Open Hablo ready to type.")
    }
}
