import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_lectura/library_store.dart';
import 'package:app_lectura/models.dart';
import 'package:app_lectura/pdf_book.dart';
import 'package:app_lectura/pdf_export.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Uint8List samplePdf() {
  const first = 'BT /F1 18 Tf 40 740 Td (Primera lectura.) Tj ET';
  const second = 'BT /F1 18 Tf 40 740 Td (Segunda pagina.) Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R /Outlines 8 0 R >>',
    '<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
        '/Resources << /Font << /F1 5 0 R >> >> /Contents 6 0 R >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
        '/Resources << /Font << /F1 5 0 R >> >> /Contents 7 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${first.length} >>\nstream\n$first\nendstream',
    '<< /Length ${second.length} >>\nstream\n$second\nendstream',
    '<< /Type /Outlines /First 9 0 R /Last 9 0 R /Count 1 >>',
    '<< /Title (Capitulo uno) /Parent 8 0 R /Dest [3 0 R /Fit] >>',
  ];
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(buffer.length);
    buffer.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = buffer.length;
  buffer.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  return Uint8List.fromList(ascii.encode(buffer.toString()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real PDF imports, extracts, renders, annotates and resumes after reopening', () async {
    sqfliteFfiInit();
    final root = await Directory.systemTemp.createTemp('lectura_pdf_test_');
    Pdfrx.cacheDirectoryPath = root.path;
    await pdfrxFlutterInitialize();
    var store = await LibraryStore.open(root, factory: databaseFactoryFfi);
    PdfBook? pdf;
    try {
      final book = await store.importPdf(
        Stream.value(samplePdf()),
        'Libro de prueba',
        inspect: PdfBook.inspect,
      );
      expect(book.pageCount, 2);
      pdf = await PdfBook.open(store, book);
      final text = await pdf.text(1);
      expect(text.trim(), 'Primera lectura.');
      expect((await pdf.document.loadOutline()).single.dest?.pageNumber, 1);
      final image = await pdf.document.pages.first.render(
        width: 100,
        height: 130,
      );
      expect(image, isNotNull);
      expect(image!.width, 100);
      expect(image.height, 130);
      image.dispose();
      final start = text.indexOf('lectura');
      await store.annotate(
        bookId: book.id,
        page: 1,
        start: start,
        end: start + 7,
      );
      await store.savePosition(book, ReadingPosition(offset: start));
      await pdf.close();
      pdf = null;
      await store.close();
      store = await LibraryStore.open(root, factory: databaseFactoryFfi);
      final reopened = await store.book(book.id);
      pdf = await PdfBook.open(store, reopened);
      expect(reopened.reading.offset, start);
      expect((await pdf.text(1)).substring(start, start + 7), 'lectura');
      expect((await store.annotations(book.id)).single.quote, 'lectura');
      await store.addPdfHighlight(
        bookId: book.id,
        page: 1,
        strokes: [
          PdfHighlightStroke(
            points: const [
              PdfHighlightPoint(0.1, 0.2),
              PdfHighlightPoint(0.5, 0.2),
            ],
            color: 0xFFFFE066,
            width: 0.025,
          ),
        ],
        note: 'Idea entendida',
      );
      final bytes = await PdfExport.build(
        title: book.title,
        source: pdf.document,
        annotations: await store.annotations(book.id),
        highlights: await store.pdfHighlights(book.id),
      );
      final output = File(p.join(root.path, 'exportado.pdf'));
      await output.writeAsBytes(bytes);
      final exported = await PdfDocument.openFile(output.path);
      try {
        expect(exported.pages, hasLength(3));
        expect(exported.pages[1].width, pdf.document.pages[0].width);
        expect(exported.pages[1].height, pdf.document.pages[0].height);
        final highlightedText = await exported.pages[1].loadText();
        expect(highlightedText?.fullText.trim(), 'Primera lectura.');
        final untouchedText = await exported.pages[2].loadText();
        expect(untouchedText?.fullText.trim(), 'Segunda pagina.');
        final originalImage = await pdf.document.pages[0].render(
          width: 306,
          height: 396,
        );
        final exportedImage = await exported.pages[1].render(
          width: 306,
          height: 396,
        );
        expect(originalImage, isNotNull);
        expect(exportedImage, isNotNull);
        try {
          var changedPixels = 0;
          for (
            var index = 0;
            index < originalImage!.pixels.length;
            index += 4
          ) {
            final differs =
                originalImage.pixels[index] != exportedImage!.pixels[index] ||
                originalImage.pixels[index + 1] !=
                    exportedImage.pixels[index + 1] ||
                originalImage.pixels[index + 2] !=
                    exportedImage.pixels[index + 2];
            if (differs) changedPixels++;
          }
          expect(changedPixels, lessThan(306 * 396 * 0.12));
        } finally {
          originalImage?.dispose();
          exportedImage?.dispose();
        }
      } finally {
        await exported.dispose();
      }
    } finally {
      await pdf?.close();
      await store.close();
      await root.delete(recursive: true);
    }
  });
}
