import SwiftUI

/// Renamed to `ProgressView` (collides with SwiftUI's ProgressView at call sites —
/// we always reference it as `ProgressView` from inside the Tempo module so the
/// local symbol takes precedence). For safety we additionally namespace via filename.
struct ProgressView: View {
    @EnvironmentObject var store: SessionStore
    @State private var range = "1M"
    @State private var liftForDetail: TopLift? = nil
    private let ranges = ["1W", "1M", "3M", "1Y"]

    private let topLifts: [TopLift] = [
        .init(name: "Back squat", best: "200 lb × 6", delta: "+5 lb", direction: .up),
        .init(name: "Bench press", best: "170 lb × 5", delta: "+5 lb", direction: .up),
        .init(name: "Romanian deadlift", best: "155 lb × 8", delta: "—", direction: .flat),
        .init(name: "Pull-up", best: "12 reps", delta: "+2", direction: .up),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                title: "Progress",
                dateLine: nil,
                trailing: AnyView(RangeSegmented(ranges: ranges, selection: $range))
            )
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 18) {
                    // KPI card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("This month".uppercased()).overlineStyle()
                        KPIRow([
                            (value: "17",       unit: "Sessions"),
                            (value: "12h 32m",  unit: "Active"),
                            (value: "5",        unit: "PRs"),
                        ])
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .card(padding: 0)

                    // Volume chart
                    ChartCard(title: "Volume · weekly", value: "42,800", delta: "▲ 14%",
                              onTap: { store.showToast("Detailed volume chart coming soon", icon: "chart.bar.fill") }) {
                        BarChartView(values: [0.6, 0.78, 0.55, 0.9, 0.72, 0.85, 1.0])
                            .frame(height: 90)
                        HStack {
                            ForEach(["W1","W2","W3","W4","W5","W6","W7"], id: \.self) { w in
                                Text(w).font(Theme.Font.mono(10)).foregroundColor(Theme.Color.fgFaint)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 6)
                    }

                    // 1RM chart
                    ChartCard(title: "Squat · est. 1RM", value: "238 lb", delta: "▲ 8 lb",
                              onTap: { store.showToast("1RM history coming soon", icon: "waveform.path.ecg") }) {
                        LineChartView(
                            you: [70,64,58,62,50,54,42,46,36,28,24],
                            partner: [80,78,70,72,66,60,62,54,50,48,42]
                        )
                        .frame(height: 110)
                        HStack {
                            Text("Apr 14").font(Theme.Font.mono(10)).foregroundColor(Theme.Color.fgFaint)
                            Spacer()
                            Text("May 14").font(Theme.Font.mono(10)).foregroundColor(Theme.Color.fgFaint)
                        }
                        HStack(spacing: 14) {
                            HStack(spacing: 4) {
                                Circle().fill(Theme.Color.you).frame(width: 6, height: 6)
                                Text(store.profile.youLabel).labelStyle(color: Theme.Color.you)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(Theme.Color.partner).frame(width: 6, height: 6)
                                Text(store.partner.name).labelStyle(color: Theme.Color.partner)
                            }
                        }
                    }

                    // Top lifts list
                    VStack(spacing: 0) {
                        SectionHead(title: "Top lifts", meta: "Tap for chart")
                            .padding(.bottom, 8)
                        VStack(spacing: 0) {
                            ForEach(topLifts) { lift in
                                Button(action: { liftForDetail = lift }) {
                                    topLiftRow(lift)
                                }
                                .buttonStyle(.plain)
                                if lift.id != topLifts.last?.id {
                                    Divider().background(Theme.Color.hairline)
                                }
                            }
                        }
                        .card(padding: 0)
                    }

                    // Coverage heatmap
                    ChartCard(title: "Coverage · last 6 weeks", value: nil, delta: nil, meta: "By muscle group",
                              onTap: { store.showToast("Muscle-group coverage detail coming soon", icon: "square.grid.3x3.fill") }) {
                        VStack(spacing: 8) {
                            heatmapRow("Quads",     cells: [3,2,4,1,3,4,2], val: "19 sessions")
                            heatmapRow("Hamstrings",cells: [2,3,2,2,3,2,4], val: "18 sessions")
                            heatmapRow("Glutes",    cells: [3,4,2,3,3,4,3], val: "22 sessions")
                            heatmapRow("Chest",     cells: [1,2,0,2,1,2,1], val: "9 sessions")
                            heatmapRow("Back",      cells: [2,1,2,3,2,1,3], val: "14 sessions")
                            heatmapRow("Core",      cells: [2,2,3,2,3,2,3], val: "17 sessions")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .sheet(item: $liftForDetail) { lift in
            LiftDetailSheet(lift: lift)
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.Color.bgElev1)
        }
    }

    private func topLiftRow(_ lift: TopLift) -> some View {
        HStack {
            Text(lift.name).font(Theme.Font.sans(14)).foregroundColor(Theme.Color.fg)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(lift.best)
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundColor(Theme.Color.fg)
            Text(lift.delta)
                .font(Theme.Font.mono(11, .medium))
                .foregroundColor(deltaColor(lift.direction))
                .frame(width: 56, alignment: .trailing)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.Color.fgFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func deltaColor(_ d: TrendDirection) -> Color {
        switch d {
        case .up:   return Theme.Color.accent
        case .down: return Theme.Color.dangerSoft
        case .flat: return Theme.Color.fgFaint
        }
    }

    private func heatmapRow(_ name: String, cells: [Int], val: String) -> some View {
        Button(action: { store.showToast("\(name): \(val)", icon: "square.grid.3x3.fill") }) {
            HStack(spacing: 10) {
                Text(name).font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgMute)
                    .frame(width: 86, alignment: .leading)
                HStack(spacing: 4) {
                    ForEach(0..<cells.count, id: \.self) { i in
                        Rectangle()
                            .fill(Theme.Color.accent.opacity(Double(cells[i]) / 4 * 0.85))
                            .frame(height: 20)
                            .overlay(
                                Rectangle().strokeBorder(Theme.Color.hairline, lineWidth: 0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .frame(maxWidth: .infinity)
                Text(val).font(Theme.Font.mono(10.5)).foregroundColor(Theme.Color.fgSoft)
                    .frame(width: 76, alignment: .trailing)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Range segmented

private struct RangeSegmented: View {
    var ranges: [String]
    @Binding var selection: String
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ranges, id: \.self) { r in
                Button(action: { selection = r }) {
                    Text(r)
                        .font(Theme.Font.mono(11, .medium))
                        .foregroundColor(selection == r ? Theme.Color.fg : Theme.Color.fgMute)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(selection == r ? Theme.Color.bgElev3 : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Theme.Color.bgElev2)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.Color.hairline, lineWidth: 1))
        .frame(width: 168)
    }
}

// MARK: - Chart card

private struct ChartCard<Content: View>: View {
    var title: String
    var value: String? = nil
    var delta: String? = nil
    var meta: String? = nil
    var onTap: (() -> Void)? = nil
    @ViewBuilder var content: Content

    var body: some View {
        let card = VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title.uppercased()).overlineStyle()
                Spacer()
                if let value, let delta {
                    HStack(spacing: 8) {
                        Text(value).font(.system(size: 14, weight: .medium).monospacedDigit()).foregroundColor(Theme.Color.fg)
                        Text(delta).font(Theme.Font.mono(11)).foregroundColor(Theme.Color.accent)
                    }
                } else if let meta {
                    Text(meta).font(Theme.Font.mono(10.5)).foregroundColor(Theme.Color.fgSoft)
                }
                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.Color.fgFaint)
                        .padding(.leading, 6)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .card(padding: 0)

        if let onTap {
            Button(action: onTap) { card }
                .buttonStyle(PressableStyle())
        } else {
            card
        }
    }
}

// MARK: - Lift detail sheet

private struct LiftDetailSheet: View {
    let lift: TopLift

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Top lift".uppercased()).overlineStyle()
                Text(lift.name).font(.system(size: 28, weight: .semibold)).foregroundColor(Theme.Color.fg)
                HStack(spacing: 6) {
                    Text(lift.best)
                        .font(.system(size: 14, weight: .medium).monospacedDigit())
                        .foregroundColor(Theme.Color.fg)
                    Text("·").foregroundColor(Theme.Color.fgFaint)
                    Text(lift.delta).font(Theme.Font.mono(12, .medium)).foregroundColor(Theme.Color.accent)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Trend".uppercased()).overlineStyle()
                LineChartView(
                    you: [70, 72, 68, 75, 78, 76, 82, 85, 88, 90, 95],
                    partner: [60, 62, 60, 65, 64, 68, 70, 72, 75, 78, 80]
                )
                .frame(height: 160)
            }
            .padding(18)
            .card(padding: 0)

            VStack(alignment: .leading, spacing: 12) {
                Text("Recent attempts".uppercased()).overlineStyle()
                ForEach(0..<5) { i in
                    HStack {
                        Text("Week \(i + 1)").font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
                        Spacer()
                        Text("\(180 + i * 5) lb × \(6 - (i % 2))")
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundColor(Theme.Color.fg)
                    }
                    .padding(.vertical, 4)
                    if i < 4 { Divider().background(Theme.Color.hairline) }
                }
            }
            .padding(16)
            .card(padding: 0)

            Spacer()
        }
        .padding(20)
        .background(Theme.Color.bgElev1)
    }
}

// MARK: - Bar chart

struct BarChartView: View {
    var values: [Double]   // 0...1
    var body: some View {
        GeometryReader { geo in
            let w = max(0, geo.size.width - CGFloat(values.count - 1) * 12) / CGFloat(values.count)
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(0..<values.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(i == values.count - 1 ? Theme.Color.accent : Theme.Color.bgElev3)
                        .frame(width: w, height: max(8, values[i] * geo.size.height))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

// MARK: - Line chart (you + partner)

struct LineChartView: View {
    var you: [Double]
    var partner: [Double]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // gridlines
                ForEach([0.0, 0.33, 0.66, 1.0], id: \.self) { r in
                    Path { p in
                        let y = r * (h - 20) + 10
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                    .foregroundColor(Theme.Color.hairline)
                }

                // partner line
                line(points: partner, in: geo.size)
                    .stroke(Theme.Color.partner.opacity(0.65), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

                // you area
                area(points: you, in: geo.size)
                    .fill(Theme.Color.accent.opacity(0.08))

                line(points: you, in: geo.size)
                    .stroke(Theme.Color.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // end dot
                if let last = you.last {
                    let y = CGFloat(last) / 100 * h
                    Circle().fill(Theme.Color.accent).frame(width: 8, height: 8)
                        .position(x: w - 4, y: y)
                }
            }
        }
    }

    private func line(points: [Double], in size: CGSize) -> Path {
        Path { p in
            let stepX = size.width / CGFloat(max(1, points.count - 1))
            for (i, v) in points.enumerated() {
                let pt = CGPoint(x: CGFloat(i) * stepX, y: CGFloat(v) / 100 * size.height)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
        }
    }

    private func area(points: [Double], in size: CGSize) -> Path {
        Path { p in
            let stepX = size.width / CGFloat(max(1, points.count - 1))
            for (i, v) in points.enumerated() {
                let pt = CGPoint(x: CGFloat(i) * stepX, y: CGFloat(v) / 100 * size.height)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.addLine(to: CGPoint(x: size.width, y: size.height))
            p.addLine(to: CGPoint(x: 0, y: size.height))
            p.closeSubpath()
        }
    }
}
