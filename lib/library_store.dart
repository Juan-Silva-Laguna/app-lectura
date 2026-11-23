import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

class LibraryStore {
  LibraryStore._(this.database, this.root);

  final Database database;
  final Directory root;

  static Future<LibraryStore> open(
    Directory root, {
    DatabaseFactory? factory,
  }) async {
    await root.create(recursive: true);
    await Directory(p.join(root.path, 'books')).create(recursive: true);
    final db = await (factory ?? databaseFactory).openDatabase(
      p.join(root.path, 'library.sqlite'),
      options: OpenDatabaseOptions(
        version: 3,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE books (
              id TEXT PRIMARY KEY, digest TEXT NOT NULL UNIQUE,
              title TEXT NOT NULL, file_name TEXT NOT NULL,
              page_count INTEGER NOT NULL CHECK(page_count > 0),
              read_page INTEGER NOT NULL DEFAULT 1,
              read_offset INTEGER NOT NULL DEFAULT 0,
              audio_page INTEGER NOT NULL DEFAULT 1,
              audio_offset INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE page_text (
              book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
              page INTEGER NOT NULL, text TEXT NOT NULL,
              PRIMARY KEY(book_id, page)
            )
          ''');
          await db.execute('''
            CREATE TABLE annotations (
              id TEXT PRIMARY KEY,
              book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
              page INTEGER NOT NULL,
              start_offset INTEGER NOT NULL CHECK(start_offset >= 0),
              end_offset INTEGER NOT NULL CHECK(end_offset > start_offset),
              quote TEXT NOT NULL, note TEXT NOT NULL,
              context_before TEXT NOT NULL, context_after TEXT NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX annotation_location ON annotations(book_id, page)',
          );
          await db.execute(
            'CREATE TABLE settings (id INTEGER PRIMARY KEY, value TEXT NOT NULL)',
          );
          await _createPdfHighlights(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createPdfHighlights(db);
          } else if (oldVersion < 3) {
            await db.execute(
              "ALTER TABLE pdf_highlights ADD COLUMN strokes TEXT NOT NULL DEFAULT '[]'",
            );
            await db.execute(
              'ALTER TABLE pdf_highlights ADD COLUMN stroke_width REAL NOT NULL DEFAULT 0.025',
            );
            await db.execute(
              "ALTER TABLE pdf_highlights ADD COLUMN note TEXT NOT NULL DEFAULT ''",
            );
          }
        },
      ),
    );
    return LibraryStore._(db, root);
  }

  String bookPath(Book book) => p.join(root.path, 'books', book.fileName);

