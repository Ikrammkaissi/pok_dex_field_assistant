/// Unit tests for [PokemonRepositoryImpl].
/// Uses a hand-written fake [http.Client] — no external mocking packages needed.
/// Tests state transitions in isolation; no real HTTP calls are made.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pok_dex_field_assistant/core/network/http_client.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/pokemon_repository.dart';

// ---------------------------------------------------------------------------
// Static JSON fixtures
// ---------------------------------------------------------------------------

/// Minimal detail JSON for Bulbasaur — used for both list enrichment and detail fetch.
const _bulbasaurJson = <String, dynamic>{
  'id': 1,
  'name': 'bulbasaur',
  'height': 7,
  'weight': 69,
  'sprites': {'front_default': 'https://example.com/1.png'},
  'types': [
    {'type': {'name': 'grass'}},
    {'type': {'name': 'poison'}},
  ],
  'abilities': [
    {'ability': {'name': 'overgrow'}},
    {'ability': {'name': 'chlorophyll'}},
  ],
  'stats': [
    {'stat': {'name': 'hp'}, 'base_stat': 45},
    {'stat': {'name': 'attack'}, 'base_stat': 49},
  ],
};

/// Minimal detail JSON for Charmander.
const _charmanderJson = <String, dynamic>{
  'id': 4,
  'name': 'charmander',
  'height': 6,
  'weight': 85,
  'sprites': {'front_default': 'https://example.com/4.png'},
  'types': [
    {'type': {'name': 'fire'}},
  ],
  'abilities': [
    {'ability': {'name': 'blaze'}},
  ],
  'stats': [
    {'stat': {'name': 'hp'}, 'base_stat': 39},
  ],
};

/// List-endpoint response returning two Pokémon names.
const _listJson = <String, dynamic>{
  'results': [
    {'name': 'bulbasaur', 'url': ''},
    {'name': 'charmander', 'url': ''},
  ],
};

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

/// Fake [http.BaseClient] that returns pre-baked JSON without network access.
/// Routes requests by URL substring to the appropriate fixture.
class _FakeHttpClient extends http.BaseClient {
  /// Number of times [send] has been called — used to verify caching.
  int sendCallCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    /// Increment call count so tests can verify caching behaviour.
    sendCallCount++;
    final url = request.url.toString();

    /// Route list endpoint to _listJson fixture.
    if (url.contains('/pokemon?limit=')) {
      return _response(_listJson);
    }

    /// Route individual Pokémon detail endpoints to their fixtures.
    if (url.endsWith('/pokemon/bulbasaur')) {
      return _response(_bulbasaurJson);
    }
    if (url.endsWith('/pokemon/charmander')) {
      return _response(_charmanderJson);
    }

    /// Any unexpected URL is a test bug — fail loudly.
    throw UnsupportedError('Unexpected URL in test: $url');
  }

  /// Wraps [body] in a 200 OK [http.StreamedResponse].
  http.StreamedResponse _response(Map<String, dynamic> body) {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeHttpClient fakeClient;
  late PokemonRepositoryImpl repository;

  /// Reset fake and repository before each test for isolation.
  setUp(() {
    fakeClient = _FakeHttpClient();
    repository = PokemonRepositoryImpl(PokeApiHttpClient(fakeClient));
  });

  group('PokemonRepositoryImpl.getPokemonList', () {
    /// Should return all items enriched from the fake API responses.
    test('returns all items from API', () async {
      final list = await repository.getPokemonList(limit: 2);

      expect(list.length, 2);
      expect(list.map((p) => p.name), containsAll(['bulbasaur', 'charmander']));
    });

    /// Second call should use the cache — HTTP client not called again.
    test('caches results — HTTP not called on second getPokemonList', () async {
      /// First call: 1 list request + 2 detail requests = 3 HTTP calls.
      await repository.getPokemonList(limit: 2);
      final countAfterFirst = fakeClient.sendCallCount;

      /// Second call: should return cache with 0 additional HTTP calls.
      await repository.getPokemonList(limit: 2);

      expect(fakeClient.sendCallCount, countAfterFirst);
    });
  });

  group('PokemonRepositoryImpl.searchPokemon', () {
    /// Empty query returns everything.
    test('returns all items when query is empty', () async {
      final results = await repository.searchPokemon('');

      expect(results.length, 2);
    });

    /// Partial match should return matching Pokémon only.
    test('filters by substring match', () async {
      final results = await repository.searchPokemon('char');

      expect(results.length, 1);
      expect(results.first.name, 'charmander');
    });

    /// Uppercase query should still match because comparison lowercases input.
    test('match is case-insensitive', () async {
      final results = await repository.searchPokemon('BULB');

      expect(results.length, 1);
      expect(results.first.name, 'bulbasaur');
    });

    /// No match returns empty list without error.
    test('returns empty list when no Pokémon match', () async {
      final results = await repository.searchPokemon('zzz');

      expect(results, isEmpty);
    });

    /// Search populates cache; second search makes no additional HTTP calls.
    test('search populates cache on first call', () async {
      await repository.searchPokemon('char');
      final countAfterFirst = fakeClient.sendCallCount;

      /// Second search hits cache — no new HTTP calls.
      await repository.searchPokemon('bulb');

      expect(fakeClient.sendCallCount, countAfterFirst);
    });
  });

  group('PokemonRepositoryImpl.getPokemonDetail', () {
    /// Should return a [PokemonDetail] with fields from the fake detail response.
    test('returns PokemonDetail with correct fields', () async {
      final detail = await repository.getPokemonDetail('bulbasaur');

      expect(detail.id, 1);
      expect(detail.name, 'bulbasaur');
      expect(detail.types, ['grass', 'poison']);
      expect(detail.stats['hp'], 45);
    });
  });
}
