# Pokédex Field Assistant

A Flutter app for searching Pokémon, viewing detailed stats, bookmarking favourites, and getting weather-based Pokémon suggestions.

---

## Setup & Run

### Prerequisites

| Tool | Version |
|------|---------|
| Flutter SDK | ≥ 3.11.0 |
| Dart SDK | ≥ 3.11.0 (bundled with Flutter) |
| Xcode (iOS) | ≥ 15 |
| Android Studio / SDK | API 21+ |

### Install and run

```bash
git clone <repo-url>
cd pok_dex_field_assistant
flutter pub get
flutter run
```

No API keys required. The app uses [PokéAPI](https://pokeapi.co) (public, no auth) and [Open-Meteo](https://open-meteo.com) (public, no auth).

### Run tests

```bash
flutter test
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

`StateNotifier` is used for mutable controller state. Riverpod 3.x deprecates `StateNotifier` in favour of `Notifier`/`AsyncNotifier` — migration is pending (see Known Issues).

---

## Tests

```
test/
  features/
    pokemon_search/
      data/models/          # PokemonSummary.fromJson, PokemonDetail.fromJson, MoveEntry.fromJson
      data/repositories/    # getPokemonList, getPokemonDetail — fake HTTP client
      presentation/providers/ # init, loadMore, loadPrevious, search, retry, all error paths
    weather/
      data/models/          # fromJson, conditionLabel, suggestedPokemonType, conditionIcon
      data/repositories/    # getCurrentWeather, getPokemonByType (success + error paths)
      presentation/providers/ # fetch, loadMore, coordinate validation, error handling
      presentation/screens/ # loading, success, error, coord fields, shuffle — widget tests
  widget_test.dart          # App smoke test: AppBar, list, search bar render
```

Repositories are tested with a `FakeHttpClient` that returns fixture JSON — no real HTTP calls. Controllers are tested by overriding providers in a `ProviderContainer` and asserting state transitions.

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

---

## Known Issues & Unsupported Edge Cases

**`StateNotifier` deprecation warnings.** `flutter analyze` surfaces deprecation warnings for all three `StateNotifier` subclasses. They are functional but will block a future Riverpod major upgrade.

**Weather screen requires manual coordinates.** There is no GPS/location-services integration. The user must type latitude and longitude manually, or tap "Randomise" for a random location.

**Forms without a Pokémon of that type.** If Open-Meteo returns a weather condition that maps to a type with zero Pokémon in the API (e.g. very rare types), the weather screen shows an empty list with no explanation.

**Audio cries.** Pokémon cry playback uses OGG URLs from PokéAPI. Some older Pokémon (Gen I–V) have cries; many Gen VI+ entries have no cry URL and the card silently hides those buttons. No fallback audio.

**Pokémon with no front-default sprite.** Sprite URL is derived from the list entry ID. A small number of alternate forms return a broken image — the error widget (pokéball icon) handles this gracefully but without explanation.

**Sliding window and bookmarks.** Bookmarks store the full `PokemonSummary` snapshot at toggle time. If the window slides and the bookmarked item scrolls out of the raw window, the bookmark remains valid (it stores the data, not a reference). But searching for a bookmarked Pokémon while the window does not contain it may show no results until more pages are fetched.

**No tablet / large-screen layout.** All screens are designed for phone portrait. Landscape and tablet layouts are unsupported — the list and detail screens will stretch but are not adapted.