  static Future<void> _createPdfHighlights(Database db) async {
    await db.execute('''
      CREATE TABLE pdf_highlights (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,
        page INTEGER NOT NULL CHECK(page > 0),
        "left" REAL NOT NULL CHECK("left" >= 0 AND "left" <= 1),
        "top" REAL NOT NULL CHECK("top" >= 0 AND "top" <= 1),
        "right" REAL NOT NULL CHECK("right" >= "left" AND "right" <= 1),
        "bottom" REAL NOT NULL CHECK("bottom" >= "top" AND "bottom" <= 1),
        color INTEGER NOT NULL,
        strokes TEXT NOT NULL DEFAULT '[]',
        stroke_width REAL NOT NULL DEFAULT 0.025,
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX pdf_highlight_location '
      'ON pdf_highlights(book_id, page)',
    );
  }

  Future<List<Book>> books() async => (await database.query(
    'books',
    orderBy: 'updated_at DESC',
  )).map(Book.fromMap).toList();

  Future<Book> book(String id) async {
    final rows = await database.query(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw StateError('El libro ya no está en la biblioteca.');
    return Book.fromMap(rows.single);
  }

  Future<Book> importPdf(
    Stream<List<int>> source,
    String title, {
    required Future<int> Function(String path) inspect,
  }) async {
    final name = title.trim();
    if (name.isEmpty) throw ArgumentError('Escribe un nombre para el libro.');
    final id = const Uuid().v4();
    final staging = File(p.join(root.path, 'books', '$id.importing'));
    final target = File(p.join(root.path, 'books', '$id.pdf'));
    var committed = false;
    try {
      final sink = staging.openWrite();
      try {
        await source.forEach((chunk) => sink.add(Uint8List.fromList(chunk)));
        await sink.flush();
      } finally {
        await sink.close();
      }
      final digest = (await sha256.bind(staging.openRead()).first).toString();
      final existing = await database.query(
        'books',
        where: 'digest = ?',
        whereArgs: [digest],
      );
      if (existing.isNotEmpty) {
        throw StateError(
          'Este PDF ya está importado como "${existing.single['title']}".',
        );
      }
      final count = await inspect(staging.path);
      if (count <= 0) throw const FormatException('El PDF no tiene páginas.');
      await staging.rename(target.path);
      await database.insert('books', {
        'id': id,
        'digest': digest,
        'title': name,
        'file_name': '$id.pdf',
        'page_count': count,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
      committed = true;
      return await book(id);
    } finally {
      if (await staging.exists()) await staging.delete();
      if (!committed && await target.exists()) await target.delete();
    }
  }

  Future<void> rename(Book book, String title) async {
    if (title.trim().isEmpty) {
      throw ArgumentError('El nombre no puede estar vacío.');
    }
    await database.update(
      'books',
      {'title': title.trim()},
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<void> deleteBook(Book book) async {
    await database.transaction((transaction) async {
      final deleted = await transaction.delete(
        'books',
        where: 'id = ?',
        whereArgs: [book.id],
      );
      if (deleted != 1) {
        throw StateError('El libro ya no está en la biblioteca.');
      }
      final file = File(bookPath(book));
      if (await file.exists()) await file.delete();
    });
  }

  Future<String?> cachedText(String bookId, int page) async {
    final rows = await database.query(
      'page_text',
      where: 'book_id = ? AND page = ?',
      whereArgs: [bookId, page],
    );
    return rows.isEmpty ? null : rows.single['text'] as String;
  }

  Future<void> cacheText(String bookId, int page, String text) async {
    await database.insert('page_text', {
      'book_id': bookId,
      'page': page,
      'text': text,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> savePosition(
    Book book,
    ReadingPosition position, {
    bool audio = false,
  }) async {
    if (position.page < 1 ||
        position.page > book.pageCount ||
        position.offset < 0) {
      throw ArgumentError('La posición está fuera del libro.');
    }
    final text = await cachedText(book.id, position.page);
    if (text != null && position.offset > text.length) {
      throw ArgumentError('La posición está fuera del texto.');
    }
    final prefix = audio ? 'audio' : 'read';
    await database.update(
      'books',
      {
        '${prefix}_page': position.page,
        '${prefix}_offset': position.offset,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<List<Annotation>> annotations(String bookId) async =>
      (await database.query(
        'annotations',
        where: 'book_id = ?',
        whereArgs: [bookId],
        orderBy: 'page, start_offset',
      )).map(Annotation.fromMap).toList();

  Future<void> annotate({
    required String bookId,
    required int page,
    required int start,
    required int end,
    String note = '',
  }) async {
    final text = await cachedText(bookId, page);
    if (text == null || start < 0 || end <= start || end > text.length) {
      throw ArgumentError('Selecciona un fragmento de texto válido.');
    }
    await database.insert('annotations', {
      'id': const Uuid().v4(),
      'book_id': bookId,
      'page': page,
      'start_offset': start,
      'end_offset': end,
      'quote': text.substring(start, end),
      'note': note.trim(),
      'context_before': text.substring(math.max(0, start - 48), start),
      'context_after': text.substring(end, math.min(text.length, end + 48)),
    });
  }

  Future<void> updateNote(Annotation annotation, String note) async {
    await database.update(
      'annotations',
      {'note': note.trim()},
      where: 'id = ?',
      whereArgs: [annotation.id],
    );
  }

  Future<void> removeAnnotation(String id) async {
    await database.delete('annotations', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PdfHighlight>> pdfHighlights(String bookId, [int? page]) async {
    final rows = await database.query(
      'pdf_highlights',
      where: page == null ? 'book_id = ?' : 'book_id = ? AND page = ?',
      whereArgs: page == null ? [bookId] : [bookId, page],
      orderBy: 'page, created_at',
    );
    return rows.map(PdfHighlight.fromMap).toList();
  }

  Future<void> addPdfHighlight({
    required String bookId,
    required int page,
    required List<PdfHighlightStroke> strokes,
    String note = '',
  }) async {
    if (page <= 0 || strokes.isEmpty) {
      throw ArgumentError('El trazo resaltado no es válido.');
    }
    final points = strokes.expand((stroke) => stroke.points).toList();
    if (points.isEmpty ||
        points.any(
          (point) => point.x < 0 || point.x > 1 || point.y < 0 || point.y > 1,
        ) ||
        strokes.any((stroke) => stroke.width <= 0)) {
      throw ArgumentError('El trazo resaltado no es válido.');
    }
    final left = points.map((point) => point.x).reduce(math.min);
    final top = points.map((point) => point.y).reduce(math.min);
    final right = points.map((point) => point.x).reduce(math.max);
    final bottom = points.map((point) => point.y).reduce(math.max);
    await database.insert('pdf_highlights', {
      'id': const Uuid().v4(),
      'book_id': bookId,
      'page': page,
      'left': left,
      'top': top,
      'right': right == left ? math.min(1, right + 0.0001) : right,
      'bottom': bottom == top ? math.min(1, bottom + 0.0001) : bottom,
      'color': strokes.first.color,
      'strokes': jsonEncode(strokes.map((stroke) => stroke.toJson()).toList()),
      'stroke_width': strokes.first.width,
      'note': note.trim(),
      'created_at': DateTime.now().microsecondsSinceEpoch,
    });
  }

  Future<void> updatePdfHighlightColor(String id, int color) async {
    final rows = await database.query(
      'pdf_highlights',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw StateError('El resaltado ya no existe.');
    final highlight = PdfHighlight.fromMap(rows.single);
    final strokes = highlight.strokes
        .map(
          (stroke) => PdfHighlightStroke(
            points: stroke.points,
            color: color,
            width: stroke.width,
          ).toJson(),
        )
        .toList();
    await database.update(
      'pdf_highlights',
      {'color': color, 'strokes': jsonEncode(strokes)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> removePdfHighlight(String id) async {
    await database.delete('pdf_highlights', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePdfHighlightNote(String id, String note) async {
    await database.update(
      'pdf_highlights',
      {'note': note.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<ReaderSettings> settings() async {
    final rows = await database.query('settings', where: 'id = 1');
    if (rows.isEmpty) return const ReaderSettings();
    final decoded = jsonDecode(rows.single['value'] as String);
    return ReaderSettings.fromMap(Map<String, Object?>.from(decoded as Map));
  }

  Future<void> saveSettings(ReaderSettings settings) async {
    await database.insert('settings', {
      'id': 1,
      'value': jsonEncode(settings.toMap()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() => database.close();
}
