import SwiftUI

enum PictureKind: String, CaseIterable, Identifiable {
    case line
    case year
    case ring

    var id: String { rawValue }

    var title: String {
        switch self {
        case .line:
            return "Line"
        case .year:
            return "Year"
        case .ring:
            return "Ring"
        }
    }
}

enum MarkColor {
    static let green = Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255)
    static let warning = Color(red: 217 / 255, green: 119 / 255, blue: 6 / 255)
}

/// One picture of the fiscal year. The panel keeps a single slot and swaps which picture is in it.
struct YearPicture: View {
    let snapshot: QuarterSnapshot
    let kind: PictureKind
    let select: (PictureKind) -> Void

    private var chart: FiscalYearMap {
        FiscalYearMap.containing(snapshot.today, calendar: snapshot.calendar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            picker
            picture
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(chart.summary(on: snapshot.today))
        }
    }

    private var picker: some View {
        HStack(spacing: 2) {
            ForEach(PictureKind.allCases) { picture in
                Button(action: { select(picture) }) {
                    Text(picture.title)
                        .font(.system(size: 11, weight: kind == picture ? .semibold : .regular))
                        .foregroundStyle(kind == picture ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(kind == picture ? Color.primary.opacity(0.08) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(kind == picture ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(Color.primary.opacity(0.05)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Picture of the year")
    }

    @ViewBuilder
    private var picture: some View {
        switch kind {
        case .line:
            YearLine(chart: chart, today: snapshot.today)
        case .year:
            YearCalendar(chart: chart, today: snapshot.today)
        case .ring:
            YearRing(chart: chart, today: snapshot.today)
        }
    }
}

// MARK: - Line

private struct YearLine: View {
    let chart: FiscalYearMap
    let today: CalendarDate

    private var currentQuarter: Int {
        chart.quarterNumber(on: today)
    }

    var body: some View {
        GeometryReader { geo in
            let layout = LineLayout(chart: chart, today: today, width: geo.size.width)
            ZStack(alignment: .topLeading) {
                ForEach(Array(chart.quarters.enumerated()), id: \.element.id) { index, quarter in
                    if index < layout.quarterSpans.count {
                        Text("Q\(quarter.quarter)")
                            .font(.system(size: 10, weight: quarter.quarter == currentQuarter ? .semibold : .medium))
                            .foregroundStyle(quarter.quarter == currentQuarter ? MarkColor.green : Color.secondary)
                            .position(x: layout.quarterSpans[index].midX, y: 8)
                    }
                }

                ForEach(Array(chart.months.enumerated()), id: \.element.id) { index, month in
                    let span = layout.monthSpans[index]
                    monthBar(month, span: span)
                        .position(x: span.midX, y: 26)
                    Text(month.symbol)
                        .font(.system(size: 9, weight: month.contains(today) ? .semibold : .regular))
                        .foregroundStyle(month.contains(today) ? Color.primary : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(width: max(span.width, 18))
                        .position(x: span.midX, y: 44)
                }

                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(MarkColor.green, lineWidth: 2))
                    .position(x: layout.todayX, y: 26)
            }
        }
        .frame(height: 54)
    }

    private func monthBar(_ month: FiscalMonth, span: LineLayout.Span) -> some View {
        let here = month.quarter == currentQuarter
        let fill = month.fill(on: today)
        return Capsule()
            .fill(here ? MarkColor.green.opacity(0.16) : Color.primary.opacity(0.08))
            .frame(width: span.width, height: 7)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(here ? MarkColor.green : Color.primary.opacity(0.45))
                    .frame(width: span.width * fill)
            }
            .clipShape(Capsule())
    }
}

private struct LineLayout {
    struct Span {
        var x: CGFloat
        var width: CGFloat
        var midX: CGFloat { x + width / 2 }
    }

    let monthSpans: [Span]
    let quarterSpans: [Span]
    let todayX: CGFloat

    init(chart: FiscalYearMap, today: CalendarDate, width: CGFloat) {
        let monthGap: CGFloat = 3
        let quarterGap: CGFloat = 11
        let months = chart.months
        var gapTotal: CGFloat = 0
        if months.count > 1 {
            for index in 1..<months.count {
                gapTotal += months[index].quarter == months[index - 1].quarter ? monthGap : quarterGap
            }
        }
        let dayWidth = chart.length > 0 ? max(0, width - gapTotal) / CGFloat(chart.length) : 0
        var spans: [Span] = []
        var cursor: CGFloat = 0
        for (index, month) in months.enumerated() {
            let bar = dayWidth * CGFloat(month.length)
            spans.append(Span(x: cursor, width: bar))
            if index < months.count - 1 {
                let gap = months[index + 1].quarter == month.quarter ? monthGap : quarterGap
                cursor += bar + gap
            }
        }
        monthSpans = spans

        var quarters: [Span] = []
        for quarter in chart.quarters {
            let members = chart.months(in: quarter)
            guard
                let first = members.first.flatMap({ months.firstIndex(of: $0) }),
                let last = members.last.flatMap({ months.firstIndex(of: $0) }),
                spans.indices.contains(first),
                spans.indices.contains(last)
            else {
                continue
            }
            let origin = spans[first].x
            let finish = spans[last].x + spans[last].width
            quarters.append(Span(x: origin, width: finish - origin))
        }
        quarterSpans = quarters

        if let index = months.firstIndex(where: { $0.contains(today) }), spans.indices.contains(index) {
            let span = spans[index]
            let day = FiscalCalendar.inclusiveDays(from: months[index].start, to: today)
            let fraction = (CGFloat(day) - 0.5) / CGFloat(max(months[index].length, 1))
            todayX = span.x + span.width * fraction
        } else {
            todayX = 0
        }
    }
}

// MARK: - Year

private struct YearCalendar: View {
    let chart: FiscalYearMap
    let today: CalendarDate

    private let column: CGFloat = 44

    private var currentQuarter: Int {
        chart.quarterNumber(on: today)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 18) {
                quarterBlock(0)
                quarterBlock(1)
            }
            HStack(alignment: .top, spacing: 18) {
                quarterBlock(2)
                quarterBlock(3)
            }
        }
    }

    @ViewBuilder
    private func quarterBlock(_ index: Int) -> some View {
        if chart.quarters.indices.contains(index) {
            let quarter = chart.quarters[index]
            VStack(alignment: .leading, spacing: 5) {
                Text("Q\(quarter.quarter)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(quarter.quarter == currentQuarter ? MarkColor.green : Color.secondary)
                HStack(alignment: .top, spacing: 6) {
                    ForEach(chart.months(in: quarter)) { month in
                        MonthDots(month: month, today: today, currentQuarter: currentQuarter)
                            .frame(width: column, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MonthDots: View {
    let month: FiscalMonth
    let today: CalendarDate
    let currentQuarter: Int

    private let cell: CGFloat = 5
    private let gap: CGFloat = 1.5

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(month.symbol)
                .font(.system(size: 9, weight: month.contains(today) ? .semibold : .regular))
                .foregroundStyle(month.contains(today) ? Color.primary : Color.secondary)
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cell), spacing: gap), count: 7),
                spacing: gap
            ) {
                ForEach(Array(month.cells().enumerated()), id: \.offset) { _, cellDate in
                    dot(cellDate.date)
                }
            }
        }
    }

    @ViewBuilder
    private func dot(_ date: CalendarDate?) -> some View {
        if let date {
            if date == today {
                Circle()
                    .strokeBorder(MarkColor.green, lineWidth: 1.25)
                    .frame(width: cell, height: cell)
            } else {
                Circle()
                    .fill(ink(for: date))
                    .frame(width: 5, height: 5)
                    .frame(width: cell, height: cell)
            }
        } else {
            Color.clear.frame(width: cell, height: cell)
        }
    }

    private func ink(for date: CalendarDate) -> Color {
        let past = date < today
        if month.quarter == currentQuarter {
            return MarkColor.green.opacity(past ? 0.95 : 0.24)
        }
        return Color.primary.opacity(past ? 0.5 : 0.14)
    }
}

// MARK: - Ring

private struct YearRing: View {
    let chart: FiscalYearMap
    let today: CalendarDate

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 20
            let geometry = RingGeometry(chart: chart, today: today, center: center, radius: radius)
            ZStack {
                Canvas { context, _ in
                    strokeQuarters(context, geometry)
                    strokeTicks(context, geometry)
                }
                ForEach(chart.quarters, id: \.id) { quarter in
                    Text("Q\(quarter.quarter)")
                        .font(.system(size: 10, weight: quarter.quarter == geometry.current ? .semibold : .medium))
                        .foregroundStyle(quarter.quarter == geometry.current ? MarkColor.green : Color.secondary)
                        .position(geometry.labelPoint(for: quarter))
                }
                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(MarkColor.green, lineWidth: 2.5))
                    .position(geometry.point(for: today, radius: radius))
                VStack(spacing: -1) {
                    Text(FiscalMonth.symbol(for: today.month).uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(.secondary)
                    Text("\(today.day)")
                        .font(.system(size: 30, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
                .position(x: center.x, y: center.y)
            }
        }
        .frame(height: 196)
    }

    private func strokeQuarters(_ context: GraphicsContext, _ geometry: RingGeometry) {
        for quarter in chart.quarters {
            let here = quarter.quarter == geometry.current
            let past = quarter.end < today
            let track: Color
            if here {
                track = MarkColor.green.opacity(0.2)
            } else if past {
                track = Color.primary.opacity(0.4)
            } else {
                track = Color.primary.opacity(0.12)
            }
            stroke(context, geometry.arc(for: quarter), color: track, width: 9)
            if here {
                stroke(context, geometry.elapsedArc(on: today), color: MarkColor.green, width: 9, cap: .butt)
            }
        }
    }

    private func strokeTicks(_ context: GraphicsContext, _ geometry: RingGeometry) {
        for month in chart.months where month.start != geometry.quarterStart(month) {
            var tick = Path()
            tick.move(to: geometry.point(for: month.start, radius: geometry.radius - 2))
            tick.addLine(to: geometry.point(for: month.start, radius: geometry.radius - 9))
            context.stroke(tick, with: .color(.primary.opacity(0.35)), lineWidth: 1)
        }
    }

    private func stroke(
        _ context: GraphicsContext,
        _ path: Path,
        color: Color,
        width: CGFloat,
        cap: CGLineCap = .round
    ) {
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: cap)
        )
    }
}

private struct RingGeometry {
    let chart: FiscalYearMap
    let today: CalendarDate
    let center: CGPoint
    let radius: CGFloat
    let gap = 13.0

    var current: Int {
        chart.quarterNumber(on: today)
    }

    var degreesPerDay: Double {
        let gaps = gap * Double(chart.quarters.count)
        guard chart.length > 0 else { return 0 }
        return (360 - gaps) / Double(chart.length)
    }

    func startDegrees(of quarter: FiscalQuarter) -> Double {
        var degrees = -90.0
        for candidate in chart.quarters {
            if candidate.id == quarter.id { return degrees }
            degrees += sweep(of: candidate) + gap
        }
        return degrees
    }

    func sweep(of quarter: FiscalQuarter) -> Double {
        degreesPerDay * Double(FiscalCalendar.inclusiveDays(from: quarter.start, to: quarter.end))
    }

    func arc(for quarter: FiscalQuarter) -> Path {
        arc(from: startDegrees(of: quarter), sweep: sweep(of: quarter))
    }

    func elapsedArc(on today: CalendarDate) -> Path {
        guard let quarter = chart.quarters.first(where: { today >= $0.start && today <= $0.end }) else {
            return Path()
        }
        let days = FiscalCalendar.inclusiveDays(from: quarter.start, to: today)
        let throughToday = max(0, Double(days) - 0.5)
        return arc(from: startDegrees(of: quarter), sweep: degreesPerDay * throughToday)
    }

    func labelPoint(for quarter: FiscalQuarter) -> CGPoint {
        let mid = startDegrees(of: quarter) + sweep(of: quarter) / 2
        return point(degrees: mid, radius: radius + 16)
    }

    func point(for date: CalendarDate, radius: CGFloat) -> CGPoint {
        guard let quarter = chart.quarters.first(where: { date >= $0.start && date <= $0.end }) else {
            return center
        }
        let day = FiscalCalendar.inclusiveDays(from: quarter.start, to: date)
        let degrees = startDegrees(of: quarter) + degreesPerDay * (Double(day) - 0.5)
        return point(degrees: degrees, radius: radius)
    }

    func quarterStart(_ month: FiscalMonth) -> CalendarDate {
        chart.quarters.first { $0.quarter == month.quarter }?.start ?? month.start
    }

    private func arc(from start: Double, sweep: Double) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(start),
            endAngle: .degrees(start + sweep),
            clockwise: false
        )
        return path
    }

    private func point(degrees: Double, radius: CGFloat) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(
            x: center.x + CGFloat(cos(radians)) * radius,
            y: center.y + CGFloat(sin(radians)) * radius
        )
    }
}
