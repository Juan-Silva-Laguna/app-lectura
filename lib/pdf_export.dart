import 'dart:ffi';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import 'models.dart';

class PdfExport {
  static final pdfium.PDFium _pdfium = pdfium.getPdfium();

  static Future<Uint8List> build({
    required String title,
    required pdfrx.PdfDocument source,
    required List<Annotation> annotations,
    required List<PdfHighlight> highlights,
    void Function(int completed, int total)? onProgress,
  }) async {
    final fontData = await rootBundle.load('assets/fonts/Lora.ttf');
    final font = pw.Font.ttf(fontData);
    final temporaryDocuments = <pdfrx.PdfDocument>[];
    final output = await pdfrx.PdfDocument.createNew(
      sourceName: '$title-anotado.pdf',
    );
    try {
      final notes = await pdfrx.PdfDocument.openData(
        await _notesPdf(
          title: title,
          annotations: annotations,
          highlights: highlights,
          font: font,
        ),
        sourceName: 'notas.pdf',
      );
      temporaryDocuments.add(notes);
      final notePageCount = notes.pages.length;
      output.pages = [...notes.pages, ...source.pages];
      final assembled = await output.assemble();
      if (!assembled) throw StateError('No se pudo preparar el PDF exportado.');

      final highlightsByPage = <int, List<PdfHighlight>>{};
      for (final highlight in highlights) {
        highlightsByPage.putIfAbsent(highlight.page, () => []).add(highlight);
      }
      await output.useNativeDocumentHandle((nativeDocumentHandle) {
        final document = pdfium.FPDF_DOCUMENT.fromAddress(nativeDocumentHandle);
        for (final entry in highlightsByPage.entries) {
          _addHighlightsToPage(
            document,
            notePageCount + entry.key - 1,
            source.pages[entry.key - 1].width,
            source.pages[entry.key - 1].height,
            entry.value,
          );
          onProgress?.call(entry.key, source.pages.length);
        }
      });
      await output.reloadPages(
        pageNumbersToReload: highlightsByPage.keys
            .map((page) => notePageCount + page)
            .toList(),
      );
      for (var page = 1; page <= source.pages.length; page++) {
        if (!highlightsByPage.containsKey(page)) {
          onProgress?.call(page, source.pages.length);
        }
      }
      return await output.encodePdf(incremental: true);
    } finally {
      for (final document in temporaryDocuments) {
        await document.dispose();
      }
      await output.dispose();
    }
  }

  static void _addHighlightsToPage(
    pdfium.FPDF_DOCUMENT document,
    int pageIndex,
    double pageWidth,
    double pageHeight,
    List<PdfHighlight> highlights,
  ) {
    final page = _pdfium.FPDF_LoadPage(document, pageIndex);
    if (page == nullptr) {
      throw StateError('No se pudo preparar la página ${pageIndex + 1}.');
    }
    try {
      for (final highlight in highlights) {
        if (highlight.strokes.isEmpty) {
          _insertLegacyRect(page, pageWidth, pageHeight, highlight);
          continue;
        }
        for (final stroke in highlight.strokes) {
          _insertStroke(page, pageWidth, pageHeight, stroke);
        }
      }
      if (_pdfium.FPDFPage_GenerateContent(page) == 0) {
        throw StateError('No se pudieron guardar los resaltados del PDF.');
      }
    } finally {
      _pdfium.FPDF_ClosePage(page);
    }
  }

