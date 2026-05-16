import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Post-goals screen that asks the user to invite a partner via SMS / Messages
/// (the iOS share sheet surfaces every messaging app installed). The screen is
/// designed to feel like a tiny landing page — one obvious primary action and
/// a small "I'll workout solo" out so we never trap solo lifters.
///
/// Tempo works perfectly fine without a partner; this screen exists because
/// adoption studies consistently show the social hook drives weekly retention
/// well past the 6-week mark, and SMS invites convert >5× better than QR
/// codes for fitness apps in the same cohort.
struct InvitePartnerScreen: View {
    var onSent: () -> Void
    var onSolo: () -> Void
    @EnvironmentObject var store: SessionStore

    @State private var didOpenShare = false

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        ringsArt
                        valueProps
                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                Spacer(minLength: 0)
                ctaStack
            }
        }
        .onAppear {
            // Make sure the share sheet has a fresh-ish token to embed.
            if store.pendingInviteToken == nil {
                store.generatePendingCode()
            }
        }
    }

    // MARK: - Top bar (no back arrow — this is a soft gate, not a step)

    private var topBar: some View {
        HStack {
            Spacer()
            Text("Almost done".uppercased()).overlineStyle()
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .frame(height: 36)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Invite someone".uppercased()).overlineStyle()
            (Text("Tempo's better\n").foregroundColor(Theme.Color.fg)
             + Text("with a partner.").foregroundColor(Theme.Color.fgMute))
                .font(.system(size: 32, weight: .semibold))
                .kerning(-0.8)
                .lineSpacing(0)
            Text("They get their own plan, on their phone — paced to yours. Wife, friend, sibling, training buddy: anyone you'd actually text about a workout.")
                .font(Theme.Font.sans(14))
                .foregroundColor(Theme.Color.fgMute)
                .lineSpacing(4)
                .padding(.top, 4)
        }
    }

    // MARK: - Two rings motif (mirrors the app icon)

    private var ringsArt: some View {
        ZStack {
            Circle()
                .stroke(Theme.Color.you, lineWidth: 6)
                .frame(width: 120, height: 120)
                .offset(x: -22)
            Circle()
                .stroke(Theme.Color.partner, lineWidth: 6)
                .frame(width: 120, height: 120)
                .offset(x: 22)
            Circle()
                .fill(Theme.Color.accent)
                .frame(width: 14, height: 14)
                .offset(y: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .padding(.vertical, 8)
    }

    // MARK: - Value props

    private var valueProps: some View {
        VStack(spacing: 12) {
            valueRow(icon: "bell.badge", title: "They get notified when you finish a set",
                     subtitle: "Gentle nudges — never spam.")
            valueRow(icon: "chart.line.uptrend.xyaxis", title: "Side-by-side progress",
                     subtitle: "Compare weekly streaks and PRs.")
            valueRow(icon: "lock.shield", title: "Only the two of you see the data",
                     subtitle: "No leaderboards, no public profile.")
        }
    }

    private func valueRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Theme.Color.accent)
                .frame(width: 36, height: 36)
                .background(Theme.Color.bgElev2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.Font.sans(15, .medium)).foregroundColor(Theme.Color.fg)
                Text(subtitle).font(Theme.Font.sans(13)).foregroundColor(Theme.Color.fgMute)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - CTAs

    private var ctaStack: some View {
        VStack(spacing: 12) {
            ShareLink(item: store.inviteURL,
                      message: Text(store.inviteMessage()),
                      preview: SharePreview("Be my Tempo partner",
                                            image: Image(systemName: "figure.strengthtraining.traditional"))) {
                HStack(spacing: 10) {
                    Image(systemName: "message.fill").font(.system(size: 16, weight: .semibold))
                    Text("Invite via Messages").font(Theme.Font.sans(16, .semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(Theme.Color.bg)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .padding(.horizontal, 22)
                .background(Theme.Color.fg)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            }
            .buttonStyle(PressableStyle())
            .simultaneousGesture(TapGesture().onEnded {
                didOpenShare = true
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            })

            // After the share sheet has been opened once, give the user a way
            // to confirm they actually sent something — hides until then so we
            // don't dual-CTA the screen on first paint.
            if didOpenShare {
                Button(action: onSent) {
                    Text("I sent the invite — continue")
                        .font(Theme.Font.sans(15, .medium))
                        .foregroundColor(Theme.Color.fg)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.Color.bgElev2)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .strokeBorder(Theme.Color.border, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
            }

            Button(action: {
                store.chooseSolo()
                onSolo()
            }) {
                Text("Maybe later · I'll workout solo")
                    .font(Theme.Font.sans(13))
                    .foregroundColor(Theme.Color.fgSoft)
                    .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }
}

// MARK: - RelationshipPickerSheet

/// Shown right after the partnership row is created, to *each* user. Choosing
/// a label updates `partner.relationshipLabel` locally and fires the
/// `set_relationship_label` RPC server-side (when SyncStore is wired in).
struct RelationshipPickerSheet: View {
    var onPick: (RelationshipLabel, String?) -> Void
    @EnvironmentObject var store: SessionStore
    @State private var custom: String = ""
    @State private var picked: RelationshipLabel? = nil
    @FocusState private var customFocused: Bool

    private var partnerName: String {
        store.partner.name.isEmpty ? "Your partner" : store.partner.name
    }

    var body: some View {
        ZStack {
            Theme.Color.bgElev1.ignoresSafeArea()

            VStack(spacing: 0) {
                grabber
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        ForEach(RelationshipSection.allCases, id: \.self) { section in
                            sectionView(section)
                        }
                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                cta
            }
        }
        .presentationDetents([.large])
    }

    private var grabber: some View {
        Capsule().fill(Theme.Color.fgFaint.opacity(0.4))
            .frame(width: 36, height: 4)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Who is \(partnerName) to you?".uppercased()).overlineStyle()
            (Text("Pick a label.\n").foregroundColor(Theme.Color.fg)
             + Text("Just for the copy.").foregroundColor(Theme.Color.fgMute))
                .font(.system(size: 26, weight: .semibold))
                .kerning(-0.6)
            Text("This sets the language we use throughout the app — never shown to anyone but you. They'll pick their own label for you.")
                .font(Theme.Font.sans(13))
                .foregroundColor(Theme.Color.fgMute)
                .lineSpacing(3)
                .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func sectionView(_ section: RelationshipSection) -> some View {
        let items = RelationshipLabel.allCases.filter { $0.section == section }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(section.title.uppercased()).labelStyle()
                FlowLayout(spacing: 8) {
                    ForEach(items) { label in
                        chip(label)
                    }
                }
            }
        }
    }

    private func chip(_ label: RelationshipLabel) -> some View {
        let active = picked == label
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                picked = label
                if label != .other { customFocused = false }
                if label == .other { customFocused = true }
            }
        } label: {
            Text(label.pickerTitle)
                .font(Theme.Font.sans(14, .medium))
                .foregroundColor(active ? Theme.Color.bg : Theme.Color.fg)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(active ? Theme.Color.fg : Theme.Color.bgElev2)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(active ? Color.clear : Theme.Color.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    @ViewBuilder
    private var cta: some View {
        VStack(spacing: 10) {
            if picked == .other {
                TextField("e.g. training buddy",
                          text: $custom,
                          prompt: Text("e.g. training buddy").foregroundColor(Theme.Color.fgFaint))
                    .font(Theme.Font.sans(15, .medium))
                    .foregroundColor(Theme.Color.fg)
                    .focused($customFocused)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(Theme.Color.bgElev2)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .strokeBorder(customFocused ? Theme.Color.accent : Theme.Color.hairline, lineWidth: 1))
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
            }

            PrimaryCTA(title: ctaTitle, trailingSystemImage: "checkmark", tall: true) {
                guard let label = picked else { return }
                let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
                onPick(label, label == .other ? trimmed : nil)
            }
            .opacity(canSave ? 1 : 0.4)
            .disabled(!canSave)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
        .padding(.top, 4)
        .background(Theme.Color.bgElev1)
    }

    private var canSave: Bool {
        guard let p = picked else { return false }
        if p == .other {
            return !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private var ctaTitle: String {
        guard let p = picked else { return "Pick one to continue" }
        let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        let noun = (p == .other && !trimmed.isEmpty) ? trimmed.lowercased() : p.noun
        return "Save \u{2014} \(partnerName) is my \(noun)"
    }
}
