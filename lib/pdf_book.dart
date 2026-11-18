import 'package:pdfrx/pdfrx.dart';

import 'library_store.dart';
import 'models.dart';

class PdfBook {
  PdfBook._(this.document, this.store, this.book);

  final PdfDocument document;
  final LibraryStore store;
  final Book book;

  static Future<PdfDocument> _open(String path) async {
    final document = await PdfDocument.openFile(path);
    if (document.isEncrypted ||
        document.permissions?.allowsCopying == false ||
        document.pages.isEmpty) {
      await document.dispose();
      throw const FormatException(
        'Usa un PDF sin contraseña ni restricciones de extracción de texto.',
      );
    }
    return document;
  }

  static Future<int> inspect(String path) async {
    final document = await _open(path);
    try {
      return document.pages.length;
    } finally {
      await document.dispose();
    }
  }

  static Future<PdfBook> open(LibraryStore store, Book book) async =>
      PdfBook._(await _open(store.bookPath(book)), store, book);

  Future<String> text(int page) async {
    final cached = await store.cachedText(book.id, page);
    if (cached != null) return cached;
    final extracted = await document.pages[page - 1].loadText();
    if (extracted == null) {
      throw StateError(
        'La página $page aún no está disponible para extraer texto.',
      );
    }
    await store.cacheText(book.id, page, extracted.fullText);
    return extracted.fullText;
  }

  Future<void> close() => document.dispose();
}
