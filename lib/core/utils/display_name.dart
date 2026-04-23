/// Converts a hyphenated PokéAPI identifier to title-cased display text.
///
/// Examples:
/// - `mr-mime` -> `Mr Mime`
/// - `special-attack` -> `Special Attack`
String toDisplayName(String hyphenated) => hyphenated
    .split('-')
    .map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');
