# BTA30 Volume

A macOS menu bar app that gives you real volume control over a **FiiO BTA30 Pro** while it runs as a USB DAC — volume keys, scroll-to-adjust, a native-feeling HUD, and full device settings, all from the menu bar.

*Türkçe okumak için: [README.tr.md](README.tr.md)*

<!-- TODO: add screenshots to docs/ and uncomment
<p align="center">
  <img src="docs/screenshot-main.png" width="360" alt="Main popover">
  <img src="docs/screenshot-settings.png" width="360" alt="Settings">
  <img src="docs/screenshot-hud.png" width="360" alt="Volume HUD">
</p>
-->

## Why does this exist?

In USB DAC mode the BTA30 Pro shows up on macOS as a USB Audio Class 2 device **without a volume feature unit or HID interface** — so the Mac's volume keys do nothing and the system slider is disabled. The device's real control channel is Bluetooth LE: the same GAIA protocol the FiiO Control mobile app uses, and per FiiO's own documentation it stays active in USB DAC mode.

This app bridges the two worlds: **audio keeps streaming over USB, control goes over BLE** from your Mac's own Bluetooth. No drivers, no kernel extensions.

## Features

- Volume slider and live level indicator in the menu bar (0–60, the device's native scale)
- Scroll over the menu bar icon to adjust volume (optional, off by default —
  too easy to max the volume by accident)
- **Media keys support** — F10/F11/F12 control the BTA30, but only while FiiO is the active audio output; with any other output selected they control system volume as usual (requires Accessibility permission, step configurable ±1/±2/±3)
- **Editable global shortcuts** (default ⌥⌘↑ / ⌥⌘↓ / ⌥⌘0) — work in every app, no permission needed
- System-style volume HUD anchored below the menu bar icon
- **Presets** — save volume + filter + balance + LED + upsampling combos, apply with one click, from the right-click menu, or via URL
- Device settings: DAC low-pass filter, channel balance (L12–R12), 384 kHz upsampling, LEDs on/off, auto power-on, remote power-off
- **Volume limit** — a hard ceiling no source can exceed (including the device's own remote)
- Live sync: changes made with the IR remote show up instantly
- Current USB audio format display (sample rate / bit depth) and firmware version
- Launch at login, auto-reconnect, right-click quick menu
- URL scheme for automation (see below)
- Localized: English, Turkish (contributions welcome — it's a single [string catalog](Sources/BTA30Volume/Resources/Localizable.xcstrings))

## Compatibility

Tested on a **BTA30 Pro**. The non-Pro **BTA30** uses the same Qualcomm CSR8675 chip and the same GAIA protocol (the protocol documentation this app is built on was actually written for the non-Pro model), so it will most likely work — but it hasn't been tested. If you try it, please [open an issue](../../issues) and share the result either way.

## Privacy

This app **never touches the network**. It talks Bluetooth LE to your BTA30 and nothing else — no analytics, no telemetry, no update checks. Nothing leaves your machine.

## Install

Requirements: macOS 13+, Xcode, [Tuist](https://tuist.dev) (`brew install tuist`).

```bash
./build.sh
open "dist/BTA30 Volume.app"   # or copy it to /Applications
```

For development, `tuist generate` creates and opens the Xcode workspace.

On first launch macOS asks for **Bluetooth** permission — required. If you enable media keys, it will also guide you to grant **Accessibility** permission (keys activate automatically the moment you grant it).

> **Code signing note:** `build.sh` signs with your Apple Development certificate if one exists in the keychain, which keeps TCC permissions stable across rebuilds. Without one it falls back to ad-hoc signing — then every rebuild counts as a new app and permissions must be re-granted (`tccutil reset Accessibility com.aliosmanozturk.bta30volume` helps).

## URL scheme (automation)

Works with Shortcuts, Raycast, Alfred, cron, or plain `open`:

```bash
open "bta30://volume/25"      # set volume (0-60)
open "bta30://volume/up"      # volume up (by key step)
open "bta30://volume/down"    # volume down
open "bta30://mute"           # toggle mute
open "bta30://balance/-3"     # balance: L3 (-12 … 12)
open "bta30://filter/2"       # DAC filter (0-3)
open "bta30://led/off"        # LEDs (on/off)
open "bta30://upsampling/on"  # upsampling (on/off)
open "bta30://power/off"      # power off the device
open "bta30://preset/night"   # apply a saved preset by name
```

## Notes

- The device accepts a single BLE connection: while the FiiO Control phone app is connected, this app can't connect (and vice versa).
- Per FiiO's FAQ, app control only works in RX and DAC modes — not in TX mode.
- Volume control in DAC mode requires the device's volume mode to be "Adjustable" (the factory default).

## Protocol

The BTA30 uses the Qualcomm GAIA service (`00001100-d102-11e1-9b23-00025b00a5a5`) on its CSR8675:

| Characteristic | Role |
|---|---|
| `...1101...` | Command endpoint (write) |
| `...1102...` | Response endpoint (subscribe for notifications) |

Frame format: `00 0a 0X XX [payload]` (request), `00 0a 8X XX 00 [payload]` (response).
Volume: GET `0x412`, SET `0x402`, 1-byte payload (0–60). The device also pushes unsolicited volume notifications when it changes locally, which is how the app stays in sync with the remote.

Two quirks worth knowing:
- The device does **not** advertise the GAIA service UUID, so discovery scans all peripherals and matches by name.
- On the BTA30 Pro the LED flag (`0x43D`/`0x43E`) is inverted relative to the protocol docs: `0x01` means LEDs **on** (verified on hardware). If you have a non-Pro BTA30 and the LED toggle behaves backwards, please open an issue.

## Credits

- BLE protocol reverse engineering: [Hypfer/fiio-bta30-protocol](https://github.com/Hypfer/fiio-bta30-protocol) — this project verified it byte-for-byte on the BTA30 Pro.

## License

[MIT](LICENSE)
