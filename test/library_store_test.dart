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
  PdfHighlightStroke stroke({
    double x1 = 0.1,
    double y1 = 0.2,
    double x2 = 0.8,
    double y2 = 0.3,
    int color = 0xFFFFE066,
  }) => PdfHighlightStroke(
    points: [PdfHighlightPoint(x1, y1), PdfHighlightPoint(x2, y2)],
    color: color,
    width: 0.025,
  );

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

  test('version 1 libraries migrate to persistent PDF highlights', () async {
    final legacyRoot = await Directory.systemTemp.createTemp(
      'lectura_migration_test_',
    );
    try {
      final legacy = await databaseFactoryFfi.openDatabase(
        p.join(legacyRoot.path, 'library.sqlite'),
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE books (
                id TEXT PRIMARY KEY, digest TEXT NOT NULL UNIQUE,
                title TEXT NOT NULL, file_name TEXT NOT NULL,
                page_count INTEGER NOT NULL,
                read_page INTEGER NOT NULL DEFAULT 1,
                read_offset INTEGER NOT NULL DEFAULT 0,
                audio_page INTEGER NOT NULL DEFAULT 1,
                audio_offset INTEGER NOT NULL DEFAULT 0,
                updated_at INTEGER NOT NULL
              )
            ''');
          },
        ),
      );
      await legacy.close();

      final migrated = await LibraryStore.open(
        legacyRoot,
        factory: databaseFactoryFfi,
      );
      try {
        await expectLater(
          migrated.addPdfHighlight(
            bookId: 'missing',
            page: 1,
            strokes: [stroke()],
          ),
          throwsException,
        );
        expect(await migrated.pdfHighlights('missing', 1), isEmpty);
      } finally {
        await migrated.close();
      }
    } finally {
      await legacyRoot.delete(recursive: true);
    }
  });

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

  test('deleting a book removes its file and all related data', () async {
    final book = await import();
    await store.cacheText(book.id, 1, 'Texto para borrar');
    await store.annotate(bookId: book.id, page: 1, start: 0, end: 5);
    await store.addPdfHighlight(
      bookId: book.id,
      page: 1,
      strokes: [stroke()],
      note: 'Una idea del PDF',
    );

    await store.deleteBook(book);

    expect(await File(store.bookPath(book)).exists(), isFalse);
    expect(await store.books(), isEmpty);
    expect(await store.cachedText(book.id, 1), isNull);
    expect(await store.annotations(book.id), isEmpty);
    expect(await store.pdfHighlights(book.id, 1), isEmpty);
  });

  test('PDF highlights persist, can change color and can be undone', () async {
    final book = await import();
    await store.addPdfHighlight(
      bookId: book.id,
      page: 2,
      strokes: [stroke(x2: 0.9, y2: 0.25)],
      note: 'Lo entendí así',
    );
    final highlight = (await store.pdfHighlights(book.id, 2)).single;
    await store.updatePdfHighlightColor(highlight.id, 0xFF8BE0B5);
    await store.close();
    store = await LibraryStore.open(root, factory: databaseFactoryFfi);

    final reopened = (await store.pdfHighlights(book.id, 2)).single;
    expect(reopened.color, 0xFF8BE0B5);
    expect(reopened.strokes.single.color, 0xFF8BE0B5);
    expect(reopened.strokes.single.points, hasLength(2));
    expect(reopened.note, 'Lo entendí así');
    expect(reopened.left, 0.1);
    expect(reopened.bottom, 0.25);
    await store.removePdfHighlight(reopened.id);
    expect(await store.pdfHighlights(book.id, 2), isEmpty);
  });

  test('PDF highlights reject coordinates outside the page', () async {
    final book = await import();
    await expectLater(
      store.addPdfHighlight(
        bookId: book.id,
        page: 1,
        strokes: [stroke(x1: -0.1)],
      ),
      throwsArgumentError,
    );
    await expectLater(
      store.addPdfHighlight(
        bookId: book.id,
        page: 1,
        strokes: [stroke(x1: 0.9, x2: 1.1, y2: 0.2)],
      ),
      throwsArgumentError,
    );
  });
}
