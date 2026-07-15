import SwiftUI

/// Main screen: status + large volume slider + preset chips + bottom bar.
struct MainView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var bta: BTA30Manager
    @ObservedObject var audio: AudioOutputWatcher
    let onSettings: () -> Void

    init(model: AppModel, onSettings: @escaping () -> Void) {
        self.model = model
        self.bta = model.bta
        self.audio = model.audio
        self.onSettings = onSettings
    }

    private var statusColor: Color {
        switch bta.state {
        case .connected: return .green
        case .connecting, .scanning: return .orange
        case .bluetoothOff, .unauthorized: return .red
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if !audio.fiioFormat.isEmpty { parts.append(audio.fiioFormat) }
        if !bta.firmwareVersion.isEmpty { parts.append(bta.firmwareVersion) }
        return parts.joined(separator: " · ")
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { Double(bta.volume) },
            set: { bta.setVolume(Int($0.rounded())) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if bta.isConnected {
                header
                volumeCard
            } else {
                emptyState
            }
            bottomBar
        }
        .padding(14)
    }


    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(bta.deviceName)
                    .font(.headline)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 2)
    }

    private var volumeCard: some View {
        HStack(spacing: 12) {
            Button {
                model.userToggleMute()
            } label: {
                Image(systemName: StatusItemIcon.symbol(for: bta.volume))
                    .font(.title2)
                    .frame(width: 26)
            }
            .buttonStyle(.borderless)
            .help(L("Mute / unmute"))

            Slider(value: volumeBinding, in: 0...Double(bta.volumeLimit), step: 1)
                .controlSize(.large)

            Text("\(bta.volume)")
                .font(.system(.title, design: .monospaced).weight(.medium))
                .frame(width: 48, alignment: .trailing)
        }
        .card()
    }


    private var emptyState: some View {
        VStack(spacing: 10) {
            switch bta.state {
            case .scanning, .connecting:
                ProgressView()
                    .controlSize(.small)
                Text(bta.state == .scanning ? L("Looking for FiiO BTA30 Pro…") : L("Connecting…"))
                    .font(.headline)
                Text(L("Make sure the device is powered on and the FiiO Control app on your phone is not connected."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            case .bluetoothOff:
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(L("Bluetooth is off"))
                    .font(.headline)
                Text(L("Turn on Bluetooth from Control Center."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .unauthorized:
                Image(systemName: "lock.shield")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(L("Bluetooth permission required"))
                    .font(.headline)
                Text(L("Grant access in System Settings → Privacy & Security → Bluetooth."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            case .connected:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .card()
    }

    private var bottomBar: some View {
        HStack(spacing: 14) {
            Button {
                onSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help(L("Settings"))

            Spacer()

            Button(L("Quit")) {
                NSApp.terminate(nil)
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 2)
    }
}
