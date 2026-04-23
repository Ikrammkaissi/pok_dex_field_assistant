# Pokédex Field Assistant

Flutter app — search Pokémon, view stats, bookmark favourites, get weather-based suggestions.

> Claude Code was used to accelerate development. Architecture and decisions reviewed manually.

---

## Setup

**Prerequisites:** Flutter ≥ 3.11, Dart ≥ 3.11. No API keys required.

```bash
git clone https://github.com/Ikrammkaissi/pok_dex_field_assistant.git
cd pok_dex_field_assistant
flutter pub get
```

iOS only:
```bash
cd ios && pod install && cd ..
```

**Run:**
```bash
flutter run                    # default device
flutter run -d chrome          # web
flutter run -d android         # Android
flutter run -d ios             # iOS
flutter devices                # list available targets
```

**Test:**
```bash
flutter test                   # all tests
flutter test --coverage        # with coverage
flutter analyze                # lint
```

---

## Architecture

Feature-first, three layers per feature: `data` → `presentation`. No separate domain layer — models are simple enough to share.

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

**State management:** Riverpod `StateNotifier`. Each feature owns its provider file. 

**APIs:** [PokéAPI v2](https://pokeapi.co) + [Open-Meteo](https://open-meteo.com) — both public, no auth.

---

## Tests

Models, repositories, and controllers are unit tested with hand-written fakes (no real HTTP calls). Widget tests cover `SearchScreen`, `WeatherPokemonScreen`, and `DetailScreen`.

```bash
flutter test test/features/pokemon_search/
flutter test test/features/weather/
```


---

## What I'd Improve With More Time


**1. Migrate `StateNotifier` → `Notifier` / `AsyncNotifier`**
Riverpod 2.x deprecated `StateNotifier`. All three controllers need migration before the next major version breaks the upgrade path.

**2. Add image caching with a size cap**
No `cached_network_image` — sprites re-fetch on rebuild. Would add it with a `CacheManager` max-size policy to prevent unbounded disk growth.

**3. Offline mode**
Browsing requires network. Would persist fetched Pokémon to Hive/SQLite with a background staleness refresh.

**6. GPS auto-detect on weather screen**
User must type lat/lon manually. `geolocator` package would remove this friction entirely.

**7. Dev / prod environment separation**
API base URLs and log levels are hardcoded. Would add an `AppEnv` class reading `--dart-define` flags at compile time.

**8. Design system**
Spacing, font sizes, and border radius are magic numbers scattered across widgets. Would extract a token layer and add a proper dark theme.

**9. Accessibility**
No `Semantics` labels on sprites, stat bars, or type chips. Screen readers get meaningless defaults. (Matters for public apps)

**10. Sliding window was considered and removed**
An earlier version capped the list at 180 items, evicting pages as the user scrolled. It was removed because ~1000 `PokemonSummary` objects total ≈ 100 KB — the memory problem didn't exist at this scale. The current append-only list is simpler and equally performant. A window would be justified if storing full `PokemonDetail` for all entries (~50 MB).

**11.Coverage gaps — tests not yet implemented**
- `BookmarkRepository` + `BookmarkNotifier` — toggle, persist, dedupe logic
- `DetailScreen` widget — loading/error/success states, shiny toggle, bookmark tap
- HTTP clients (`PokeApiHttpClient`, `WeatherHttpClient`) — 2xx, 4xx, socket error, malformed JSON

---

## Known Limitations

- **Fix the N+1 problem properly**
The list endpoint doesn't return sprites or types, so each page fires N concurrent detail calls. Short-term: in-memory cache so re-scrolling pages is free. Long-term: a backend proxy or GraphQL layer that returns everything in one call.
- **Search is client-side.** PokéAPI has no search endpoint. Late-dex Pokémon may need many auto-fetched pages to appear.
- **Weather needs manual coordinates.** No GPS integration — user types lat/lon or taps Randomise.
- **Weather empty list.** If no Pokémon exist for the suggested type, the list shows empty with no explanation.
- **No offline detection mid-session.** If the device loses connectivity after the app loads, the last fetched data stays visible silently — no "you're offline" banner or error. Only the next user-triggered action (scroll, search, retry) surfaces the network error.
