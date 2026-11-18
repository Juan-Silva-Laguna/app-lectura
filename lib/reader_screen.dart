import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import 'library_store.dart';
import 'models.dart';
import 'narrator.dart';
import 'pdf_book.dart';
import 'reader_settings_sheet.dart';
import 'reflow_page.dart';
import 'ui_helpers.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.store, required this.book});
  final LibraryStore store;
  final Book book;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  final _narrator = Narrator();
  PdfBook? _pdf;
  Object? _loadError;
  late ReadingPosition _reading = widget.book.reading;
  late ReadingPosition _audio = widget.book.audio;
  late int _page = _reading.page;
  int _targetOffset = 0;
  String _text = '';
  ReaderSettings _settings = const ReaderSettings();
  List<Annotation> _annotations = [];
  List<PdfOutlineNode> _outline = [];
  bool _loading = true;
  bool _original = false;
  bool _speaking = false;
  bool _preparingVoice = false;
  bool _pausedNarration = false;
  bool _closing = false;
  bool _allowPop = false;
  int _navigation = 0;
  int _playback = 0;
  int? _spokenStart;
  int? _spokenEnd;
  Timer? _saveAudioTimer;
  LocalVoice? _voice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    PdfBook? opened;
    try {
      opened = await PdfBook.open(widget.store, widget.book);
      final settings = await widget.store.settings();
      final notes = await widget.store.annotations(widget.book.id);
      final outline = await opened.document.loadOutline();
      final text = await opened.text(_reading.page);
      if (!mounted) {
        await opened.close();
        return;
      }
      setState(() {
        _pdf = opened;
        _settings = settings;
        _annotations = notes;
        _outline = outline;
        _text = text;
        _targetOffset = _reading.offset.clamp(0, text.length);
        _loading = false;
        _loadError = null;
      });
    } catch (error, stack) {
      if (opened != null) await opened.close();
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = error;
        });
        showFailure(context, error, stack);
      }
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stack) {
      if (mounted) {
        showFailure(context, error, stack);
      } else {
        reportFailure(error, stack);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_perform(_pause));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveAudioTimer?.cancel();
    // The normal back path awaits persistence before permitting disposal.
    unawaited(_perform(_narrator.stop));
    final pdf = _pdf;
    if (pdf != null) unawaited(_perform(pdf.close));
    super.dispose();
  }

  Future<void> _saveReading(int offset) async {
    _reading = ReadingPosition(page: _page, offset: offset);
    await widget.store.savePosition(widget.book, _reading);
  }

  Future<void> _flushAudio() async {
    _saveAudioTimer?.cancel();
    _saveAudioTimer = null;
    await widget.store.savePosition(widget.book, _audio, audio: true);
  }

  Future<void> _pause() async {
    _playback++;
    await _narrator.stop();
    await _flushAudio();
    if (mounted) {
      setState(() {
        _speaking = false;
        _spokenStart = null;
        _spokenEnd = null;
      });
    }
  }

  Future<void> _exit() async {
    if (_closing) return;
    _closing = true;
    try {
      await _pause();
      await widget.store.savePosition(widget.book, _reading);
      if (!mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (_) {
      _closing = false;
      rethrow;
    }
  }

  Future<void> _goTo(int page, {int offset = 0, bool forAudio = false}) async {
    if (page < 1 || page > widget.book.pageCount) {
      throw ArgumentError('La página no existe.');
    }
    final navigation = ++_navigation;
    if (!forAudio) {
      await _pause();
      _pausedNarration = false;
    }
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final text = await _pdf!.text(page);
      if (!mounted || navigation != _navigation) return;
      final target = offset.clamp(0, text.length);
      if (!forAudio) {
        final position = ReadingPosition(page: page, offset: target);
        await widget.store.savePosition(widget.book, position);
        _reading = position;
      }
      if (!mounted || navigation != _navigation) return;
      setState(() {
        _page = page;
        _text = text;
        _targetOffset = target;
        _spokenStart = null;
        _spokenEnd = null;
      });
    } finally {
      if (mounted && navigation == _navigation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _annotate(int start, int end, bool withNote) async {
    final page = _page;
    await _pause();
    if (!mounted) return;
    final note = withNote
        ? await textPrompt(
            context,
            title: 'Una idea para recordar',
            label: 'Tu nota sobre este fragmento',
            multiline: true,
          )
        : '';
    if (note == null) return;
    await widget.store.annotate(
      bookId: widget.book.id,
      page: page,
      start: start,
      end: end,
      note: note,
    );
    final annotations = await widget.store.annotations(widget.book.id);
    if (mounted) {
      setState(() => _annotations = annotations);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fragmento guardado en tus anotaciones.')),
      );
    }
  }

  Future<void> _bookmark(int offset) async {
    await _saveReading(offset);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retomarás desde este fragmento.')),
      );
    }
  }

  Future<void> _preferences() async {
    await _pause();
    if (!mounted) return;
    final settings = await showModalBottomSheet<ReaderSettings>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ReaderSettingsSheet(settings: _settings),
    );
    if (settings == null) return;
    await widget.store.saveSettings(settings);
    if (mounted) {
      setState(() {
        _settings = settings;
        _targetOffset = _reading.page == _page ? _reading.offset : 0;
      });
    }
  }

  Future<bool> _chooseVoice() async {
    await _pause();
    final voices = await _narrator.voices();
    if (!mounted) return false;
    final selected = await showModalBottomSheet<LocalVoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Tu voz de lectura',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Voces en español disponibles en el sistema. En Android se '
              'excluyen las que requieren red o no están instaladas.\n\n'
              'En iPhone descarga una voz desde Ajustes > Accesibilidad > '
              'Contenido leído o Lectura y voz > Voces. En Android, desde '
              'los ajustes de síntesis de voz. Regresa y abre esta lista de nuevo.\n\n'
              'Prueba siempre la voz en modo avión antes de depender de ella.',
            ),
            const SizedBox(height: 16),
            if (voices.isEmpty)
              const Text(
                'No hay voces locales en español disponibles. '
                'Instala una en los ajustes del dispositivo.',
              ),
            for (final voice in voices)
              ListTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                title: Text(voice.label),
                onTap: () => Navigator.pop(context, voice),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return false;
    final settings = _settings.copyWith(
      voiceName: selected.key,
      voiceLocale: selected.locale,
    );
    await widget.store.saveSettings(settings);
    if (mounted) {
      setState(() {
        _settings = settings;
        _voice = selected;
      });
    }
    return true;
  }

  Future<void> _listen({bool resume = false}) async {
    if (_preparingVoice) return;
    if (_speaking) {
      await _pause();
      return;
    }
    setState(() => _preparingVoice = true);
    try {
      if (_voice == null && _settings.voiceName != null) {
        final voices = await _narrator.voices();
        for (final voice in voices) {
          if (voice.key == _settings.voiceName) _voice = voice;
        }
      }
      if (_voice == null && !await _chooseVoice()) return;
      if (!mounted) return;
      await _narrator.configure(_voice!, _settings.speechRate);
    } finally {
      if (mounted) setState(() => _preparingVoice = false);
    }
    if (!mounted ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final position = resume || _pausedNarration
        ? _audio
        : ReadingPosition(
            page: _page,
            offset: _reading.page == _page ? _reading.offset : 0,
          );
    final playback = ++_playback;
    setState(() {
      _speaking = true;
      _pausedNarration = true;
      _original = false;
    });
    try {
      for (var page = position.page; page <= widget.book.pageCount; page++) {
        if (!mounted || playback != _playback) return;
        final start = page == position.page ? position.offset : 0;
        await _goTo(page, offset: start, forAudio: true);
        if (!mounted || playback != _playback) return;
        if (_text.trim().isEmpty) {
          throw StateError(
            'La página $page no contiene texto extraíble. '
            'Puedes verla en PDF original o pasar a la siguiente.',
          );
        }
        _audio = ReadingPosition(
          page: page,
          offset: start.clamp(0, _text.length),
        );
        await _flushAudio();
        final completed = await _narrator.play(
          _text,
          start: _audio.offset,
          onWord: (start, end) {
            if (!mounted || playback != _playback) return;
            _audio = ReadingPosition(page: page, offset: start);
            setState(() {
              _spokenStart = start;
              _spokenEnd = end;
            });
            _saveAudioTimer ??= Timer(const Duration(seconds: 1), () {
              unawaited(_perform(_flushAudio));
            });
          },
        );
        if (!completed || playback != _playback) return;
        _audio = ReadingPosition(page: page, offset: _text.length);
        await _flushAudio();
      }
      _pausedNarration = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Llegaste al final del libro.')),
        );
      }
    } finally {
      if (playback == _playback) await _pause();
    }
  }

  Future<void> _jump() async {
    await _pause();
    if (!mounted) return;
    final value = await textPrompt(
      context,
      title: 'Ir a una página',
      label: 'Página entre 1 y ${widget.book.pageCount}',
      initial: '$_page',
    );
    if (value == null) return;
    final page = int.tryParse(value);
    if (page == null || page < 1 || page > widget.book.pageCount) {
      throw ArgumentError('Escribe un número de página válido.');
    }
    await _goTo(page);
  }

  Iterable<Widget> _outlineTiles(List<PdfOutlineNode> nodes, int depth) sync* {
    for (final node in nodes) {
      yield ListTile(
        contentPadding: EdgeInsets.only(left: 16 + depth * 12, right: 16),
        title: Text(node.title),
        subtitle: node.dest == null
            ? null
            : Text('Página ${node.dest!.pageNumber}'),
        enabled: node.dest != null,
        onTap: node.dest == null
            ? null
            : () => Navigator.pop(context, node.dest!.pageNumber),
      );
      yield* _outlineTiles(node.children, depth + 1);
    }
  }

  Future<void> _chapters() async {
    await _pause();
    if (!mounted) return;
    final page = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          children: [
            const ListTile(title: Text('Índice del documento')),
            if (_outline.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Este PDF no incluye un índice navegable. '
                  'Usa el número de página para desplazarte.',
                ),
              ),
            ..._outlineTiles(_outline, 0),
          ],
        ),
      ),
    );
    if (page != null) await _goTo(page);
  }

  Future<void> _notes() async {
    await _pause();
    if (!mounted) return;
    final selected = await showModalBottomSheet<Annotation>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          children: [
            const ListTile(title: Text('Tus fragmentos y notas')),
            if (_annotations.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Mantén pulsado un fragmento en Lectura y elige Resaltar o Anotar.',
                ),
              ),
            for (final annotation in _annotations)
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: Text(
                  annotation.quote,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Página ${annotation.page}'
                  '${annotation.note.isEmpty ? '' : '\n${annotation.note}'}',
                ),
                onTap: () => Navigator.pop(context, annotation),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Fragmento guardado'),
        children: [
          for (final (value, label) in [
            ('go', 'Ir al fragmento'),
            ('edit', 'Editar nota'),
            ('delete', 'Eliminar anotación'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text(label),
            ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'go') {
      setState(() => _original = false);
      await _goTo(selected.page, offset: selected.start);
    } else if (action == 'edit') {
      final note = await textPrompt(
        context,
        title: 'Editar nota',
        label: 'Tu nota',
        initial: selected.note,
        multiline: true,
        allowEmpty: true,
      );
      if (note != null) await widget.store.updateNote(selected, note);
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Eliminar este fragmento y su nota?'),
          content: const Text('Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      if (confirm == true) await widget.store.removeAnnotation(selected.id);
    }
    final annotations = await widget.store.annotations(widget.book.id);
    if (mounted) setState(() => _annotations = annotations);
  }

  Color get _background => switch (_settings.theme) {
    ReadingTheme.paper => const Color(0xFFFEFDF9),
    ReadingTheme.sepia => const Color(0xFFF3EADA),
    ReadingTheme.dark => const Color(0xFF1C2421),
  };

  @override
  Widget build(BuildContext context) {
    final ready = !_loading && _pdf != null && _loadError == null;
    final dark = _settings.theme == ReadingTheme.dark;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_perform(_exit));
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF365C4D),
            brightness: dark ? Brightness.dark : Brightness.light,
            surface: _background,
          ),
          scaffoldBackgroundColor: _background,
        ),
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Volver a la biblioteca',
              onPressed: () => _perform(_exit),
              icon: const Icon(Icons.arrow_back),
            ),
            title: Text(widget.book.title),
            actions: [
              IconButton(
                tooltip: 'Anotaciones',
                onPressed: ready ? () => _perform(_notes) : null,
                icon: const Icon(Icons.bookmarks_outlined),
              ),
              IconButton(
                tooltip: 'Preferencias de lectura',
                onPressed: ready ? () => _perform(_preferences) : null,
                icon: const Icon(Icons.text_fields),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones del libro',
                enabled: ready,
                onSelected: (value) => _perform(() async {
                  switch (value) {
                    case 'voice':
                      await _chooseVoice();
                    case 'chapters':
                      await _chapters();
                    case 'resume':
                      await _listen(resume: true);
                    case 'reading':
                      await _goTo(_reading.page, offset: _reading.offset);
                  }
                }),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'chapters',
                    child: Text('Índice / capítulos'),
                  ),
                  PopupMenuItem(
                    value: 'voice',
                    child: Text('Elegir voz local'),
                  ),
                  PopupMenuItem(
                    value: 'resume',
                    child: Text('Retomar narración'),
                  ),
                  PopupMenuItem(
                    value: 'reading',
                    child: Text('Volver a mi lectura'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Lectura'),
                      icon: Icon(Icons.menu_book),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('PDF original'),
                      icon: Icon(Icons.picture_as_pdf_outlined),
                    ),
                  ],
                  selected: {_original},
                  onSelectionChanged: ready
                      ? (selection) => _perform(() async {
                          await _pause();
                          if (mounted) {
                            setState(() {
                              _original = selection.single;
                              _targetOffset =
                                  _pausedNarration && _audio.page == _page
                                  ? _audio.offset
                                  : _reading.page == _page
                                  ? _reading.offset
                                  : 0;
                            });
                          }
                        })
                      : null,
                ),
              ),
              Expanded(
                child: _loadError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('No se pudo abrir este libro: $_loadError'),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _loadError = null;
                                    _loading = true;
                                  });
                                  unawaited(_load());
                                },
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : !ready
                    ? const Center(child: CircularProgressIndicator())
                    : _original
                    ? InteractiveViewer(
                        key: ValueKey('pdf-$_page'),
                        minScale: 1,
                        maxScale: 5,
                        child: Center(
                          child: PdfPageView(
                            document: _pdf!.document,
                            pageNumber: _page,
                          ),
                        ),
                      )
                    : _text.trim().isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Esta página no contiene texto extraíble. '
                            'Puede ser una portada, imagen o página escaneada. '
                            'Ábrela en PDF original o pasa a la siguiente. '
                            'El reconocimiento OCR se añadirá en otra etapa.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ReflowPage(
                        key: ValueKey('text-$_page'),
                        text: _text,
                        settings: _settings,
                        annotations: _annotations
                            .where((a) => a.page == _page)
                            .toList(),
                        targetOffset: _targetOffset,
                        spokenStart: _spokenStart,
                        spokenEnd: _spokenEnd,
                        onPosition: (offset) {
                          if (!_speaking) {
                            unawaited(_perform(() => _saveReading(offset)));
                          }
                        },
                        onAnnotate: (start, end, note) => unawaited(
                          _perform(() => _annotate(start, end, note)),
                        ),
                        onBookmark: (offset) =>
                            unawaited(_perform(() => _bookmark(offset))),
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Página anterior',
                        onPressed: ready && _page > 1
                            ? () => _perform(() => _goTo(_page - 1))
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      TextButton(
                        onPressed: ready ? () => _perform(_jump) : null,
                        child: Text('$_page / ${widget.book.pageCount}'),
                      ),
                      IconButton(
                        tooltip: 'Página siguiente',
                        onPressed: ready && _page < widget.book.pageCount
                            ? () => _perform(() => _goTo(_page + 1))
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                      FilledButton.icon(
                        onPressed:
                            ready && !_preparingVoice && _text.trim().isNotEmpty
                            ? () => _perform(_listen)
                            : null,
                        icon: Icon(_speaking ? Icons.pause : Icons.headphones),
                        label: Text(
                          _preparingVoice
                              ? 'Preparando…'
                              : _speaking
                              ? 'Pausar'
                              : _pausedNarration
                              ? 'Continuar'
                              : 'Escuchar',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
