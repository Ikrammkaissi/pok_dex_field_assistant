/// Unit tests for [PokemonRepositoryImpl].
/// Uses a hand-written fake [http.Client] , no external mocking packages needed.
/// Tests state transitions in isolation; no real HTTP calls are made.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pok_dex_field_assistant/core/network/http_client.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/pokemon_repository.dart';

// ---------------------------------------------------------------------------
// Static JSON fixtures
// ---------------------------------------------------------------------------

/// Minimal detail JSON for Bulbasaur , used for both list enrichment and detail fetch.
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

/// List-endpoint response with a next page available.
/// urls match the canonical PokéAPI pattern so _spriteUrlFromApiUrl can extract IDs.
const _listJsonWithMore = <String, dynamic>{
  'count': 1350,
  'next': 'https://pokeapi.co/api/v2/pokemon?offset=2&limit=2',
  'previous': null,
  'results': [
    {'name': 'bulbasaur', 'url': 'https://pokeapi.co/api/v2/pokemon/1/'},
    {'name': 'charmander', 'url': 'https://pokeapi.co/api/v2/pokemon/4/'},
  ],
};

/// List-endpoint response where next is null , last page.
const _listJsonNoMore = <String, dynamic>{
  'count': 1350,
  'next': null,
  'previous': null,
  'results': [
    {'name': 'bulbasaur', 'url': 'https://pokeapi.co/api/v2/pokemon/1/'},
    {'name': 'charmander', 'url': 'https://pokeapi.co/api/v2/pokemon/4/'},
  ],
};

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

/// Fake [http.BaseClient] that returns pre-baked JSON without network access.
/// Routes requests by URL substring to the appropriate fixture.
class _FakeHttpClient extends http.BaseClient {
  /// Controls which list fixture to return.
  final bool hasMore;

  _FakeHttpClient({this.hasMore = true});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();

    /// Route list endpoint to the appropriate fixture based on [hasMore].
    if (url.contains('/pokemon?limit=')) {
      return _response(hasMore ? _listJsonWithMore : _listJsonNoMore);
    }

    /// Route individual Pokémon detail endpoints to their fixtures.
    if (url.endsWith('/pokemon/bulbasaur')) {
      return _response(_bulbasaurJson);
    }
    if (url.endsWith('/pokemon/charmander')) {
      return _response(_charmanderJson);
    }

    /// Any unexpected URL is a test bug , fail loudly.
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
  late PokemonRepositoryImpl repository;

  group('PokemonRepositoryImpl.getPokemonList', () {
    test('returns items from API response', () async {
      repository =
          PokemonRepositoryImpl(PokeApiHttpClient(_FakeHttpClient()));

      final page = await repository.getPokemonList(limit: 2);

      expect(page.items.length, 2);
      expect(page.items.map((p) => p.name),
          containsAll(['bulbasaur', 'charmander']));
    });

    test('hasMore is true when next field is non-null', () async {
      repository =
          PokemonRepositoryImpl(PokeApiHttpClient(_FakeHttpClient(hasMore: true)));

      final page = await repository.getPokemonList(limit: 2);

      expect(page.hasMore, isTrue);
    });

    test('hasMore is false when next field is null', () async {
      repository = PokemonRepositoryImpl(
          PokeApiHttpClient(_FakeHttpClient(hasMore: false)));

      final page = await repository.getPokemonList(limit: 2);

      expect(page.hasMore, isFalse);
    });

    test('each call hits the network , no internal cache', () async {
      /// Count HTTP calls across two getPokemonList calls.
      var callCount = 0;
      final client = _CountingFakeClient(
          inner: _FakeHttpClient(), onSend: () => callCount++);
      repository = PokemonRepositoryImpl(PokeApiHttpClient(client));

      await repository.getPokemonList(limit: 2);
      final afterFirst = callCount;

      await repository.getPokemonList(limit: 2);

      /// Second call should make the same number of HTTP calls as the first.
      expect(callCount, greaterThan(afterFirst));
    });
  });

  group('PokemonRepositoryImpl.getPokemonDetail', () {
    setUp(() {
      repository =
          PokemonRepositoryImpl(PokeApiHttpClient(_FakeHttpClient()));
    });

    test('returns PokemonDetail with correct fields', () async {
      final detail = await repository.getPokemonDetail('bulbasaur');

      expect(detail.id, 1);
      expect(detail.name, 'bulbasaur');
      expect(detail.types, ['grass', 'poison']);
      expect(detail.stats['hp'], 45);
    });
  });
}

/// Wraps [_FakeHttpClient] and counts every [send] call.
class _CountingFakeClient extends http.BaseClient {
  final http.BaseClient inner;
  final void Function() onSend;

  _CountingFakeClient({required this.inner, required this.onSend});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    onSend();
    return inner.send(request);
  }
}
