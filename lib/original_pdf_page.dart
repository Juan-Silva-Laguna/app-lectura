import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import 'models.dart';

class OriginalPdfPage extends StatefulWidget {
  const OriginalPdfPage({
    super.key,
    required this.document,
    required this.pageNumber,
    required this.highlights,
    required this.draftStrokes,
    required this.highlighting,
    required this.color,
    required this.strokeWidth,
    required this.onStroke,
    required this.onRecolor,
  });

  final PdfDocument document;
  final int pageNumber;
  final List<PdfHighlight> highlights;
  final List<PdfHighlightStroke> draftStrokes;
  final bool highlighting;
  final Color color;
  final double strokeWidth;
  final ValueChanged<PdfHighlightStroke> onStroke;
  final ValueChanged<PdfHighlight> onRecolor;

  @override
  State<OriginalPdfPage> createState() => _OriginalPdfPageState();
}

class _OriginalPdfPageState extends State<OriginalPdfPage> {
  final List<PdfHighlightPoint> _current = [];
  Offset? _pointerStart;

  void _begin(Offset position, Size size) {
    _pointerStart = position;
    setState(() {
      _current
        ..clear()
        ..add(_normalize(position, size));
    });
  }

  void _move(Offset position, Size size) {
    final point = _normalize(position, size);
    final previous = _current.lastOrNull;
    if (previous != null &&
        math.sqrt(
              math.pow(previous.x - point.x, 2) +
                  math.pow(previous.y - point.y, 2),
            ) <
            0.001) {
      return;
    }
    setState(() => _current.add(point));
  }

  void _finish(Offset position, Size size) {
    final moved =
        _pointerStart != null && (position - _pointerStart!).distance >= 3;
    _pointerStart = null;
    if (!moved) {
      setState(_current.clear);
      _recolor(position, size);
      return;
    }
    final points = List<PdfHighlightPoint>.of(_current);
    setState(_current.clear);
    if (points.isEmpty) return;
    widget.onStroke(
      PdfHighlightStroke(
        points: points,
        color: widget.color.toARGB32(),
        width: widget.strokeWidth,
      ),
    );
  }

  PdfHighlightPoint _normalize(Offset position, Size size) => PdfHighlightPoint(
    (position.dx / size.width).clamp(0, 1),
    (position.dy / size.height).clamp(0, 1),
  );

  void _recolor(Offset position, Size size) {
    final point = _normalize(position, size);
    for (final highlight in widget.highlights.reversed) {
      if (highlight.left <= point.x &&
          highlight.right >= point.x &&
          highlight.top <= point.y &&
          highlight.bottom >= point.y) {
        widget.onRecolor(highlight);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => PdfPageView(
    document: widget.document,
    pageNumber: widget.pageNumber,
    decorationBuilder: (context, pageSize, page, pageImage) => Align(
      child: AspectRatio(
        aspectRatio: pageSize.width / pageSize.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: widget.highlighting
                  ? (event) => _begin(event.localPosition, size)
                  : null,
              onPointerMove: widget.highlighting
                  ? (event) => _move(event.localPosition, size)
                  : null,
              onPointerUp: widget.highlighting
                  ? (event) => _finish(event.localPosition, size)
                  : null,
              onPointerCancel: widget.highlighting
                  ? (_) {
                      _pointerStart = null;
                      setState(_current.clear);
                    }
                  : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: Colors.white,
                    child: pageImage ?? const SizedBox.expand(),
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _PdfHighlightPainter(
                        highlights: widget.highlights,
                        draftStrokes: widget.draftStrokes,
                        current: _current,
                        currentColor: widget.color,
                        currentWidth: widget.strokeWidth,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _PdfHighlightPainter extends CustomPainter {
  const _PdfHighlightPainter({
    required this.highlights,
    required this.draftStrokes,
    required this.current,
    required this.currentColor,
    required this.currentWidth,
  });

  final List<PdfHighlight> highlights;
  final List<PdfHighlightStroke> draftStrokes;
  final List<PdfHighlightPoint> current;
  final Color currentColor;
  final double currentWidth;

  void _paintStroke(Canvas canvas, Size size, PdfHighlightStroke stroke) {
    if (stroke.points.isEmpty) return;
    final paint = Paint()
      ..color = Color(stroke.color).withValues(alpha: 0.36)
      ..strokeWidth = math.min(size.width, size.height) * stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(
        stroke.points.first.x * size.width,
        stroke.points.first.y * size.height,
      );
    for (final point in stroke.points.skip(1)) {
      path.lineTo(point.x * size.width, point.y * size.height);
    }
    if (stroke.points.length == 1) {
      canvas.drawCircle(
        Offset(
          stroke.points.first.x * size.width,
          stroke.points.first.y * size.height,
        ),
        paint.strokeWidth / 2,
        paint..style = PaintingStyle.fill,
      );
    } else {
      canvas.drawPath(path, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final highlight in highlights) {
      if (highlight.strokes.isEmpty) {
        canvas.drawRect(
          Rect.fromLTRB(
            highlight.left * size.width,
            highlight.top * size.height,
            highlight.right * size.width,
            highlight.bottom * size.height,
          ),
          Paint()..color = Color(highlight.color).withValues(alpha: 0.36),
        );
        continue;
      }
      for (final stroke in highlight.strokes) {
        _paintStroke(canvas, size, stroke);
      }
    }
    for (final stroke in draftStrokes) {
      _paintStroke(canvas, size, stroke);
    }
    if (current.isNotEmpty) {
      _paintStroke(
        canvas,
        size,
        PdfHighlightStroke(
          points: current,
          color: currentColor.toARGB32(),
          width: currentWidth,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PdfHighlightPainter oldDelegate) =>
      oldDelegate.highlights != highlights ||
      oldDelegate.draftStrokes != draftStrokes ||
      oldDelegate.current.length != current.length ||
      oldDelegate.currentColor != currentColor ||
      oldDelegate.currentWidth != currentWidth;
}
