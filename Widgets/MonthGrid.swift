import SwiftUI
import WidgetKit

enum CalLang: String, CaseIterable {
    case english, spanish, french, italian

    var locale: Locale {
        switch self {
        case .english: Locale(identifier: "en_US")
        case .spanish: Locale(identifier: "es_ES")
        case .french: Locale(identifier: "fr_FR")
        case .italian: Locale(identifier: "it_IT")
        }
    }
}

/// Apple-Calendar-style month: the current month plus the week before and the week after, faded.
struct MonthGrid: View {
    let date: Date
    let lang: CalLang

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = lang.locale
        c.firstWeekday = Calendar.current.firstWeekday
        return c
    }

    private var monthName: String {
        let f = DateFormatter()
        f.locale = lang.locale
        f.setLocalizedDateFormatFromTemplate("LLLL")
        return f.string(from: date).uppercased(with: lang.locale)
    }

    private var weekdays: [String] {
        let s = cal.veryShortStandaloneWeekdaySymbols
        let shift = cal.firstWeekday - 1
        return Array(s[shift...] + s[..<shift])
    }

    private var weeks: [[Date]] {
        guard let month = cal.dateInterval(of: .month, for: date),
              let firstWeek = cal.dateInterval(of: .weekOfYear, for: month.start),
              let lastWeek = cal.dateInterval(of: .weekOfYear, for: month.end.addingTimeInterval(-1)),
              let start = cal.date(byAdding: .day, value: -7, to: firstWeek.start),
              let end = cal.date(byAdding: .day, value: 7, to: lastWeek.end)
        else { return [] }
        var days: [Date] = []
        var d = start
        while d < end {
            days.append(d)
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(monthName)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.3)
                .foregroundStyle(.red)
                .padding(.leading, 3)
                .widgetAccentable()
            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, s in
                    Text(s)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 1)
            GeometryReader { geo in
                let rows = weeks
                let rowH = geo.size.height / CGFloat(max(rows.count, 1))
                let dot = min(rowH + 2, geo.size.width / 7, 19)
                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { w in
                        HStack(spacing: 0) {
                            ForEach(rows[w], id: \.self) { day in
                                cell(day, dot: dot)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: rowH)
                            }
                        }
                    }
                }
            }
        }
    }

    private func cell(_ day: Date, dot: CGFloat) -> some View {
        let inMonth = cal.isDate(day, equalTo: date, toGranularity: .month)
        let today = cal.isDate(day, inSameDayAs: date)
        let weekend = cal.isDateInWeekend(day)
        return Text("\(cal.component(.day, from: day))")
            .font(.system(size: 11, weight: today ? .bold : .semibold))
            .monospacedDigit()
            .foregroundStyle(today ? Color.white : inMonth ? (weekend ? Color.secondary : Color.primary) : Color.primary.opacity(0.22))
            .background {
                if today {
                    Circle().fill(.red).frame(width: dot, height: dot)
                }
            }
    }
}

