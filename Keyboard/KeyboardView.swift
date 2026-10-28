import SwiftUI

struct KeyboardView: View {
    @ObservedObject var model: KeyboardModel
    @Environment(\.colorScheme) private var scheme

    static let barHeight: CGFloat = 46
    static let composeHeight: CGFloat = 74
    static let rowHeight: CGFloat = 54

    static func height(translateOn: Bool) -> CGFloat {
        barHeight + rowHeight * 4 + 8 + (translateOn ? composeHeight : 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .frame(height: Self.barHeight)
            if model.translateOn {
                compose
                    .frame(height: Self.composeHeight)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            keys
                .padding(.bottom, 4)
        }
        .padding(.top, 4)
        .animation(.snappy(duration: 0.22), value: model.translateOn)
    }

    // MARK: toolbar

    private var toolbar: some View {
        HStack(spacing: 6) {
            chip { model.clear() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
            }
            chip(active: model.translateOn) {
                model.translateOn.toggle()
                if !model.translateOn { model.clear() }
            } label: {
                Image(systemName: "translate").font(.system(size: 16, weight: .semibold))
            }
            Button { model.swap() } label: {
                HStack(spacing: 6) {
                    Text(model.source.name)
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.blue)
                    Text(model.target.name)
                }
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Capsule().fill(chipFill))
            }
            .buttonStyle(.plain)
            chip { model.translateField() } label: {
                Image(systemName: "text.badge.checkmark").font(.system(size: 15, weight: .semibold))
            }
            Spacer(minLength: 0)
            if let e = model.engine {
                Text(e.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            chip { model.dismiss() } label: {
                Image(systemName: "keyboard.chevron.compact.down").font(.system(size: 14, weight: .semibold))
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
    }

    private func chip<L: View>(active: Bool = false, action: @escaping () -> Void, @ViewBuilder label: () -> L) -> some View {
        Button(action: action) {
            label()
                .frame(width: 38, height: 34)
                .foregroundStyle(active ? Color.white : Color.primary)
                .background(Capsule().fill(active ? AnyShapeStyle(Theme.blue) : AnyShapeStyle(chipFill)))
        }
        .buttonStyle(.plain)
    }

    private var chipFill: Color {
        scheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.85)
    }

    // MARK: compose card

    private var compose: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(model.source.flag).font(.system(size: 14))
                    Text(model.buffer.isEmpty ? "Type in \(model.source.name)…" : model.buffer)
                        .foregroundStyle(model.buffer.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                .font(.system(size: 16, weight: .medium))
                HStack(spacing: 6) {
                    Text(model.target.flag).font(.system(size: 14))
                    Group {
                        if let p = model.problem {
                            Text(p).foregroundStyle(.orange).font(.system(size: 13, weight: .medium))
                        } else if !model.modelsReady && !model.hasFullAccess {
                            Text("Open Hablo to download \(model.target.name)")
                                .foregroundStyle(.orange).font(.system(size: 13, weight: .medium))
                        } else if model.busy && model.output.isEmpty {
                            Text("Translating…").foregroundStyle(.secondary)
                        } else {
                            Text(model.output.isEmpty ? model.target.name : model.output)
                                .foregroundStyle(model.output.isEmpty ? Color.secondary : Theme.blue)
                        }
                    }
                    .lineLimit(1)
                    .truncationMode(.head)
                }
                .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { model.send() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(model.buffer.isEmpty ? Color.gray.opacity(0.4) : Theme.blue))
            }
            .buttonStyle(.plain)
            .disabled(model.buffer.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(scheme == .dark ? Color.white.opacity(0.10) : Color.white)
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: keys

    private var rows: [[String]] {
        switch model.layer {
        case .letters:
            let mid = model.source == .es ? "asdfghjklñ" : "asdfghjkl"
            return ["qwertyuiop", mid, "zxcvbnm"].map { $0.map(String.init) }
        case .numbers:
            return [
                ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
                ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
                [".", ",", "?", "!", "¿", "¡", "'"],
            ]
        case .symbols:
            return [
                ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
                ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"],
                [".", ",", "?", "!", "á", "é", "í"],
            ]
        }
    }

    private var keys: some View {
        GeometryReader { geo in
            let gap: CGFloat = 6
            let unit = (geo.size.width - 6 - gap * 9) / 10
            VStack(spacing: 0) {
                row(rows[0], unit: unit, gap: gap)
                row(rows[1], unit: unit, gap: gap)
                HStack(spacing: gap) {
                    shiftKey(width: unit * 1.35)
                    Spacer(minLength: 0)
                    ForEach(rows[2], id: \.self) { k in letterKey(k, width: unit) }
                    Spacer(minLength: 0)
                    Key(width: unit * 1.35, style: .function, repeats: true, action: model.delete) {
                        Image(systemName: "delete.left").font(.system(size: 18, weight: .medium))
                    }
                }
                .padding(.horizontal, 3)
                .frame(height: Self.rowHeight)
                bottomRow(unit: unit, gap: gap)
            }
        }
        .frame(height: Self.rowHeight * 4)
    }

    private func row(_ items: [String], unit: CGFloat, gap: CGFloat) -> some View {
        HStack(spacing: gap) {
            ForEach(items, id: \.self) { k in letterKey(k, width: unit) }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.rowHeight)
    }

    private func letterKey(_ k: String, width: CGFloat) -> some View {
        let shown = model.layer == .letters && model.shift != .off ? k.uppercased() : k
        return Key(width: width, style: .letter, action: { model.type(k) }) {
            Text(shown).font(.system(size: 23, weight: .regular))
        }
    }

    @ViewBuilder
    private func shiftKey(width: CGFloat) -> some View {
        switch model.layer {
        case .letters:
            Key(width: width, style: model.shift == .off ? .function : .letter,
                action: model.toggleShift, doubleTap: model.capsLock) {
                Image(systemName: model.shift == .caps ? "capslock.fill" : (model.shift == .on ? "shift.fill" : "shift"))
                    .font(.system(size: 18, weight: .medium))
            }
        case .numbers:
            Key(width: width, style: .function, action: { model.layer = .symbols }) {
                Text("#+=").font(.system(size: 15, weight: .medium))
            }
        case .symbols:
            Key(width: width, style: .function, action: { model.layer = .numbers }) {
                Text("123").font(.system(size: 15, weight: .medium))
            }
        }
    }

    private func bottomRow(unit: CGFloat, gap: CGFloat) -> some View {
        HStack(spacing: gap) {
            Key(width: unit * 1.3, style: .function, action: {
                model.layer = model.layer == .letters ? .numbers : .letters
            }) {
                Text(model.layer == .letters ? "123" : "ABC").font(.system(size: 16, weight: .medium))
            }
            if model.needsGlobe {
                Key(width: unit * 1.1, style: .function, action: model.nextKeyboard) {
                    Image(systemName: "globe").font(.system(size: 18))
                }
            }
            Key(width: nil, style: .letter, action: model.space) {
                Text(model.translateOn ? "\(model.source.name) → \(model.target.name)" : "space")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Key(width: unit * 2.1, style: .accent, action: model.returnKey) {
                if model.translateOn && !model.buffer.isEmpty {
                    Text("Insert").font(.system(size: 16, weight: .semibold))
                } else {
                    Image(systemName: "return").font(.system(size: 18, weight: .semibold))
                }
            }
        }
        .padding(.horizontal, 3)
        .frame(height: Self.rowHeight)
    }
}

// MARK: - Key

struct Key<Label: View>: View {
    enum Style { case letter, function, accent }

    let width: CGFloat?
    let style: Style
    var repeats = false
    let action: () -> Void
    var doubleTap: (() -> Void)?
    @ViewBuilder let label: () -> Label

    @Environment(\.colorScheme) private var scheme
    @State private var pressed = false
    @State private var timer: Timer?
    @State private var lastTap = Date.distantPast

    init(width: CGFloat?, style: Style, repeats: Bool = false, action: @escaping () -> Void,
         doubleTap: (() -> Void)? = nil, @ViewBuilder label: @escaping () -> Label) {
        self.width = width
        self.style = style
        self.repeats = repeats
        self.action = action
        self.doubleTap = doubleTap
        self.label = label
    }

    var body: some View {
        label()
            .foregroundStyle(style == .accent ? Color.white : Color.primary)
            .frame(width: width, height: 44)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(fill)
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.18), radius: 0, y: 1)
            )
            .scaleEffect(pressed ? 0.94 : 1)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressed else { return }
                        pressed = true
                        fire()
                        if repeats { startRepeat() }
                    }
                    .onEnded { _ in
                        pressed = false
                        timer?.invalidate()
                        timer = nil
                    }
            )
            .animation(.easeOut(duration: 0.08), value: pressed)
    }

    private func fire() {
        if let doubleTap, Date().timeIntervalSince(lastTap) < 0.3 {
            doubleTap()
            lastTap = .distantPast
            return
        }
        lastTap = Date()
        action()
    }

    private func startRepeat() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { _ in
            Task { @MainActor in
                guard pressed else { return }
                timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                    Task { @MainActor in if pressed { action() } }
                }
            }
        }
    }

    private var fill: Color {
        switch style {
        case .accent: return Theme.blue
        case .letter: return scheme == .dark ? Color(white: 0.42) : .white
        case .function: return scheme == .dark ? Color(white: 0.27) : Color(red: 0.68, green: 0.70, blue: 0.74)
        }
    }
}
