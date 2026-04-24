/// Unit tests for [PokemonDetail.fromJson] and [MoveEntry.fromJson].
/// All tests use static JSON maps , no network or Flutter dependencies.
import 'package:flutter_test/flutter_test.dart';
import 'package:pok_dex_field_assistant/core/error/exceptions.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_detail_mapper.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/move_entry.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/domain/entities/pokemon_detail.dart';

/// Minimal valid move entry JSON matching PokéAPI shape.
Map<String, dynamic> _moveJson({
  String name = 'tackle',
  String method = 'level-up',
  int level = 1,
}) =>
    {
      'move': {'name': name, 'url': 'https://pokeapi.co/api/v2/move/33/'},
      'version_group_details': [
        {
          'level_learned_at': level,
          'move_learn_method': {
            'name': method,
            'url': 'https://pokeapi.co/api/v2/move-learn-method/1/',
          },
          'version_group': {
            'name': 'red-blue',
            'url': 'https://pokeapi.co/api/v2/version-group/1/',
          },
        },
      ],
    };

/// Full valid JSON matching the abbreviated shape of a `/pokemon/{name}` response.
/// Includes all fields parsed by [PokemonDetail.fromJson].
final _validJson = <String, dynamic>{
  'id': 6,
  'name': 'charizard',
  'height': 17,
  'weight': 905,
  'base_experience': 240,
  'sprites': {
    'front_default': 'https://example.com/front.png',
    'back_default': 'https://example.com/back.png',
    'front_shiny': 'https://example.com/front_shiny.png',
    'back_shiny': 'https://example.com/back_shiny.png',
    'other': {
      'official-artwork': {
        'front_default': 'https://example.com/artwork.png',
        'front_shiny': 'https://example.com/artwork_shiny.png',
      },
    },
  },
  'types': [
    {'type': {'name': 'fire'}},
    {'type': {'name': 'flying'}},
  ],
  'abilities': [
    {'ability': {'name': 'blaze'}, 'is_hidden': false},
    {'ability': {'name': 'solar-power'}, 'is_hidden': true},
  ],
  'stats': [
    {'stat': {'name': 'hp'}, 'base_stat': 78},
    {'stat': {'name': 'attack'}, 'base_stat': 84},
  ],
  'moves': [
    _moveJson(name: 'scratch', method: 'level-up', level: 1),
    _moveJson(name: 'ember', method: 'level-up', level: 7),
    _moveJson(name: 'flamethrower', method: 'machine', level: 0),
  ],
  'game_indices': [
    {'game_index': 6, 'version': {'name': 'red'}},
    {'game_index': 6, 'version': {'name': 'blue'}},
    {'game_index': 6, 'version': {'name': 'gold'}},
  ],
  'cries': {
    'latest': 'https://example.com/cry_latest.ogg',
    'legacy': 'https://example.com/cry_legacy.ogg',
  },
};

