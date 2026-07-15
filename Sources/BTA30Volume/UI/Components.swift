import SwiftUI

/// A titled card in the settings screen.
struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// "Short title + thin subtitle" row with the switch pinned to the right.
struct ToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }
}

/// Secondary-colored, wrapping helper text.
struct Caption: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension BTA30Manager {
    /// A two-way binding that reads a published property and writes through its
    /// matching setter (which clamps, guards `isConnected` and pushes the GAIA
    /// write). Turns `Binding(get: { bta.x }, set: { bta.setX($0) })` into
    /// `bta.binding(\.x, bta.setX)`.
    func binding<Value>(
        _ keyPath: KeyPath<BTA30Manager, Value>,
        _ setter: @escaping (Value) -> Void
    ) -> Binding<Value> {
        Binding(get: { self[keyPath: keyPath] }, set: setter)
    }
}

extension View {
    /// Soft rounded card background.
    func card() -> some View {
        padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
}
