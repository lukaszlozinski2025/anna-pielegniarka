import SwiftUI

/// Compact keyboard panel UI. Sized to fit a standard iOS keyboard height.
struct KeyboardView: View {
    @ObservedObject var model: KeyboardViewModel

    var body: some View {
        VStack(spacing: 8) {
            topBar

            ScrollView {
                VStack(spacing: 10) {
                    receiveSection
                    replySection
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }

            if let status = model.status {
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(Theme.danger)
                    .lineLimit(2)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
            }
        }
        .background(Theme.bg)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            if model.needsNextKeyboardButton {
                Button(action: model.advanceKeyboard) {
                    Image(systemName: "globe")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 34, height: 30)
                }
                .accessibilityLabel("Następna klawiatura")
            }
            Text("🌐 AI Translate")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.accent)
            Spacer()
            if model.busy { ProgressView().tint(Theme.accent) }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }

    // MARK: - Receive (their message -> Polish)

    private var receiveSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                actionButton("Wklej ze schowka", icon: "doc.on.clipboard", filled: true) {
                    model.pasteFromClipboard()
                }
            }
            HStack(spacing: 8) {
                actionButton("EN → PL") { model.translateIncoming(direction: .enToPl) }
                actionButton("PL → EN") { model.translateIncoming(direction: .plToEn) }
                actionButton("Auto") { model.translateIncoming(direction: .auto) }
            }

            textPreview(text: model.incoming, placeholder: "Wklejony tekst pojawi się tutaj")
            resultView(text: model.translated, placeholder: "Tłumaczenie wiadomości")
        }
        .padding(10)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Reply (your Polish -> English)

    private var replySection: some View {
        VStack(spacing: 8) {
            TextField("Wpisz odpowiedź po polsku…", text: $model.reply, axis: .vertical)
                .lineLimit(1...3)
                .font(.subheadline)
                .foregroundStyle(Theme.text)
                .padding(8)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 8) {
                actionButton("Przetłumacz odpowiedź", icon: "arrow.left.arrow.right") {
                    model.translateReply()
                }
            }

            resultView(text: model.translatedReply, placeholder: "Gotowa odpowiedź (angielski)")

            actionButton("Wstaw do WhatsApp", icon: "paperplane.fill", filled: true) {
                model.insertResult()
            }
        }
        .padding(10)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Reusable pieces

    private func actionButton(_ title: String, icon: String? = nil, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon) }
                Text(title).fontWeight(.semibold)
            }
            .font(.footnote)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(filled ? Theme.bg : Theme.accent)
            .background(filled ? Theme.accent : Theme.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func textPreview(text: String, placeholder: String) -> some View {
        Text(text.isEmpty ? placeholder : text)
            .font(.footnote)
            .foregroundStyle(text.isEmpty ? Theme.textDim : Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(3)
            .padding(8)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func resultView(text: String, placeholder: String) -> some View {
        Text(text.isEmpty ? placeholder : text)
            .font(.subheadline.weight(text.isEmpty ? .regular : .semibold))
            .foregroundStyle(text.isEmpty ? Theme.textDim : Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(4)
            .textSelection(.enabled)
            .padding(8)
            .background(text.isEmpty ? Theme.card : Theme.accent.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