void main() {
  group('MoveEntry.fromJson', () {
    test('parses name, method and level', () {
      final entry = PokemonDetailMapper.moveFromJson(
          _moveJson(name: 'ember', method: 'level-up', level: 7));

      expect(entry.name, 'ember');
      expect(entry.learnMethod, 'level-up');
      expect(entry.levelLearnedAt, 7);
    });

    test('level 0 for machine moves', () {
      final entry =
          PokemonDetailMapper.moveFromJson(_moveJson(name: 'flamethrower', method: 'machine', level: 0));

      expect(entry.learnMethod, 'machine');
      expect(entry.levelLearnedAt, 0);
    });

    test('uses last version_group_details entry', () {
      /// Two version entries , should pick the last one.
      final json = <String, dynamic>{
        'move': {'name': 'tackle', 'url': ''},
        'version_group_details': [
          {
            'level_learned_at': 5,
            'move_learn_method': {'name': 'level-up', 'url': ''},
            'version_group': {'name': 'red-blue', 'url': ''},
          },
          {
            'level_learned_at': 9,
            'move_learn_method': {'name': 'level-up', 'url': ''},
            'version_group': {'name': 'sword-shield', 'url': ''},
          },
        ],
      };

      final entry = PokemonDetailMapper.moveFromJson(json);
      expect(entry.levelLearnedAt, 9);
    });

    test('empty version_group_details defaults gracefully', () {
      final json = <String, dynamic>{
        'move': {'name': 'tackle', 'url': ''},
        'version_group_details': [],
      };

      final entry = PokemonDetailMapper.moveFromJson(json);
      expect(entry.learnMethod, '');
      expect(entry.levelLearnedAt, 0);
    });
  });

  group('PokemonDetail.fromJson', () {
    test('parses core fields correctly', () {
      final model = PokemonDetailMapper.fromJson(_validJson);

      expect(model.id, 6);
      expect(model.name, 'charizard');
      expect(model.height, 17);
      expect(model.weight, 905);
      expect(model.baseExperience, 240);
    });

    test('parses all four sprite URLs', () {
      final model = PokemonDetailMapper.fromJson(_validJson);

      expect(model.spriteUrl, 'https://example.com/front.png');
      expect(model.backSpriteUrl, 'https://example.com/back.png');
      expect(model.frontShinySpriteUrl, 'https://example.com/front_shiny.png');
      expect(model.backShinySpriteUrl, 'https://example.com/back_shiny.png');
    });

    test('parses official artwork URLs', () {
      final model = PokemonDetailMapper.fromJson(_validJson);

      expect(model.officialArtworkUrl, 'https://example.com/artwork.png');
      expect(model.officialArtworkShinyUrl,
          'https://example.com/artwork_shiny.png');
    });

    test('falls back to front sprite when official artwork missing', () {
      final json = <String, dynamic>{
        ..._validJson,
        'sprites': {
          'front_default': 'https://example.com/front.png',
          'back_default': null,
          'front_shiny': null,
          'back_shiny': null,
        },
      };

      final model = PokemonDetailMapper.fromJson(json);
      expect(model.officialArtworkUrl, 'https://example.com/front.png');
      expect(model.officialArtworkShinyUrl, 'https://example.com/front.png');
    });

    test('falls back to empty string when back/shiny sprites are null', () {
      final json = <String, dynamic>{
        ..._validJson,
        'sprites': {
          'front_default': 'https://example.com/front.png',
          'back_default': null,
          'front_shiny': null,
          'back_shiny': null,
          'other': <String, dynamic>{},
        },
      };

      final model = PokemonDetailMapper.fromJson(json);
      expect(model.backSpriteUrl, '');
      expect(model.frontShinySpriteUrl, '');
      expect(model.backShinySpriteUrl, '');
    });

    test('parses types in slot order', () {
      final model = PokemonDetailMapper.fromJson(_validJson);
      expect(model.types, ['fire', 'flying']);
    });

    test('handles single type', () {
      final json = <String, dynamic>{
        ..._validJson,
        'types': [
          {'type': {'name': 'psychic'}}
        ],
      };
      expect(PokemonDetailMapper.fromJson(json).types, ['psychic']);
    });

    test('parses abilities in slot order with hidden flags', () {
      final model = PokemonDetailMapper.fromJson(_validJson);
      expect(model.abilities.map((a) => a.name), ['blaze', 'solar-power']);
      expect(model.abilities.map((a) => a.isHidden), [false, true]);
    });

    test('parses stats map', () {
      final model = PokemonDetailMapper.fromJson(_validJson);
      expect(model.stats['hp'], 78);
      expect(model.stats['attack'], 84);
      expect(model.stats.length, 2);
    });

    test('parses moves with correct count and types', () {
      final model = PokemonDetailMapper.fromJson(_validJson);

      expect(model.moveCount, 3);
      expect(model.moves.length, 3);
      expect(model.moves.map((m) => m.name),
          containsAll(['scratch', 'ember', 'flamethrower']));
    });

    test('level-up moves have correct levels', () {
      final model = PokemonDetailMapper.fromJson(_validJson);
      final scratch = model.moves.firstWhere((m) => m.name == 'scratch');
      final ember = model.moves.firstWhere((m) => m.name == 'ember');

      expect(scratch.levelLearnedAt, 1);
      expect(ember.levelLearnedAt, 7);
    });

    test('machine move has level 0', () {
      final model = PokemonDetailMapper.fromJson(_validJson);
      final flamethrower =
          model.moves.firstWhere((m) => m.name == 'flamethrower');

      expect(flamethrower.learnMethod, 'machine');
      expect(flamethrower.levelLearnedAt, 0);
    });

    test('empty moves list produces moveCount 0', () {
      final json = <String, dynamic>{..._validJson, 'moves': []};
      expect(PokemonDetailMapper.fromJson(json).moveCount, 0);
    });

    test('parses game_indices version names', () {
      final model = PokemonDetailMapper.fromJson(_validJson);
      expect(model.gameIndices, ['red', 'blue', 'gold']);
    });

    test('empty game_indices produces empty list', () {
      final json = <String, dynamic>{..._validJson, 'game_indices': []};
      expect(PokemonDetailMapper.fromJson(json).gameIndices, isEmpty);
    });

    test('parses cry URLs', () {
      final model = PokemonDetailMapper.fromJson(_validJson);
      expect(model.cryLatestUrl, 'https://example.com/cry_latest.ogg');
      expect(model.cryLegacyUrl, 'https://example.com/cry_legacy.ogg');
    });

    test('falls back to empty string when cries missing', () {
      final json = Map<String, dynamic>.from(_validJson)..remove('cries');
      final model = PokemonDetailMapper.fromJson(json);

      expect(model.cryLatestUrl, '');
      expect(model.cryLegacyUrl, '');
    });

    test('defaults base_experience to 0 when null', () {
      final json = <String, dynamic>{..._validJson, 'base_experience': null};
      expect(PokemonDetailMapper.fromJson(json).baseExperience, 0);
    });

    test('throws ParseException when height is missing', () {
      final json = Map<String, dynamic>.from(_validJson)..remove('height');
      expect(() => PokemonDetailMapper.fromJson(json), throwsA(isA<ParseException>()));
    });

    test('throws ParseException when types is not a list', () {
      final json = <String, dynamic>{..._validJson, 'types': 'not-a-list'};
      expect(() => PokemonDetailMapper.fromJson(json), throwsA(isA<ParseException>()));
    });

    test('throws ParseException when stats is missing', () {
      final json = Map<String, dynamic>.from(_validJson)..remove('stats');
      expect(() => PokemonDetailMapper.fromJson(json), throwsA(isA<ParseException>()));
    });
  });
}
