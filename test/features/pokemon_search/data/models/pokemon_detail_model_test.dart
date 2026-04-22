/// Unit tests for [PokemonDetailModel.fromJson] and [toEntity].
/// All tests use static JSON maps — no network or Flutter dependencies.
import 'package:flutter_test/flutter_test.dart';
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_detail_model.dart';

void main() {
  /// Valid JSON matching the abbreviated shape of a `/pokemon/{name}` response.
  const validJson = <String, dynamic>{
    'id': 6,
    'name': 'charizard',
    'height': 17,
    'weight': 905,
    'sprites': {'front_default': 'https://example.com/6.png'},
    'types': [
      {
        'type': {'name': 'fire'}
      },
      {
        'type': {'name': 'flying'}
      },
    ],
    'abilities': [
      {
        'ability': {'name': 'blaze'}
      },
      {
        'ability': {'name': 'solar-power'}
      },
    ],
    'stats': [
      {
        'stat': {'name': 'hp'},
        'base_stat': 78
      },
      {
        'stat': {'name': 'attack'},
        'base_stat': 84
      },
    ],
  };

  group('PokemonDetailModel.fromJson', () {
    /// Happy-path: all required fields present.
    test('parses valid JSON correctly', () {
      final model = PokemonDetailModel.fromJson(validJson);

      expect(model.id, 6);
      expect(model.name, 'charizard');
      expect(model.height, 17);
      expect(model.weight, 905);
      expect(model.spriteUrl, 'https://example.com/6.png');
      expect(model.types, ['fire', 'flying']);
      expect(model.abilities, ['blaze', 'solar-power']);
      expect(model.stats, {'hp': 78, 'attack': 84});
    });

    /// Single-type Pokémon (e.g. Mewtwo) should parse without errors.
    test('handles single type correctly', () {
      final json = <String, dynamic>{
        ...validJson,
        'types': [
          {
            'type': {'name': 'psychic'}
          }
        ],
      };
      final model = PokemonDetailModel.fromJson(json);

      expect(model.types, ['psychic']);
    });

    /// Null sprite should not throw — fall back to empty string.
    test('falls back to empty string when front_default is null', () {
      final json = <String, dynamic>{
        ...validJson,
        'sprites': {'front_default': null},
      };
      final model = PokemonDetailModel.fromJson(json);

      expect(model.spriteUrl, '');
    });

    /// Stat map should contain exactly the entries from the JSON array.
    test('builds stats map with correct values', () {
      final model = PokemonDetailModel.fromJson(validJson);

      expect(model.stats['hp'], 78);
      expect(model.stats['attack'], 84);
      expect(model.stats.length, 2);
    });

    /// Missing height is required — should throw ParseException.
    test('throws ParseException when height is missing', () {
      final json = Map<String, dynamic>.from(validJson)..remove('height');

      expect(
        () => PokemonDetailModel.fromJson(json),
        throwsA(isA<ParseException>()),
      );
    });

    /// Wrong type for types array should throw ParseException.
    test('throws ParseException when types is not a list', () {
      final json = <String, dynamic>{...validJson, 'types': 'not-a-list'};

      expect(
        () => PokemonDetailModel.fromJson(json),
        throwsA(isA<ParseException>()),
      );
    });

    /// Missing stats array should throw ParseException.
    test('throws ParseException when stats is missing', () {
      final json = Map<String, dynamic>.from(validJson)..remove('stats');

      expect(
        () => PokemonDetailModel.fromJson(json),
        throwsA(isA<ParseException>()),
      );
    });
  });

  group('PokemonDetailModel.toEntity', () {
    /// Entity should mirror all model fields exactly.
    test('converts to PokemonDetail with matching fields', () {
      final model = PokemonDetailModel.fromJson(validJson);
      final entity = model.toEntity();

      expect(entity.id, model.id);
      expect(entity.name, model.name);
      expect(entity.spriteUrl, model.spriteUrl);
      expect(entity.types, model.types);
      expect(entity.height, model.height);
      expect(entity.weight, model.weight);
      expect(entity.abilities, model.abilities);
      expect(entity.stats, model.stats);
    });
  });
}
