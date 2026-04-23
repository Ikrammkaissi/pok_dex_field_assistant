/// Unit tests for [PokemonSummary.fromJson].
/// All tests use static JSON maps , no network or Flutter dependencies.
import 'package:flutter_test/flutter_test.dart';
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';

void main() {
  /// Minimal valid JSON matching the shape of a `/pokemon/{name}` response.
  const validJson = <String, dynamic>{
    'id': 1,
    'name': 'bulbasaur',
    'sprites': {'front_default': 'https://example.com/1.png'},
    'types': [
      {
        'slot': 1,
        'type': {'name': 'grass'},
      },
      {
        'slot': 2,
        'type': {'name': 'poison'},
      },
    ],
  };

  group('PokemonSummary.fromJson', () {
    /// Happy-path: all required fields present with correct types.
    test('parses valid JSON correctly', () {
      final model = PokemonSummary.fromJson(validJson);

      expect(model.id, 1);
      expect(model.name, 'bulbasaur');
      expect(model.spriteUrl, 'https://example.com/1.png');
      expect(model.primaryType, 'grass');
    });

    /// PokéAPI returns null for `front_default` on some alternate forms.
    test('falls back to empty string when front_default is null', () {
      final json = <String, dynamic>{
        ...validJson,
        'sprites': {'front_default': null},
      };
      final model = PokemonSummary.fromJson(json);

      expect(model.spriteUrl, '');
      expect(model.primaryType, 'grass');
    });

    /// Missing top-level field should throw [ParseException], not a raw TypeError.
    test('throws ParseException when id is missing', () {
      final json = Map<String, dynamic>.from(validJson)..remove('id');

      expect(
        () => PokemonSummary.fromJson(json),
        throwsA(isA<ParseException>()),
      );
    });

    /// Wrong type for id should produce a ParseException, not an unhandled error.
    test('throws ParseException when id is wrong type', () {
      final json = <String, dynamic>{...validJson, 'id': 'not-an-int'};

      expect(
        () => PokemonSummary.fromJson(json),
        throwsA(isA<ParseException>()),
      );
    });

    /// Missing sprites key should throw ParseException.
    test('throws ParseException when sprites is missing', () {
      final json = Map<String, dynamic>.from(validJson)..remove('sprites');

      expect(
        () => PokemonSummary.fromJson(json),
        throwsA(isA<ParseException>()),
      );
    });
  });
}
