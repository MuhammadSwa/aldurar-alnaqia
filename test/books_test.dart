import 'package:flutter_test/flutter_test.dart';
import 'package:aldurar_alnaqia/screens/library_screen/books.dart';

void main() {
  group('book catalogue', () {
    test('ids are ASCII slugs (route-, filename- and notification-safe)', () {
      final slug = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
      for (final book in books) {
        expect(book.id, matches(slug), reason: 'book id: ${book.id}');
      }
    });

    test('ids are unique', () {
      final ids = books.map((b) => b.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('bookById resolves every id and rejects unknown ids', () {
      for (final book in books) {
        expect(bookById(book.id), same(book));
      }
      expect(bookById('no-such-book'), isNull);
    });

    test('every book has a full title, a display title and an https url', () {
      for (final book in books) {
        expect(book.fullTitle, isNotEmpty);
        expect(book.title, isNotEmpty);
        expect(book.url, startsWith('https://'));
      }
    });
  });
}
