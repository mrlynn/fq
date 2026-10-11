import SwiftUI
import WidgetKit

/// One moment of a countdown widget. The apps build these too, for the Appearance preview.
struct CountdownEntry: TimelineEntry {
    let date: Date
    let snapshot: QuarterSnapshot
    let target: CountdownTarget
    let unit: CountdownUnit
    let label: String?
    var appearance: Appearance = .standard
    /// The picture for an image background, loaded once per timeline.
    var backgroundImage: CGImage?

    var countdown: Countdown { snapshot.countdown(to: target) }
    var theme: Theme { Theme(appearance: appearance) }
}

/// What a widget draws behind its content: the system fill, or the chosen background.
struct CountdownBackground: View {
    let entry: CountdownEntry

    var body: some View {
        if entry.appearance.background == .system {
            if #available(macOS 14, iOS 17, *) {
                Rectangle().fill(.fill.tertiary)
            } else {
                // Only the preview in the Mac app runs before macOS 14. Widgets need 14.
                Rectangle().fill(Color.primary.opacity(0.08))
            }
        } else {
            ThemeBackground(appearance: entry.appearance, image: entry.backgroundImage)
        }
    }
}

extension Theme {
    /// Amber in the last two weeks, the accent otherwise.
    func tint(for countdown: Countdown) -> Color {
        countdown.days <= 14 ? Theme.warning : accent
    }
}

struct CountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CountdownEntry

    var body: some View {
        content.themed(entry.appearance)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        #if os(iOS)
        case .accessoryCircular:
            CircularCountdown(entry: entry)
        case .accessoryRectangular:
            RectangularCountdown(entry: entry)
        case .accessoryInline:
            Text("\(entry.countdown.label) · \(entry.countdown.short(in: entry.unit))")
        #endif
        case .systemMedium:
            MediumCountdown(entry: entry)
        default:
            SmallCountdown(entry: entry)
        }
    }
}

/// The big number, its unit, and how far through the period today is.
struct SmallCountdown: View {
    let entry: CountdownEntry

    var body: some View {
        let countdown = entry.countdown
        let theme = entry.theme
        let display = entry.appearance.display
        let alignment: HorizontalAlignment = display.centered ? .center : .leading
        VStack(alignment: alignment, spacing: 2) {
            Text(entry.label ?? countdown.label)
                .font(theme.font(13, .semibold))
                .lineLimit(1)
            if entry.label != nil && display.subtitle {
                Text(countdown.label)
                    .font(theme.font(11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(BigNumber.text(countdown, entry.unit))
                .font(theme.numberFont(44))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(countdown.days <= 14 ? Theme.warning : Color.primary)
            Text(BigNumber.caption(countdown, entry.unit))
                .font(theme.font(12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if display.progressBars {
                ProgressBar(fraction: countdown.fractionComplete, tint: theme.tint(for: countdown))
            }
            if display.endDate {
                Text("Ends \(ShortDate.text(countdown.end))")
                    .font(theme.font(11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: display.centered ? .center : .leading)
    }
}

/// The chosen countdown on the left. On the right, quarter, half, and year side by side,
/// each with its own progress, because they start on different days even when they end together.
struct MediumCountdown: View {
    let entry: CountdownEntry

    var body: some View {
        let theme = entry.theme
        if entry.appearance.display.otherPeriods {
            HStack(alignment: .top, spacing: 16) {
                SmallCountdown(entry: entry)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(entry.snapshot.countdowns, id: \.target) { countdown in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(countdown.label)
                                    .font(theme.font(12, countdown.target == entry.target ? .semibold : .regular))
                                Spacer(minLength: 4)
                                Text(countdown.short(in: entry.unit))
                                    .font(theme.font(12))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            if entry.appearance.display.progressBars {
                                ProgressBar(fraction: countdown.fractionComplete, tint: theme.tint(for: countdown))
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            SmallCountdown(entry: entry)
        }
    }
}

#if os(iOS)
struct CircularCountdown: View {
    let entry: CountdownEntry

    var body: some View {
        let countdown = entry.countdown
        Gauge(value: countdown.fractionComplete) {
            Text(countdown.label)
        } currentValueLabel: {
            Text("\(countdown.value(in: entry.unit))")
                .font(entry.theme.numberFont(16))
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }
}

struct RectangularCountdown: View {
    let entry: CountdownEntry

    var body: some View {
        let countdown = entry.countdown
        let theme = entry.theme
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.label.map { "\($0) · \(countdown.label)" } ?? countdown.label)
                .font(theme.font(15, .semibold))
                .widgetAccentable()
                .lineLimit(1)
            Text("\(countdown.phrase(in: entry.unit)) left")
                .font(theme.font(14))
                .lineLimit(1)
            if entry.appearance.display.progressBars {
                ProgressBar(fraction: countdown.fractionComplete, tint: .primary)
                    .widgetAccentable()
            }
        }
    }
}
#endif

/// How much of the period is behind us. Drawn rather than a ProgressView so the tint always applies.
struct ProgressBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(tint)
                    .frame(width: max(4, proxy.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityLabel("\(Int((fraction * 100).rounded())) percent through")
    }
}

enum BigNumber {
    static func text(_ countdown: Countdown, _ unit: CountdownUnit) -> String {
        unit == .weeks ? countdown.short(in: .weeks) : "\(countdown.value(in: unit))"
    }

    static func caption(_ countdown: Countdown, _ unit: CountdownUnit) -> String {
        let value = countdown.value(in: unit)
        switch unit {
        case .days: return value == 1 ? "day left" : "days left"
        case .workdays: return value == 1 ? "workday left" : "workdays left"
        case .weeks: return "left"
        case .weekends: return value == 1 ? "weekend left" : "weekends left"
        }
    }
}

enum ShortDate {
    /// `Dec 31`.
    static func text(_ date: CalendarDate) -> String {
        "\(FiscalMonth.symbol(for: date.month)) \(date.day)"
    }
}

/// A widget drawn at its real size, with its background, for previews inside the apps.
struct WidgetPreview: View {
    let entry: CountdownEntry
    let medium: Bool

    var body: some View {
        Group {
            if medium {
                MediumCountdown(entry: entry)
            } else {
                SmallCountdown(entry: entry)
            }
        }
        .themed(entry.appearance)
        .padding(16)
        .frame(width: medium ? 338 : 158, height: 158)
        .background(CountdownBackground(entry: entry).themed(entry.appearance))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
