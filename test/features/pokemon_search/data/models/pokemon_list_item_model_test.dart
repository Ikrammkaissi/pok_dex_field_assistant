/// Unit tests for [PokemonListItemModel.fromJson] and [toEntity].
/// All tests use static JSON maps — no network or Flutter dependencies.
import 'package:flutter_test/flutter_test.dart';
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_list_item_model.dart';

void main() {
  /// Minimal valid JSON matching the shape of a `/pokemon/{name}` response.
  const validJson = <String, dynamic>{
    'id': 1,
    'name': 'bulbasaur',
    'sprites': {'front_default': 'https://example.com/1.png'},
    'types': [
      {
        'type': {'name': 'grass'}
      }
    ],
  };

  group('PokemonListItemModel.fromJson', () {
    /// Happy-path: all required fields present with correct types.
    test('parses valid JSON correctly', () {
      final model = PokemonListItemModel.fromJson(validJson);

      expect(model.id, 1);
      expect(model.name, 'bulbasaur');
      expect(model.spriteUrl, 'https://example.com/1.png');
      expect(model.primaryType, 'grass');
    });

    /// The first type in the array is always the primary type (slot 1).
    test('uses first type as primaryType when multiple types present', () {
      final json = <String, dynamic>{
        ...validJson,
        'types': [
          {
            'type': {'name': 'fire'}
          },
          {
            'type': {'name': 'flying'}
          },
        ],
      };
      final model = PokemonListItemModel.fromJson(json);

      expect(model.primaryType, 'fire');
    });

    /// PokéAPI returns null for `front_default` on some alternate forms.
    test('falls back to empty string when front_default is null', () {
      final json = <String, dynamic>{
        ...validJson,
        'sprites': {'front_default': null},
      };
      final model = PokemonListItemModel.fromJson(json);

      expect(model.spriteUrl, '');
    });

    /// Missing top-level field should throw [ParseException], not a raw TypeError.
    test('throws ParseException when id is missing', () {
      final json = Map<String, dynamic>.from(validJson)..remove('id');

      expect(
        () => PokemonListItemModel.fromJson(json),
        throwsA(isA<ParseException>()),
      );
    });

    /// Missing types array means we cannot determine the primary type.
    test('throws ParseException when types is missing', () {
      final json = Map<String, dynamic>.from(validJson)..remove('types');

      expect(
        () => PokemonListItemModel.fromJson(json),
        throwsA(isA<ParseException>()),
      );
    });

    /// Wrong type for id should produce a ParseException, not an unhandled error.
    test('throws ParseException when id is wrong type', () {
      final json = <String, dynamic>{...validJson, 'id': 'not-an-int'};

      expect(
        () => PokemonListItemModel.fromJson(json),
        throwsA(isA<ParseException>()),
      );
    });
  });

  group('PokemonListItemModel.toEntity', () {
    /// The entity should mirror all model fields exactly.
    test('converts to PokemonListItem with matching fields', () {
      final model = PokemonListItemModel.fromJson(validJson);
      final entity = model.toEntity();

      expect(entity.id, model.id);
      expect(entity.name, model.name);
      expect(entity.spriteUrl, model.spriteUrl);
      expect(entity.primaryType, model.primaryType);
    });
  });
}
