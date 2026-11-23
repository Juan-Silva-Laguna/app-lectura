import 'package:material_ui/material_ui.dart';

import 'design_system/provit_design_system.dart';
import 'models.dart';

class ReflowPage extends StatefulWidget {
  const ReflowPage({
    super.key,
    required this.text,
    required this.settings,
    required this.annotations,
    required this.targetOffset,
    required this.onPosition,
    required this.onAnnotate,
    required this.onBookmark,
    this.spokenStart,
    this.spokenEnd,
  });

  final String text;
  final ReaderSettings settings;
  final List<Annotation> annotations;
  final int targetOffset;
  final int? spokenStart;
  final int? spokenEnd;
  final ValueChanged<int> onPosition;
  final void Function(int start, int end, bool withNote) onAnnotate;
  final ValueChanged<int> onBookmark;

  @override
  State<ReflowPage> createState() => _ReflowPageState();
}

class _ReflowPageState extends State<ReflowPage> {
  final _scroll = ScrollController();
  double _width = 0;
  bool _positionScheduled = false;
  bool _programmatic = false;

  @override
  void initState() {
    super.initState();
    _schedulePosition();
  }

  @override
  void didUpdateWidget(ReflowPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetOffset != widget.targetOffset ||
        oldWidget.settings != widget.settings ||
        (widget.spokenStart != null &&
            oldWidget.spokenStart != widget.spokenStart)) {
      _schedulePosition();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  TextStyle get _style => TextStyle(
    fontFamily: widget.settings.font == 'Sistema' ? null : widget.settings.font,
    fontSize: widget.settings.fontSize,
    height: widget.settings.lineHeight,
    color: widget.settings.theme == ReadingTheme.dark
        ? ProvitPalette.onDark
        : ProvitPalette.textPrimary,
  );

  TextPainter _painter() => TextPainter(
    text: TextSpan(text: readingText(widget.text), style: _style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: _width);

  void _schedulePosition() {
    if (_positionScheduled) return;
    _positionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _positionScheduled = false;
      if (!mounted || !_scroll.hasClients || _width <= 0) return;
      final painter = _painter();
      final offset = (widget.spokenStart ?? widget.targetOffset).clamp(
        0,
        widget.text.length,
      );
      final y = painter
          .getOffsetForCaret(TextPosition(offset: offset), Rect.zero)
          .dy;
      painter.dispose();
      if (widget.spokenStart != null &&
          y >= _scroll.offset &&
          y < _scroll.offset + _scroll.position.viewportDimension - 80) {
        return;
      }
      _programmatic = true;
      _scroll.jumpTo(y.clamp(0, _scroll.position.maxScrollExtent));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _programmatic = false;
      });
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollEndNotification &&
        !_programmatic &&
        widget.spokenStart == null &&
        _width > 0) {
      final painter = _painter();
      final offset = painter
          .getPositionForOffset(Offset(0, _scroll.offset))
          .offset;
      painter.dispose();
      widget.onPosition(offset);
    }
    return false;
  }

  List<TextSpan> _spans() {
    final text = readingText(widget.text);
    final boundaries = <int>{0, text.length};
    for (final annotation in widget.annotations) {
      boundaries.add(annotation.start.clamp(0, text.length));
      boundaries.add(annotation.end.clamp(0, text.length));
    }
    final spokenStart = widget.spokenStart;
    final spokenEnd = widget.spokenEnd;
    if (spokenStart != null && spokenEnd != null) {
      boundaries.add(spokenStart.clamp(0, text.length));
      boundaries.add(spokenEnd.clamp(0, text.length));
    }
    final sorted = boundaries.toList()..sort();
    return [
      for (var i = 0; i < sorted.length - 1; i++)
        TextSpan(
          text: text.substring(sorted[i], sorted[i + 1]),
          style: TextStyle(
            backgroundColor:
                spokenStart != null &&
                    spokenEnd != null &&
                    sorted[i] >= spokenStart &&
                    sorted[i] < spokenEnd
                ? ProvitPalette.spokenRange
                : widget.annotations.any(
                    (a) => sorted[i] >= a.start && sorted[i] < a.end,
                  )
                ? ProvitPalette.annotationRange
                : null,
            color:
                widget.annotations.any(
                      (a) => sorted[i] >= a.start && sorted[i] < a.end,
                    ) ||
                    (spokenStart != null &&
                        spokenEnd != null &&
                        sorted[i] >= spokenStart &&
                        sorted[i] < spokenEnd)
                ? ProvitPalette.textPrimary
                : null,
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth - 48;
      if (_width != width) {
        _width = width;
        _schedulePosition();
      }
      return NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 64),
          child: SelectableText.rich(
            TextSpan(style: _style, children: _spans()),
            textDirection: TextDirection.ltr,
            contextMenuBuilder: (context, editable) {
              final selection = editable.textEditingValue.selection;
              final valid = selection.isValid && !selection.isCollapsed;
              void annotate(bool note) {
                ContextMenuController.removeAny();
                widget.onAnnotate(selection.start, selection.end, note);
              }

              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: editable.contextMenuAnchors,
                buttonItems: [
                  if (valid) ...[
                    ContextMenuButtonItem(
                      label: 'Resaltar',
                      onPressed: () => annotate(false),
                    ),
                    ContextMenuButtonItem(
                      label: 'Anotar',
                      onPressed: () => annotate(true),
                    ),
                    ContextMenuButtonItem(
                      label: 'Guardar aquí',
                      onPressed: () {
                        ContextMenuController.removeAny();
                        widget.onBookmark(selection.start);
                      },
                    ),
                  ],
                  ...editable.contextMenuButtonItems,
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
