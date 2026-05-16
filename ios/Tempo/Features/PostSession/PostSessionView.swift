import SwiftUI

struct PostSessionView: View {
    var onDone: () -> Void
    @EnvironmentObject var store: SessionStore
    @State private var note: String = ""
    @FocusState private var noteFocused: Bool

    private struct ComparisonRow {
        var exercise: String
        var pr: Bool
        var you: [String]
        var partner: [String]
    }

    private let rows: [ComparisonRow] = [
        .init(exercise: "Back squat", pr: true,
              you: ["Set 1 · 6 × 195", "Set 2 · 6 × 195", "Set 3 · 6 × 200", "Set 4 · 5 × 200"],
              partner: ["Set 1 · 8 × 35", "Set 2 · 8 × 35", "Set 3 · 8 × 35", "Set 4 · 8 × 40"]),
        .init(exercise: "Romanian deadlift", pr: false,
              you: ["Set 1 · 8 × 155", "Set 2 · 8 × 155", "Set 3 · 8 × 155"],
              partner: ["Set 1 · 10 × 95", "Set 2 · 10 × 95", "Set 3 · 10 × 100"]),
        .init(exercise: "Walking lunge", pr: false,
              you: ["3 × 20 · bodyweight"],
              partner: ["3 × 16 · bodyweight"]),
        .init(exercise: "Hanging leg raise", pr: true,
              you: ["3 × 12"],
              partner: ["—"]),
        .init(exercise: "Plank", pr: false,
              you: ["3 × 45s"],
              partner: ["3 × 30s"]),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Color.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    // Hero
                    VStack(spacing: 6) {
                        Text("Done · in tempo".uppercased()).overlineStyle(color: Theme.Color.accent)
                        Text("45:08")
                            .font(.system(size: 64, weight: .semibold).monospacedDigit())
                            .kerning(-2.6)
                            .foregroundColor(Theme.Color.fg)
                        Text("Lower body & core · together").labelStyle()
                    }
                    .padding(.top, 40)

                    // Streak update
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Theme.Color.prDim)
                            Image(systemName: "flame.fill").font(.system(size: 18)).foregroundColor(Theme.Color.pr)
                        }
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("24-day streak").font(.system(size: 17, weight: .semibold)).foregroundColor(Theme.Color.fg)
                            Text("Longest yet — keep it rolling Wed")
                                .font(Theme.Font.mono(11)).foregroundColor(Theme.Color.fgSoft)
                        }
                        Spacer()
                        Text("+1").font(.system(size: 22, weight: .semibold).monospacedDigit()).foregroundColor(Theme.Color.fg)
                    }
                    .card()

                    // KPIs
                    KPIRow([
                        (value: "8,650", unit: "Volume lb · you"),
                        (value: "2",     unit: "PRs hit"),
                        (value: "38:21", unit: "Active time"),
                    ])

                    HStack {
                        Text("Side-by-side".uppercased()).overlineStyle()
                        Spacer()
                    }
                    .padding(.top, 8)

                    // Comparison rows
                    VStack(spacing: 10) {
                        ForEach(0..<rows.count, id: \.self) { i in
                            comparisonCard(rows[i])
                        }
                    }

                    // Reactions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Send \(store.partner.name) a reaction".uppercased()).overlineStyle()
                        HStack(spacing: 6) {
                            ForEach(["💪","🔥","👏","😮‍💨"], id: \.self) { e in
                                Button(action: { sendReaction(e) }) {
                                    Text(e)
                                        .font(.system(size: 18))
                                        .frame(width: 44, height: 36)
                                        .background(Theme.Color.bgElev2)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().strokeBorder(Theme.Color.hairline, lineWidth: 1))
                                }
                                .buttonStyle(PressableStyle())
                            }
                            TextField("", text: $note,
                                      prompt: Text("Type a note…").foregroundColor(Theme.Color.fgSoft))
                                .font(Theme.Font.sans(13))
                                .foregroundColor(Theme.Color.fg)
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(Theme.Color.bgElev2)
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Theme.Color.hairline, lineWidth: 1))
                                .focused($noteFocused)
                                .submitLabel(.send)
                                .onSubmit(sendNote)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 20)
            }

            VStack {
                PrimaryCTA(title: "Done", trailingSystemImage: "checkmark", tall: true, action: onDone)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
            }
            .background(
                LinearGradient(colors: [Theme.Color.bg.opacity(0), Theme.Color.bg], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    private func sendReaction(_ emoji: String) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        store.showToast("Sent \(emoji) to \(store.partner.name)", icon: "paperplane.fill")
    }

    private func sendNote() {
        let trimmed = note.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.showToast("Note sent to \(store.partner.name)", icon: "paperplane.fill")
        note = ""
        noteFocused = false
    }

    private func comparisonCard(_ row: ComparisonRow) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(row.exercise).font(Theme.Font.sans(14, .medium)).foregroundColor(Theme.Color.fg)
                if row.pr {
                    Text("★ Personal record")
                        .font(Theme.Font.mono(10, .medium))
                        .foregroundColor(Theme.Color.pr)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.Color.prDim)
                        .clipShape(Capsule())
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.Color.bgElev2)

            HStack(alignment: .top, spacing: 0) {
                column(label: store.profile.youLabel, color: Theme.Color.you, values: row.you)
                Rectangle().fill(Theme.Color.hairline).frame(width: 1)
                column(label: store.partner.name, color: Theme.Color.partner, values: row.partner)
            }
        }
        .card(padding: 0)
    }

    private func column(label: String, color: Color, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).labelStyle(color: color)
            ForEach(values, id: \.self) { v in
                Text(v).font(Theme.Font.mono(12)).foregroundColor(Theme.Color.fg)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
