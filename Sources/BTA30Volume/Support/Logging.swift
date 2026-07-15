import os.log

extension Logger {
    /// The app's shared logging subsystem. Callers only pick a category:
    /// `Logger(category: "device")`.
    private static let subsystem = "com.aliosmanozturk.bta30volume"

    init(category: String) {
        self.init(subsystem: Self.subsystem, category: category)
    }
}
