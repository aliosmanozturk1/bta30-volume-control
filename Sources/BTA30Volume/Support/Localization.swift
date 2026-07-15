import Foundation

/// Returns localized text from the module's string catalog.
/// The source language is English; translations live in
/// Resources/Localizable.xcstrings.
func L(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}
