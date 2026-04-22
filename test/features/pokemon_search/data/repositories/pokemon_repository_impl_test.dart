/// Unit tests for [PokemonRepositoryImpl].
/// Uses a hand-written fake datasource — no external mocking packages needed.
import 'package:flutter_test/flutter_test.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/datasources/pokemon_remote_datasource.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_detail_model.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_list_item_model.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/repositories/pokemon_repository_impl.dart';
import 'package:pok_dex_field_assistant/core/network/http_client.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Fake HTTP client — returns an error for any real request so no test
// accidentally hits the network.
// ---------------------------------------------------------------------------

/// Fake [http.Client] that always throws if called.
/// Used to construct [PokeApiHttpClient] without real network access.
class _ThrowingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnsupportedError('Tests must not make real HTTP calls');
  }
}

// ---------------------------------------------------------------------------
// Fake datasource — returns predetermined data without any HTTP calls.
// ---------------------------------------------------------------------------

/// Stub datasource that returns a fixed list of two Pokémon.
class _FakeDatasource extends PokemonRemoteDatasource {
  /// Track how many times [fetchEnrichedList] was called to test caching.
  int fetchEnrichedListCallCount = 0;

  /// Construct with a throwing HTTP client; methods are overridden so the
  /// client is never actually called.
  _FakeDatasource()
      : super(PokeApiHttpClient(_ThrowingHttpClient()));

  @override
  Future<List<PokemonListItemModel>> fetchEnrichedList(int limit) async {
    fetchEnrichedListCallCount++;
    /// Return two predictable items for filtering tests.
    return [
      const PokemonListItemModel(
        id: 1,
        name: 'bulbasaur',
        spriteUrl: 'https://example.com/1.png',
        primaryType: 'grass',
      ),
      const PokemonListItemModel(
        id: 4,
        name: 'charmander',
        spriteUrl: 'https://example.com/4.png',
        primaryType: 'fire',
      ),
    ];
  }

  @override
  Future<PokemonDetailModel> fetchPokemonDetail(String nameOrId) async {
    /// Minimal detail model returned for any [nameOrId] in these tests.
    return const PokemonDetailModel(
      id: 1,
      name: 'bulbasaur',
      spriteUrl: 'https://example.com/1.png',
      types: ['grass', 'poison'],
      height: 7,
      weight: 69,
      abilities: ['overgrow', 'chlorophyll'],
      stats: {'hp': 45, 'attack': 49},
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeDatasource fakeDatasource;
  late PokemonRepositoryImpl repository;

  /// Reset fake and repository before each test for isolation.
  setUp(() {
    fakeDatasource = _FakeDatasource();
    repository = PokemonRepositoryImpl(fakeDatasource);
  });

  group('PokemonRepositoryImpl.getPokemonList', () {
    /// Should return all items from the datasource.
    test('returns all items from datasource', () async {
      final list = await repository.getPokemonList();

      expect(list.length, 2);
      expect(list[0].name, 'bulbasaur');
      expect(list[1].name, 'charmander');
    });

    /// Second call should use the cache, not call the datasource again.
    test('caches results — datasource called only once on repeated calls',
        () async {
      await repository.getPokemonList();
      await repository.getPokemonList();

      expect(fakeDatasource.fetchEnrichedListCallCount, 1);
    });
  });

  group('PokemonRepositoryImpl.searchPokemon', () {
    /// Empty query returns everything.
    test('returns all items when query is empty', () async {
      final results = await repository.searchPokemon('');

      expect(results.length, 2);
    });

    /// Partial match should return matching Pokémon.
    test('filters by substring match (case-insensitive)', () async {
      final results = await repository.searchPokemon('char');

      expect(results.length, 1);
      expect(results.first.name, 'charmander');
    });

    /// Uppercase query should still match because comparison is lowercased.
    test('match is case-insensitive', () async {
      final results = await repository.searchPokemon('BULB');

      expect(results.length, 1);
      expect(results.first.name, 'bulbasaur');
    });

    /// No match should return empty list.
    test('returns empty list when no Pokémon match', () async {
      final results = await repository.searchPokemon('zzz');

      expect(results, isEmpty);
    });

    /// Search should populate cache; datasource called only once across search calls.
    test('populates cache on first call', () async {
      await repository.searchPokemon('char');
      await repository.searchPokemon('bulb');

      expect(fakeDatasource.fetchEnrichedListCallCount, 1);
    });
  });

  group('PokemonRepositoryImpl.getPokemonDetail', () {
    /// Should return a domain entity with fields from the datasource model.
    test('returns mapped PokemonDetail entity', () async {
      final detail = await repository.getPokemonDetail('bulbasaur');

      expect(detail.id, 1);
      expect(detail.name, 'bulbasaur');
      expect(detail.types, ['grass', 'poison']);
      expect(detail.stats['hp'], 45);
    });
  });
}
