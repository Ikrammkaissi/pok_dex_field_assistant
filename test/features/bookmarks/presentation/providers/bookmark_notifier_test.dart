import 'package:flutter_test/flutter_test.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/data/bookmark_repository.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/presentation/providers/bookmark_notifier.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';

const _bulbasaur = PokemonSummary(
  id: 1,
  name: 'bulbasaur',
  spriteUrl: 'https://example.com/1.png',
  primaryType: 'grass',
);

const _charmander = PokemonSummary(
  id: 4,
  name: 'charmander',
  spriteUrl: 'https://example.com/4.png',
  primaryType: 'fire',
);

class _FakeBookmarkRepository implements BookmarkRepository {
  List<PokemonSummary> stored;
  int addCalls = 0;
  int removeCalls = 0;

  _FakeBookmarkRepository({List<PokemonSummary>? initial})
      : stored = List<PokemonSummary>.from(initial ?? const []);

  @override
  Future<void> addBookmark(PokemonSummary pokemon) async {
    addCalls++;
    if (stored.any((p) => p.name == pokemon.name)) return;
    stored = [...stored, pokemon];
  }

  @override
  Future<List<PokemonSummary>> getBookmarks() async {
    return List<PokemonSummary>.from(stored);
  }

  @override
  Future<void> removeBookmark(String pokemonName) async {
    removeCalls++;
    stored = stored.where((p) => p.name != pokemonName).toList();
  }
}

void main() {
  Future<void> flushLoad() async {
    await Future<void>.delayed(Duration.zero);
  }

  group('BookmarkNotifier', () {
    test('loads persisted bookmarks on init', () async {
      final repository = _FakeBookmarkRepository(
        initial: const [_bulbasaur, _charmander],
      );

      final notifier = BookmarkNotifier(repository);
      await flushLoad();

      expect(notifier.state.map((p) => p.name), ['bulbasaur', 'charmander']);
    });

    test('toggle adds pokemon when it is not bookmarked', () async {
      final repository = _FakeBookmarkRepository();
      final notifier = BookmarkNotifier(repository);
      await flushLoad();

      await notifier.toggle(_bulbasaur);

      expect(repository.addCalls, 1);
      expect(notifier.state.map((p) => p.name), ['bulbasaur']);
      expect(notifier.isBookmarked('bulbasaur'), isTrue);
    });

    test('toggle removes pokemon when it is bookmarked', () async {
      final repository = _FakeBookmarkRepository(initial: const [_bulbasaur]);
      final notifier = BookmarkNotifier(repository);
      await flushLoad();

      await notifier.toggle(_bulbasaur);

      expect(repository.removeCalls, 1);
      expect(notifier.state, isEmpty);
      expect(notifier.isBookmarked('bulbasaur'), isFalse);
    });

    test('toggle does not create duplicate entries', () async {
      final repository = _FakeBookmarkRepository();
      final notifier = BookmarkNotifier(repository);
      await flushLoad();

      await notifier.toggle(_bulbasaur); // add
      await notifier.toggle(_bulbasaur); // remove
      await notifier.toggle(_bulbasaur); // add again

      expect(notifier.state.where((p) => p.name == 'bulbasaur').length, 1);
    });
  });
}
