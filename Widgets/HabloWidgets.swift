import AppIntents
import SwiftUI
import WidgetKit

extension CalLang: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Language"
    static var caseDisplayRepresentations: [CalLang: DisplayRepresentation] = [
        .english: "English",
        .spanish: "Español",
        .french: "Français",
        .italian: "Italiano",
    ]
}

struct CalendarLanguageIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Calendar Language"
    static var description = IntentDescription("Show the month and weekdays in the language you're learning.")

    @Parameter(title: "Language", default: .spanish)
    var language: CalLang
}

struct CalendarEntry: TimelineEntry {
    let date: Date
    let lang: CalLang
}

struct CalendarProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: .now, lang: .spanish)
    }

    func snapshot(for configuration: CalendarLanguageIntent, in context: Context) async -> CalendarEntry {
        CalendarEntry(date: .now, lang: configuration.language)
    }

    func timeline(for configuration: CalendarLanguageIntent, in context: Context) async -> Timeline<CalendarEntry> {
        let cal = Calendar.current
        let midnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now))!
        return Timeline(
            entries: [
                CalendarEntry(date: .now, lang: configuration.language),
                CalendarEntry(date: midnight, lang: configuration.language),
            ],
            policy: .after(midnight))
    }
}

struct HabloCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "HabloCalendar", intent: CalendarLanguageIntent.self, provider: CalendarProvider()) { entry in
            MonthGrid(date: entry.date, lang: entry.lang)
                .padding(.horizontal, 9)
                .padding(.top, 13)
                .padding(.bottom, 10)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("Calendario")
        .description("This month in Spanish, French, Italian or English. Long-press → Edit Widget to switch.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

@main
struct HabloWidgets: WidgetBundle {
    var body: some Widget {
        HabloCalendarWidget()
    }
}
