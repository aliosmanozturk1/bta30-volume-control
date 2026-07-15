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

    init(model: AppModel, onBack: @escaping () -> Void) {
        self.model = model
        self.bta = model.bta
        self.audio = model.audio
        self.keyboard = model.keyboard
        self.presetStore = model.presetStore
        self.loginItem = model.loginItem
        self.onBack = onBack
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
}