  static void _insertStroke(
    pdfium.FPDF_PAGE page,
    double pageWidth,
    double pageHeight,
    PdfHighlightStroke stroke,
  ) {
    if (stroke.points.isEmpty) return;
    final points = stroke.points;
    final first = points.first;
    final path = _pdfium.FPDFPageObj_CreateNewPath(
      first.x * pageWidth,
      (1 - first.y) * pageHeight,
    );
    if (path == nullptr) throw StateError('No se pudo crear un trazo PDF.');
    for (final point in points.skip(1)) {
      _pdfium.FPDFPath_LineTo(
        path,
        point.x * pageWidth,
        (1 - point.y) * pageHeight,
      );
    }
    final color = stroke.color;
    _pdfium.FPDFPageObj_SetStrokeColor(
      path,
      color >> 16 & 0xff,
      color >> 8 & 0xff,
      color & 0xff,
      82,
    );
    _pdfium.FPDFPageObj_SetStrokeWidth(
      path,
      stroke.width * (pageWidth < pageHeight ? pageWidth : pageHeight),
    );
    _pdfium.FPDFPageObj_SetLineCap(path, pdfium.FPDF_LINECAP_ROUND);
    _pdfium.FPDFPageObj_SetLineJoin(path, pdfium.FPDF_LINEJOIN_ROUND);
    _pdfium.FPDFPath_SetDrawMode(path, pdfium.FPDF_FILLMODE_NONE, 1);
    if (_pdfium.FPDFPage_InsertObject(page, path) == 0) {
      _pdfium.FPDFPageObj_Destroy(path);
      throw StateError('No se pudo insertar un trazo en el PDF.');
    }
  }

  static void _insertLegacyRect(
    pdfium.FPDF_PAGE page,
    double pageWidth,
    double pageHeight,
    PdfHighlight highlight,
  ) {
    final rect = _pdfium.FPDFPageObj_CreateNewRect(
      highlight.left * pageWidth,
      (1 - highlight.bottom) * pageHeight,
      (highlight.right - highlight.left) * pageWidth,
      (highlight.bottom - highlight.top) * pageHeight,
    );
    if (rect == nullptr) {
      throw StateError('No se pudo crear un resaltado PDF.');
    }
    _pdfium.FPDFPageObj_SetFillColor(
      rect,
      highlight.color >> 16 & 0xff,
      highlight.color >> 8 & 0xff,
      highlight.color & 0xff,
      82,
    );
    _pdfium.FPDFPath_SetDrawMode(rect, pdfium.FPDF_FILLMODE_WINDING, 0);
    if (_pdfium.FPDFPage_InsertObject(page, rect) == 0) {
      _pdfium.FPDFPageObj_Destroy(rect);
      throw StateError('No se pudo insertar un resaltado en el PDF.');
    }
  }

  static Future<Uint8List> _notesPdf({
    required String title,
    required List<Annotation> annotations,
    required List<PdfHighlight> highlights,
    required pw.Font font,
  }) {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Text(title, style: pw.TextStyle(font: font, fontSize: 24)),
          pw.SizedBox(height: 8),
          pw.Text(
            'Fragmentos, resaltados y notas',
            style: pw.TextStyle(font: font, fontSize: 13),
          ),
          pw.SizedBox(height: 24),
          if (annotations.isEmpty && highlights.isEmpty)
            pw.Text(
              'Este libro todavía no tiene anotaciones.',
              style: pw.TextStyle(font: font),
            ),
          for (final annotation in annotations)
            _noteBlock(
              font: font,
              label: 'Pág. ${annotation.page} · Lectura',
              text: annotation.note.isEmpty
                  ? annotation.quote
                  : annotation.note,
              quote: annotation.note.isEmpty ? null : annotation.quote,
            ),
          for (final highlight in highlights)
            _noteBlock(
              font: font,
              label: 'Pág. ${highlight.page} · PDF original',
              text: highlight.note.isEmpty
                  ? 'Resaltado del PDF'
                  : highlight.note,
            ),
        ],
      ),
    );
    return document.save();
  }

  static pw.Widget _noteBlock({
    required pw.Font font,
    required String label,
    required String text,
    String? quote,
  }) => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      border: pw.Border.all(color: PdfColors.grey300),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(text, style: pw.TextStyle(font: font, fontSize: 12)),
        if (quote != null) ...[
          pw.SizedBox(height: 5),
          pw.Text(
            '"$quote"',
            style: pw.TextStyle(
              font: font,
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ],
    ),
  );
}
