import 'dart:convert';
import 'dart:math' as math;

class ReadingPosition {
  const ReadingPosition({this.page = 1, this.offset = 0});

  final int page;
  final int offset;
}

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.fileName,
    required this.pageCount,
    required this.reading,
    required this.audio,
  });

  factory Book.fromMap(Map<String, Object?> row) => Book(
    id: row['id'] as String,
    title: row['title'] as String,
    fileName: row['file_name'] as String,
    pageCount: row['page_count'] as int,
    reading: ReadingPosition(
      page: row['read_page'] as int,
      offset: row['read_offset'] as int,
    ),
    audio: ReadingPosition(
      page: row['audio_page'] as int,
      offset: row['audio_offset'] as int,
    ),
  );

  final String id;
  final String title;
  final String fileName;
  final int pageCount;
  final ReadingPosition reading;
  final ReadingPosition audio;
}

class Annotation {
  const Annotation({
    required this.id,
    required this.bookId,
    required this.page,
    required this.start,
    required this.end,
    required this.quote,
    required this.note,
    required this.contextBefore,
    required this.contextAfter,
  });

  factory Annotation.fromMap(Map<String, Object?> row) => Annotation(
    id: row['id'] as String,
    bookId: row['book_id'] as String,
    page: row['page'] as int,
    start: row['start_offset'] as int,
    end: row['end_offset'] as int,
    quote: row['quote'] as String,
    note: row['note'] as String,
    contextBefore: row['context_before'] as String,
    contextAfter: row['context_after'] as String,
  );

  final String id;
  final String bookId;
  final int page;
  final int start;
  final int end;
  final String quote;
  final String note;
  final String contextBefore;
  final String contextAfter;
}

class PdfHighlight {
  const PdfHighlight({
    required this.id,
    required this.bookId,
    required this.page,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.color,
    required this.strokes,
    required this.note,
    required this.createdAt,
  });

  factory PdfHighlight.fromMap(Map<String, Object?> row) => PdfHighlight(
    id: row['id'] as String,
    bookId: row['book_id'] as String,
    page: row['page'] as int,
    left: (row['left'] as num).toDouble(),
    top: (row['top'] as num).toDouble(),
    right: (row['right'] as num).toDouble(),
    bottom: (row['bottom'] as num).toDouble(),
    color: row['color'] as int,
    strokes: ((jsonDecode((row['strokes'] as String?) ?? '[]') as List)
        .map(
          (value) => PdfHighlightStroke.fromJson(
            Map<String, Object?>.from(value as Map),
          ),
        )
        .toList()),
    note: (row['note'] as String?) ?? '',
    createdAt: row['created_at'] as int,
  );

  final String id;
  final String bookId;
  final int page;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final int color;
  final List<PdfHighlightStroke> strokes;
  final String note;
  final int createdAt;
}

class PdfHighlightPoint {
  const PdfHighlightPoint(this.x, this.y);

  factory PdfHighlightPoint.fromJson(Map<String, Object?> json) =>
      PdfHighlightPoint(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      );

  final double x;
  final double y;

  Map<String, Object?> toJson() => {'x': x, 'y': y};
}

class PdfHighlightStroke {
  const PdfHighlightStroke({
    required this.points,
    required this.color,
    required this.width,
  });

  factory PdfHighlightStroke.fromJson(Map<String, Object?> json) =>
      PdfHighlightStroke(
        points: (json['points'] as List)
            .map(
              (point) => PdfHighlightPoint.fromJson(
                Map<String, Object?>.from(point as Map),
              ),
            )
            .toList(),
        color: json['color'] as int,
        width: (json['width'] as num).toDouble(),
      );

  final List<PdfHighlightPoint> points;
  final int color;
  final double width;

  Map<String, Object?> toJson() => {
    'points': points.map((point) => point.toJson()).toList(),
    'color': color,
    'width': width,
  };
}

enum ReadingTheme { paper, sepia, dark }

class ReaderSettings {
  const ReaderSettings({
    this.font = 'Sistema',
    this.fontSize = 21,
    this.lineHeight = 1.65,
    this.theme = ReadingTheme.sepia,
    this.speechRate = 0.45,
    this.voiceName,
    this.voiceLocale,
  });

  factory ReaderSettings.fromMap(Map<String, Object?> row) => ReaderSettings(
    font: row['font'] as String,
    fontSize: (row['font_size'] as num).toDouble(),
    lineHeight: (row['line_height'] as num).toDouble(),
    theme: ReadingTheme.values.byName(row['theme'] as String),
    speechRate: (row['speech_rate'] as num).toDouble(),
    voiceName: row['voice_name'] as String?,
    voiceLocale: row['voice_locale'] as String?,
  );

  final String font;
  final double fontSize;
  final double lineHeight;
  final ReadingTheme theme;
  final double speechRate;
  final String? voiceName;
  final String? voiceLocale;

  ReaderSettings copyWith({
    String? font,
    double? fontSize,
    double? lineHeight,
    ReadingTheme? theme,
    double? speechRate,
    String? voiceName,
    String? voiceLocale,
  }) => ReaderSettings(
    font: font ?? this.font,
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    theme: theme ?? this.theme,
    speechRate: speechRate ?? this.speechRate,
    voiceName: voiceName ?? this.voiceName,
    voiceLocale: voiceLocale ?? this.voiceLocale,
  );

  Map<String, Object?> toMap() => {
    'font': font,
    'font_size': fontSize,
    'line_height': lineHeight,
    'theme': theme.name,
    'speech_rate': speechRate,
    'voice_name': voiceName,
    'voice_locale': voiceLocale,
  };
}

class SpeechChunk {
  const SpeechChunk(this.start, this.text);
  final int start;
  final String text;
  int get end => start + text.length;
}

// Preserve UTF-16 offsets shared by PDF text, selections and native TTS.
String readingText(String raw) => raw
    .replaceAll('\r', ' ')
    .replaceAllMapped(RegExp(r'(?<!\n)\n(?!\n)'), (_) => ' ');

Iterable<SpeechChunk> speechChunks(
  String text, {
  int start = 0,
  int limit = 1500,
}) sync* {
  if (start < 0 || start > text.length || limit < 2) {
    throw ArgumentError('Rango de narración no válido.');
  }
  var cursor = start;
  while (cursor < text.length) {
    var end = math.min(cursor + limit, text.length);
    if (end < text.length) {
      final candidate = text.substring(cursor, end);
      final sentences = RegExp(r'[.!?;]\s').allMatches(candidate).toList();
      final boundary = sentences.isNotEmpty
          ? sentences.last.end
          : candidate.lastIndexOf(RegExp(r'\s')) + 1;
      if (boundary > 0) end = cursor + boundary;
      final last = text.codeUnitAt(end - 1);
      if (last >= 0xD800 && last <= 0xDBFF) end--;
    }
    yield SpeechChunk(cursor, text.substring(cursor, end));
    cursor = end;
  }
}
