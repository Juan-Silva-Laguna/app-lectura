import 'dart:convert';
import 'dart:io';

import 'package:app_lectura/library_store.dart';
import 'package:app_lectura/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory root;
  late LibraryStore store;

  setUp(() async {
    sqfliteFfiInit();
    root = await Directory.systemTemp.createTemp('lectura_store_test_');
    store = await LibraryStore.open(root, factory: databaseFactoryFfi);
  });
  tearDown(() async {
    await store.close();
    await root.delete(recursive: true);
  });

  Stream<List<int>> source() => Stream.value(utf8.encode('PDF fixture bytes'));
  Future<Book> import() =>
      store.importPdf(source(), 'Mi libro', inspect: (_) async => 3);

  test(
    'import is private, title is not used as a path, duplicates are rejected',
    () async {
      final book = await store.importPdf(
        source(),
        '../../Mi libro',
        inspect: (_) async => 3,
      );
      expect(p.isWithin(root.path, store.bookPath(book)), isTrue);
      expect(
        await File(store.bookPath(book)).readAsString(),
        'PDF fixture bytes',
      );
      await expectLater(import(), throwsStateError);
      expect(await store.books(), hasLength(1));
      expect(await Directory(p.join(root.path, 'books')).list().length, 1);
    },
  );

  test(
    'failed inspection and stream errors leave no book or partial file',
    () async {
      await expectLater(
        store.importPdf(
          source(),
          'Dañado',
          inspect: (_) async => throw const FormatException('Invalid PDF'),
        ),
        throwsFormatException,
      );
      await expectLater(
        store.importPdf(
          Stream<List<int>>.error(const FileSystemException('Read failed')),
          'No disponible',
          inspect: (_) async => 3,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await store.books(), isEmpty);
      expect(
        await Directory(p.join(root.path, 'books')).list().toList(),
        isEmpty,
      );
    },
  );

  test(
    'reading, audio, annotations and typography survive reopening SQLite',
    () async {
      final book = await import();
      const text = 'Antes. Texto seleccionado. Después.';
      await store.cacheText(book.id, 2, text);
      await store.savePosition(book, const ReadingPosition(page: 2, offset: 7));
      await store.savePosition(
        book,
        const ReadingPosition(page: 2, offset: 25),
        audio: true,
      );
      await store.annotate(
        bookId: book.id,
        page: 2,
        start: 7,
        end: 25,
        note: 'Una idea',
      );
      await store.saveSettings(
        const ReaderSettings(
          font: 'Atkinson',
          fontSize: 30,
          theme: ReadingTheme.dark,
        ),
      );
      await store.close();
      store = await LibraryStore.open(root, factory: databaseFactoryFfi);
      final reopened = await store.book(book.id);
      expect(reopened.reading.page, 2);
      expect(reopened.reading.offset, 7);
      expect(reopened.audio.offset, 25);
      final note = (await store.annotations(book.id)).single;
      expect(note.quote, 'Texto seleccionado');
      expect(note.contextBefore, 'Antes. ');
      expect(note.contextAfter, '. Después.');
      expect(note.note, 'Una idea');
      expect((await store.settings()).fontSize, 30);
      expect((await store.settings()).theme, ReadingTheme.dark);
      await store.updateNote(note, 'Nueva idea');
      expect((await store.annotations(book.id)).single.note, 'Nueva idea');
      await store.removeAnnotation(note.id);
      expect(await store.annotations(book.id), isEmpty);
    },
  );

  test(
    'cached text is immutable and out-of-range anchors cannot be saved',
    () async {
      final book = await import();
      await store.cacheText(book.id, 1, 'Texto original');
      await store.cacheText(book.id, 1, 'Cambio del extractor');
      expect(await store.cachedText(book.id, 1), 'Texto original');
      await expectLater(
        store.savePosition(book, const ReadingPosition(page: 4)),
        throwsArgumentError,
      );
      await expectLater(
        store.savePosition(book, const ReadingPosition(offset: 500)),
        throwsArgumentError,
      );
      await expectLater(
        store.annotate(bookId: book.id, page: 1, start: 1, end: 1),
        throwsArgumentError,
      );
      await expectLater(
        store.annotate(bookId: book.id, page: 1, start: -1, end: 4),
        throwsArgumentError,
      );
      expect(await store.annotations(book.id), isEmpty);
    },
  );
}
