# Pokédex Field Assistant

A Flutter app for searching Pokémon, viewing detailed stats, bookmarking favourites, and getting weather-based Pokémon suggestions.

---
## Notes
Claude Code was used to accelerate development, while ensuring code quality,
architecture, and decisions were reviewed and validated manually.

## Setup & Run

### Prerequisites

| Tool | Version | Required for |
|------|---------|-------------|
| Flutter SDK | ≥ 3.11.0 | All targets |
| Dart SDK | ≥ 3.11.0 | All targets (bundled with Flutter) |
| Xcode | ≥ 15 | iOS only |
| CocoaPods | latest | iOS only |
| Android Studio / SDK | API 21+ | Android only |
| Chrome | any | Web only |

No API keys required. Uses [PokéAPI](https://pokeapi.co) and [Open-Meteo](https://open-meteo.com) , both public, no auth.

### Initial setup

```bash
git clone <repo-url>
cd pok_dex_field_assistant
flutter pub get
```

### Web

**Debug** (Chrome, hot restart, DevTools available):

```bash
flutter run -d chrome
```

**Release** (minified, tree-shaken, production-ready):

```bash
flutter build web --release
# Output: build/web/

# Serve locally to verify the release build:
cd build/web && python3 -m http.server 8080
# Then open http://localhost:8080
```
iOS only : install CocoaPods dependencies after `pub get`:

```bash
cd ios && pod install && cd ..
```

---

### Web

**Debug** (Chrome, hot restart, DevTools available):

```bash
flutter run -d chrome
```

**Release** (minified, tree-shaken, production-ready):

```bash
flutter build web --release
# Output: build/web/

# Serve locally to verify the release build:
cd build/web && python3 -m http.server 8080
# Then open http://localhost:8080
```
> **Note:** Audio cries (`audioplayers`) require HTTPS in production web deployments due to browser autoplay policy. Local `python3 -m http.server` is HTTP , cries may not play.


### Android

**Debug** (hot reload, debug banner, verbose logging):

```bash
flutter run -d android
```

**Release** (minified, signed, no debug overlay):

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Universal APK (all ABIs in one file , larger, good for local testing):
flutter build apk --release

# Split by ABI (smaller per-device downloads , use for Play Store):
flutter build apk --release --split-per-abi
# Output: app-armeabi-v7a-release.apk, app-arm64-v8a-release.apk, app-x86_64-release.apk

# App Bundle for Play Store (recommended over APK for distribution):
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

> **Signing:** Release builds require a keystore. See [Android signing docs](https://docs.flutter.dev/deployment/android#signing-the-app). For local testing only, `--release` without signing will still build but cannot be installed on non-debug devices.

---

### iOS

**Debug** (requires connected device or simulator, Xcode installed):

```bash
# List available simulators/devices:
flutter devices

flutter run -d ios
```

**Release** (requires Apple Developer account for device install):

```bash
flutter build ios --release
# Output: build/ios/iphoneos/Runner.app

# For App Store distribution , open Xcode and archive:
open ios/Runner.xcworkspace
# Then: Product → Archive → Distribute App
```

> **Note:** `flutter build ios --release` does not produce a distributable `.ipa` directly. Use Xcode's Organizer or `xcodebuild` for App Store / TestFlight submission.

---



### Run on a specific device

```bash
# List all connected devices and emulators:
flutter devices

# Run on a specific device by ID:
flutter run -d <device-id>
```

---

### Run tests

**Recommended : PowerShell script** (generates timestamped reports):

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_tests.ps1
```

Produces three artifacts under `reports/tests/<timestamp>/`:

| File | Contents |
|------|----------|
| `flutter_test_machine.jsonl` | Machine-readable JSON Lines test results |
| `flutter_test_console.log` | Full console output |
| `lcov.info` | Coverage data (LCOV format) |
| `coverage_html/index.html` | HTML coverage report (requires `genhtml` on PATH) |

Skip HTML generation if `genhtml` is not installed:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_tests.ps1 -SkipHtmlCoverage
```

**Manual : single commands:**

```bash
# All tests:
flutter test

# Single file:
flutter test test/features/bookmarks/presentation/providers/bookmark_notifier_test.dart

# With LCOV coverage:
flutter test --coverage
# Then generate HTML (requires genhtml / lcov):
genhtml coverage/lcov.info -o coverage/html
```


### Lint

```bash
flutter analyze
```

---

## Architecture Overview

Three-layer architecture per feature: **data → domain (implicit in repository) → presentation**.

```
lib/
  app/            # Router, theme, MaterialApp shell
  core/           # Shared HTTP clients, typed exceptions, logger
  features/
    pokemon_search/
      data/       # PokemonRepository, models (PokemonSummary, PokemonDetail, MoveEntry)
      presentation/
        providers/  # Riverpod providers + PokemonSearchController (StateNotifier)
        screens/    # SearchScreen, DetailScreen
        widgets/    # PokemonListTile
    bookmarks/
      data/       # BookmarkRepository (SharedPreferences)
      presentation/
        providers/  # BookmarkNotifier, isBookmarkedProvider, bookmarkedNamesProvider
        screens/    # BookmarksScreen
    weather/
      data/       # WeatherRepository (Open-Meteo + PokéAPI type endpoint)
      presentation/
        providers/  # WeatherController (StateNotifier), WeatherState
        screens/    # WeatherPokemonScreen
```



## State Management

**Riverpod** (`flutter_riverpod ^2.6.1`).

Each feature has its own provider file. Cross-feature data flows only from data-layer providers (e.g. `bookmarkRepositoryProvider` is imported by the bookmark notifier, not the search screen).

`StateNotifier` is used for mutable controller state. Riverpod 3.x deprecates `StateNotifier` in favour of `Notifier`/`AsyncNotifier` , migration is pending .

---

## Tests

```
test/
  features/
    pokemon_search/
      data/models/          # PokemonSummary.fromJson, PokemonDetail.fromJson, MoveEntry.fromJson
      data/repositories/    # getPokemonList, getPokemonDetail , fake HTTP client
      presentation/providers/ # init, loadMore, loadPrevious, search, retry, all error paths
    weather/
      data/models/          # fromJson, conditionLabel, suggestedPokemonType, conditionIcon
      data/repositories/    # getCurrentWeather, getPokemonByType (success + error paths)
      presentation/providers/ # fetch, loadMore, coordinate validation, error handling
      presentation/screens/ # loading, success, error, coord fields, shuffle , widget tests
  widget_test.dart          # App smoke test: AppBar, list, search bar render
```

Repositories are tested with a `FakeHttpClient` that returns fixture JSON , no real HTTP calls. Controllers are tested by overriding providers in a `ProviderContainer` and asserting state transitions.

Coverage gaps: `WeatherHttpClient` unit tests and full `SearchScreen` widget tests are pending.

---

## Things I Would Improve With More Time

**1. Migrate `StateNotifier` → `Notifier` / `AsyncNotifier`**
Riverpod 2.x deprecated `StateNotifier`. All three controllers (`PokemonSearchController`, `BookmarkNotifier`, `WeatherController`) need migration before the next Riverpod major version blocks the upgrade path.

**2. Eliminate the remaining N+1**
`primaryType` requires a detail fetch per list item. The PokéAPI list endpoint doesn't return type data. Fix options: pre-fetch types in batch (speculative), or cache detail responses so revisiting a Pokémon is free.

**3. Persistent image cache size limit**
`cached_network_image` caches to disk without a configured size cap. On devices with limited storage and large Pokédex exploration sessions, the cache can grow unboundedly. Would add a `CacheManager` with a max-size policy.

**4. Offline mode**
Bookmarks persist locally but browsing requires a network connection. Would add a local SQLite or Hive store for previously fetched Pokémon, with a staleness policy so cached data refreshes in the background.

**5. Full widget test coverage for SearchScreen and DetailScreen**
`SearchScreen` has a smoke test but no coverage for pagination triggers, window-slide scroll-jump behaviour, or search debounce. `DetailScreen` tests cover happy-path render but not the moves table or shiny toggle.

**6. Accessibility**
No `Semantics` labels on sprite images, stat bars, or type chips. Screen readers get widget-tree defaults which are not meaningful for Pokémon data.

**7. Localisation**
All user-facing strings are hardcoded English. Would wire `flutter_localizations` + ARB files.

**8. Dev / prod environment separation**
No environment layer exists. API base URLs, log levels, and timeouts are hardcoded in source. Flutter's `--dart-define` mechanism requires no extra packages:

```bash
flutter run   --dart-define=ENV=dev  --dart-define=LOG_LEVEL=debug
flutter build --dart-define=ENV=prod --dart-define=LOG_LEVEL=warning --release
```

A single `AppEnv` class reads these at compile time, HTTP clients pull base URLs from it, and `AppLogger` respects the level. `.vscode/launch.json` launch configs let new devs pick an environment from a dropdown , no manual flags. Pointing `POKE_API_BASE` at a local mock server then enables fully offline development with zero source changes.

**9. Design system : theme, typography, and tokens**
The current theme is a single file ([`lib/app/theme.dart`](lib/app/theme.dart)) with one seed colour and no custom typography or spacing scale:

```dart
final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFCC0000)),
);
```

Everything else (font sizes, weights, paddings, border radii, icon sizes) is hardcoded inline at each call site , no shared constants, no token layer. Problems this causes:

- **No single source of truth.** Changing the base font size means hunting every `fontSize: 12` across every file.
- **No dark-mode colour overrides.** `ColorScheme.fromSeed` auto-generates a light scheme only. A dark scheme needs a second `ColorScheme.fromSeed(..., brightness: Brightness.dark)` and a `ThemeData.dark()` counterpart wired into `MaterialApp.darkTheme`.
- **No custom `TextTheme`.** All typography falls back to Material 3 defaults. A Pokédex benefits from a distinct type scale: a condensed display font for dex numbers, a bold title font for Pokémon names, and a compact body font for stat values.
- **Magic numbers everywhere.** Padding values like `EdgeInsets.all(16)`, `EdgeInsets.symmetric(horizontal: 12, vertical: 4)`, border radius like `BorderRadius.circular(12)` are repeated at dozens of call sites with no semantic name.

This gives one place to change any visual property, makes dark mode trivial to add, and removes all magic numbers from widget code.

---

## Known Issues & Unsupported Edge Cases

**Search is client-side only — no API search endpoint.** PokéAPI has no search or filter endpoint. Searching fetches pages from offset 0 and filters results in memory. Rare or late-dex Pokémon (e.g. "Eternatus") may require many auto-fetched pages before appearing, or return no results if the sliding window is exhausted before their name is reached. Clearing the search resets to browse mode from scratch.

**Weather screen requires manual coordinates.** There is no GPS/location-services integration. The user must type latitude and longitude manually, or tap "Randomise" for a random location.

**Forms without a Pokémon of that type.** If Open-Meteo returns a weather condition that maps to a type with zero Pokémon in the API , the weather screen shows an empty list with no explanation.

