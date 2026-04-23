import 'package:flutter_test/flutter_test.dart';
import 'package:pok_dex_field_assistant/features/bookmarks/data/bookmark_repository.dart';
import 'package:pok_dex_field_assistant/features/pokemon_search/data/models/pokemon_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<BookmarkRepositoryImpl> makeRepository() async {
    final prefs = await SharedPreferences.getInstance();
    return BookmarkRepositoryImpl(prefs);
  }

  group('BookmarkRepositoryImpl', () {
    test('getBookmarks returns empty list when nothing is stored', () async {
      final repository = await makeRepository();

      final result = await repository.getBookmarks();

      expect(result, isEmpty);
    });

    test('addBookmark stores item and getBookmarks returns it', () async {
      final repository = await makeRepository();

      await repository.addBookmark(_bulbasaur);
      final result = await repository.getBookmarks();

      expect(result.length, 1);
      expect(result.first.name, 'bulbasaur');
      expect(result.first.primaryType, 'grass');
    });

    test('addBookmark ignores duplicates by name', () async {
      final repository = await makeRepository();

      await repository.addBookmark(_bulbasaur);
      await repository.addBookmark(_bulbasaur);
      final result = await repository.getBookmarks();

      expect(result.length, 1);
    });

    test('setBookmarks persists full list in one operation', () async {
      final repository = await makeRepository();

      await repository.setBookmarks(const [_bulbasaur, _charmander]);
      final result = await repository.getBookmarks();

      expect(result.map((p) => p.name), ['bulbasaur', 'charmander']);
    });

    test('removeBookmark removes only matching pokemon', () async {
      final repository = await makeRepository();

      await repository.addBookmark(_bulbasaur);
      await repository.addBookmark(_charmander);
      await repository.removeBookmark('bulbasaur');
      final result = await repository.getBookmarks();

      expect(result.map((p) => p.name), ['charmander']);
    });

    test('removeBookmark is no-op when pokemon does not exist', () async {
      final repository = await makeRepository();

      await repository.addBookmark(_charmander);
      await repository.removeBookmark('pikachu');
      final result = await repository.getBookmarks();

      expect(result.map((p) => p.name), ['charmander']);
    });
  });
}
