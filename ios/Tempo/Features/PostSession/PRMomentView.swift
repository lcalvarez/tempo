import SwiftUI

struct PRMomentView: View {
    var payload: PRPayload
    var onLog: () -> Void
    @State private var burst = false

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()

            RadialGradient(
                colors: [Theme.Color.pr.opacity(0.18), Theme.Color.bg.opacity(0.95)],
                center: .center, startRadius: 30, endRadius: 380
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle().fill(Theme.Color.pr.opacity(0.18)).frame(width: 160, height: 160).blur(radius: 16)
                    Circle()
                        .fill(RadialGradient(colors: [Theme.Color.pr, Theme.Color.pr.opacity(0.6)],
                                             center: .center, startRadius: 0, endRadius: 60))
                        .frame(width: 120, height: 120)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 2))
                    Text("PR")
                        .font(.system(size: 40, weight: .bold))
                        .kerning(-1.6)
                        .foregroundColor(Theme.Color.bg)
                }
                .scaleEffect(burst ? 1 : 0.8)
                .opacity(burst ? 1 : 0)

                VStack(spacing: 8) {
                    Text("Personal record".uppercased()).overlineStyle(color: Theme.Color.pr)
                    Text(payload.name)
                        .font(.system(size: 32, weight: .semibold))
                        .kerning(-0.7)
                        .foregroundColor(Theme.Color.fg)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(payload.reps)").font(.system(size: 64, weight: .semibold).monospacedDigit()).foregroundColor(Theme.Color.fg)
                        Text("×").font(.system(size: 22)).foregroundColor(Theme.Color.fgFaint)
                        Text("\(payload.weight)").font(.system(size: 64, weight: .semibold).monospacedDigit()).foregroundColor(Theme.Color.fg)
                    }
                    .padding(.top, 8)

                    Text("REPS × LB").labelStyle().padding(.top, 2)

                    if payload.previous > 0 {
                        Text("Previous best · \(payload.reps) × \(payload.previous)")
                            .font(Theme.Font.mono(12))
                            .foregroundColor(Theme.Color.fgSoft)
                            .padding(.top, 12)
                    } else {
                        Text("First time logging this lift").font(Theme.Font.mono(12)).foregroundColor(Theme.Color.fgSoft).padding(.top, 12)
                    }
                }

                Spacer()

                VStack(spacing: 10) {
                    PrimaryCTA(title: "Log it", trailingSystemImage: "checkmark", tall: true, action: onLog)
                    Button("Failed — adjust", action: onLog)
                        .font(Theme.Font.sans(14)).foregroundColor(Theme.Color.fgMute)
                }
                .padding(.horizontal, 24).padding(.bottom, 32)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) { burst = true }
        }
    }
}
