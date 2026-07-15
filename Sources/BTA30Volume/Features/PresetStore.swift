import Foundation

/// A named snapshot of device settings.
struct Preset: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var volume: Int
    var filter: Int
    var ledOff: Bool
    var balance: Int
    var upsampling: Bool
}

/// Stores and queries presets. Applying a preset to the device is AppModel's job.
final class PresetStore: ObservableObject {
    @Published private(set) var presets: [Preset] {
        didSet {
            if let data = try? JSONEncoder().encode(presets) {
                defaults.set(data, forKey: Preferences.presets)
            }
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Preferences.presets),
           let saved = try? JSONDecoder().decode([Preset].self, from: data) {
            presets = saved
        } else {
            presets = []
        }
    }

    /// Name comparison used consistently for deduplication and lookup, so a
    /// URL like `bta30://preset/cafe` can never resolve to a preset that
    /// `saveOrUpdate` would have treated as a different name.
    private static let nameOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// Overwrites the preset with the same name, otherwise appends.
    func saveOrUpdate(_ preset: Preset) {
        if let index = presets.firstIndex(where: {
            $0.name.compare(preset.name, options: Self.nameOptions) == .orderedSame
        }) {
            var updated = preset
            updated.id = presets[index].id
            presets[index] = updated
        } else {
            presets.append(preset)
        }
    }

    func delete(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
    }

    func find(named name: String) -> Preset? {
        presets.first {
            $0.name.compare(name, options: Self.nameOptions) == .orderedSame
        }
    }

    func find(id: String) -> Preset? {
        presets.first { $0.id.uuidString == id }
    }
}
