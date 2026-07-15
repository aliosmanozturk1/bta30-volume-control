import SwiftUI

/// Settings screen: keyboard, device, preset and app settings cards.
struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var bta: BTA30Manager
    @ObservedObject var audio: AudioOutputWatcher
    @ObservedObject var keyboard: KeyboardCoordinator
    @ObservedObject var presetStore: PresetStore
    @ObservedObject var loginItem: LoginItemManager
    let onBack: () -> Void
    @State private var newPresetName = ""

    init(model: AppModel, onBack: @escaping () -> Void) {
        self.model = model
        self.bta = model.bta
        self.audio = model.audio
        self.keyboard = model.keyboard
        self.presetStore = model.presetStore
        self.loginItem = model.loginItem
        self.onBack = onBack
    }

    private var balanceBinding: Binding<Double> {
        Binding(
            get: { Double(bta.balance) },
            set: { bta.setBalance(Int($0.rounded())) }
        )
    }

    private var balanceLabel: String {
        if bta.balance == 0 { return L("Center") }
        return bta.balance < 0 ? "L\(-bta.balance)" : "R\(bta.balance)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Button {
                    keyboard.endRecording()
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                Text(L("Settings"))
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 2)

            SectionCard(title: L("KEYBOARD")) { keyboardSettings }
            SectionCard(title: L("DEVICE")) { deviceSettings }
            SectionCard(title: L("PRESETS")) { presetSettings }
            SectionCard(title: L("APP")) { appSettings }
        }
        .padding(14)
    }

    @ViewBuilder private var keyboardSettings: some View {
        ToggleRow(
            title: L("Media keys"),
            subtitle: L("Volume keys control the device while FiiO is the active output"),
            isOn: $keyboard.mediaKeysEnabled
        )

        if keyboard.mediaKeysEnabled {
            HStack {
                Text(L("Key step"))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $keyboard.keyStep) {
                    Text("±1").tag(1)
                    Text("±2").tag(2)
                    Text("±3").tag(3)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 130)
            }
            .controlSize(.small)
        }

        if let hint = keyboard.permissionHint {
            Caption(hint)
        } else if keyboard.mediaKeysEnabled && !audio.isFiiODefaultOutput {
            Caption(L("Active output: \(audio.currentOutputName.isEmpty ? L("another device") : audio.currentOutputName) — keys currently control system volume."))
        }

        ToggleRow(
            title: L("Global shortcuts"),
            subtitle: L("Work in every app, no permission needed"),
            isOn: $keyboard.hotKeysEnabled
        )

        if keyboard.hotKeysEnabled {
            ForEach(HotKeyAction.allCases, id: \.self) { action in
                HStack {
                    Text(action.title)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        if keyboard.recordingAction == action {
                            keyboard.endRecording()
                        } else {
                            keyboard.beginRecording(action)
                        }
                    } label: {
                        Text(keyboard.recordingAction == action
                             ? L("Press keys… ⎋")
                             : (keyboard.hotKeyBindings[action]?.displayString ?? "—"))
                            .font(.system(.caption, design: .monospaced))
                            .frame(minWidth: 76)
                    }
                }
                .controlSize(.small)
            }
            if let hint = keyboard.hotKeyHint {
                Caption(hint)
            }
            Button(L("Restore defaults")) {
                keyboard.resetHotKeys()
            }
            .buttonStyle(.link)
            .font(.caption)
        }
    }

    @ViewBuilder private var deviceSettings: some View {
        HStack {
            Text(L("DAC filter"))
            Spacer()
            Picker("", selection: bta.binding(\.filter, bta.setFilter)) {
                Text(verbatim: "Sharp Roll-Off").tag(0)
                Text(verbatim: "Slow Roll-Off").tag(1)
                Text(verbatim: "Short Delay Sharp").tag(2)
                Text(verbatim: "Short Delay Slow").tag(3)
            }
            .labelsHidden()
            .frame(width: 164)
        }
        .disabled(!bta.isConnected)

        HStack(spacing: 10) {
            Text(L("Balance"))
            Slider(value: balanceBinding, in: -12...12, step: 1)
            Button(balanceLabel) {
                bta.setBalance(0)
            }
            .buttonStyle(.plain)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(width: 34, alignment: .trailing)
            .help(L("Reset to center"))
        }
        .disabled(!bta.isConnected)

        ToggleRow(
            title: L("Upsampling"),
            subtitle: L("Upsamples the signal to 384 kHz"),
            isOn: bta.binding(\.upsampling, bta.setUpsampling)
        )
        .disabled(!bta.isConnected)

        ToggleRow(
            title: L("Turn off LEDs"),
            subtitle: nil,
            isOn: bta.binding(\.ledOff, bta.setLedOff)
        )
        .disabled(!bta.isConnected)

        ToggleRow(
            title: L("Auto power-on"),
            subtitle: L("Device turns on when it receives power"),
            isOn: bta.binding(\.bootMode, bta.setBootMode)
        )
        .disabled(!bta.isConnected)

        Button {
            bta.powerOff()
        } label: {
            Label(L("Power off device"), systemImage: "power")
        }
        .controlSize(.small)
        .disabled(!bta.isConnected)
    }

    @ViewBuilder private var presetSettings: some View {
        if presetStore.presets.isEmpty {
            Caption(L("Save the current device settings (volume, filter, balance, LED, upsampling) under a name, then apply them with one click from the main screen."))
        }

        ForEach(presetStore.presets) { preset in
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up")
                    .foregroundStyle(.secondary)
                Text(preset.name)
                Spacer()
                Text("\(preset.volume)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Button {
                    presetStore.delete(preset)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help(L("Delete preset"))
            }
        }

        HStack {
            TextField(L("New preset name"), text: $newPresetName)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .onSubmit { savePreset() }
            Button(L("Save")) { savePreset() }
                .controlSize(.small)
                .disabled(!bta.isConnected || newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
                .help(L("Saves the current settings under this name"))
        }
    }

    private func savePreset() {
        model.saveCurrentAsPreset(named: newPresetName)
        newPresetName = ""
    }

    @ViewBuilder private var appSettings: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(L("Volume limit"))
                Text(L("No source can go above this level"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Stepper(value: $bta.volumeLimit, in: BTA30Manager.minVolumeLimit...BTA30Manager.maxVolume, step: 5) {
                Text("\(bta.volumeLimit)")
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 24, alignment: .trailing)
            }
            .controlSize(.small)
        }

        ToggleRow(
            title: L("Scroll to adjust volume"),
            subtitle: L("Turn the volume by scrolling over the menu bar icon"),
            isOn: $model.scrollAdjustsVolume
        )

        ToggleRow(
            title: L("Launch at login"),
            subtitle: L("Ready in the menu bar when your Mac starts"),
            isOn: $loginItem.isEnabled
        )

        if let hint = loginItem.hint {
            Caption(hint)
        }
    }
}
