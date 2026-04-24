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

Feature-first clean architecture: `presentation` → `domain` → `data`. Each layer only imports inward.

```
lib/
  app/            # Router, theme, MaterialApp shell
  core/           # Shared HTTP clients, typed exceptions, logger
  features/
    pokemon_search/
      data/
        models/       # PokemonSummary, PokemonDetail, MoveEntry (JSON DTOs)
        repositories/ # PokemonRepositoryImpl (HTTP calls, implements domain interface)
        providers/    # httpClientProvider, pokemonRepositoryProvider, use case providers
      domain/
        repositories/ # PokemonRepository (abstract interface)
        usecases/     # GetPokemonList, GetPokemonDetail
      presentation/
        providers/    # PokemonSearchController (StateNotifier), pokemonSearchControllerProvider
        screens/      # SearchScreen, DetailScreen
        widgets/      # PokemonListTile
    bookmarks/
      data/
        repositories/ # BookmarkRepositoryImpl (SharedPreferences)
      domain/
        repositories/ # BookmarkRepository (abstract interface)
        usecases/     # GetBookmarks, SetBookmarks
      presentation/
        providers/    # BookmarkNotifier, isBookmarkedProvider, bookmarkedNamesProvider
        screens/      # BookmarksScreen
    weather/
      data/
        models/       # WeatherData (Open-Meteo JSON DTO)
        repositories/ # WeatherRepositoryImpl (Open-Meteo + PokéAPI type endpoint)
      domain/
        repositories/ # WeatherRepository (abstract interface)
        usecases/     # GetCurrentWeather, GetPokemonByType
      presentation/
        providers/    # WeatherController (StateNotifier), WeatherState
        screens/      # WeatherPokemonScreen
```


**State management:** Riverpod `StateNotifier`. Each feature owns its provider file.

**APIs:** [PokéAPI v2](https://pokeapi.co) + [Open-Meteo](https://open-meteo.com) — both public, no auth.



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

**4. GPS auto-detect on weather screen**
User must type lat/lon manually. `geolocator` package would remove this friction entirely.

**5. Dev / prod environment separation**
API base URLs and log levels are hardcoded. Would add an `AppEnv` class reading `--dart-define` flags at compile time.

**6. Design system**
Spacing, font sizes, and border radius are magic numbers scattered across widgets. Would extract a token layer and add a proper dark theme.

**7. Accessibility**
No `Semantics` labels on sprites, stat bars, or type chips. Screen readers get meaningless defaults. (Matters for public apps)





---

## Known Limitations

- **Fix the N+1 problem properly**
The list endpoint doesn't return sprites or types, so each page fires N concurrent detail calls. Short-term: in-memory cache so re-scrolling pages is free. Long-term: a backend proxy or GraphQL layer that returns everything in one call.
- **Search is client-side.** PokéAPI has no search endpoint. Late-dex Pokémon may need many auto-fetched pages to appear.
- **Weather needs manual coordinates.** No GPS integration — user types lat/lon or taps Randomise.
- **Weather empty list.** If no Pokémon exist for the suggested type, the list shows empty with no explanation.
- **No offline detection mid-session.** If the device loses connectivity after the app loads, the last fetched data stays visible silently — no "you're offline" banner or error. Only the next user-triggered action (scroll, search, retry) surfaces the network error.
