import SwiftUI
import Translation

struct ContentView: View {
    @Environment(\.scenePhase) private var phase
    @State private var installed = false
    @State private var downloading = false
    @State private var config: TranslationSession.Configuration?
    @State private var pending: [Lang] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero
                VStack(spacing: 12) {
                    step(1, "Download English & Spanish",
                         installed ? "Ready — translations run on your iPhone, offline." : "One-time download, works offline after.",
                         done: installed) {
                        if downloading {
                            ProgressView()
                        } else if !installed {
                            pill("Download") { download() }
                        }
                    }
                    step(2, "Add the Hablo keyboard",
                         "Settings → Hablo → Keyboards → turn on Hablo.",
                         done: false) {
                        pill("Open") { openSettings() }
                    }
                    step(3, "Allow Full Access (optional)",
                         "Only for haptics and an online fallback. Typing never leaves your phone otherwise.",
                         done: false) { EmptyView() }
                    step(4, "Add the Calendario widget",
                         "Long-press the Home Screen → + → Hablo. Long-press the widget → Edit Widget to pick Español, Français, Italiano or English.",
                         done: false) { EmptyView() }
                }
                .padding(.horizontal, 18)

                TryItCard()
                    .padding(.horizontal, 18)

                Text("In any app: tap 🌐 on your keyboard to switch to Hablo, type in your language, tap **Insert**.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 30)
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .translationTask(config) { session in
            do { try await session.prepareTranslation() } catch {}
            await next()
        }
        .task { await refresh() }
        .onChange(of: phase) { _, p in if p == .active { Task { await refresh() } } }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 70)
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.white)
                    .frame(width: 92, height: 92)
                    .shadow(color: .black.opacity(0.15), radius: 14, y: 8)
                Image(systemName: "translate")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Theme.blue)
            }
            Text("Hablo")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                Text("🇺🇸 English")
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 13, weight: .bold))
                Text("Spanish 🇪🇸")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(.white.opacity(0.2)))
            Text("Translate as you type, in every app.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.gradient)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 36, bottomTrailingRadius: 36, style: .continuous))
    }

    private func step<A: View>(_ n: Int, _ title: String, _ detail: String, done: Bool,
                               @ViewBuilder accessory: () -> A) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(done ? Color.green : Theme.blueSoft).frame(width: 34, height: 34)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                } else {
                    Text("\(n)").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.blue)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .semibold))
                Text(detail).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            accessory()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.blue))
        }
        .buttonStyle(.plain)
    }

    private func download() {
        downloading = true
        pending = [.en, .es]
        Task { await next() }
    }

    @MainActor
    private func next() async {
        guard !pending.isEmpty else {
            await refresh()
            downloading = false
            return
        }
        let src = pending.removeFirst()
        config = .init(source: src.language, target: src.other.language)
    }

    @MainActor
    private func refresh() async {
        let a = await Translator.shared.isInstalled(.en)
        let b = await Translator.shared.isInstalled(.es)
        installed = a && b
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

private struct TryItCard: View {
    @State private var text = ""
    @State private var output = ""
    @State private var source: Lang = .en
    @State private var engine: Engine?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Try it").font(.system(size: 18, weight: .bold))
                Spacer()
                Button {
                    source = source.other
                    if !output.isEmpty { text = output }
                } label: {
                    HStack(spacing: 6) {
                        Text("\(source.flag) \(source.name)")
                        Image(systemName: "arrow.left.arrow.right").foregroundStyle(Theme.blue)
                        Text("\(source.other.name) \(source.other.flag)")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Theme.blueSoft))
                }
                .buttonStyle(.plain)
            }
            TextField("Type in \(source.name)…", text: $text, axis: .vertical)
                .font(.system(size: 18))
                .lineLimit(1...4)
            Divider()
            Text(output.isEmpty ? " " : output)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.blue)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let engine {
                Text(engine.rawValue).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
        .task(id: "\(source.rawValue)|\(text)") {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            if let r = try? await Translator.shared.translate(text, from: source) {
                output = r.0
                engine = text.isEmpty ? nil : r.1
            }
        }
    }
}
