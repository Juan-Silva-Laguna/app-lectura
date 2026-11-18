import 'dart:async';
import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

import 'models.dart';

class LocalVoice {
  const LocalVoice(this.name, this.locale, this.identifier, this.quality);
  final String name;
  final String locale;
  final String? identifier;
  final String quality;

  String get key => identifier ?? '$locale/$name';
  String get label => '$name · $locale${quality.isEmpty ? '' : ' · $quality'}';

  static List<LocalVoice> parse(Object? raw, {required bool android}) {
    if (raw is! List) {
      throw const FormatException('El motor de voz no devolvió voces válidas.');
    }
    final voices = <LocalVoice>[];
    for (final entry in raw) {
      if (entry is! Map ||
          entry['name'] is! String ||
          entry['locale'] is! String) {
        throw const FormatException('El motor devolvió una voz no válida.');
      }
      final locale = entry['locale'] as String;
      if (locale.split(RegExp('[-_]')).first.toLowerCase() != 'es') continue;
      if (android &&
          (entry['network_required'] != '0' ||
              (entry['features']?.toString() ?? '').contains('notInstalled'))) {
        continue;
      }
      voices.add(
        LocalVoice(
          entry['name'] as String,
          locale,
          entry['identifier'] as String?,
          entry['quality']?.toString() ?? '',
        ),
      );
    }
    return voices;
  }
}

class Narrator {
  Narrator({FlutterTts? engine, bool? android, bool? ios})
    : _engine = engine ?? FlutterTts(),
      _android = android ?? Platform.isAndroid,
      _ios = ios ?? Platform.isIOS {
    _engine.setCompletionHandler(() => _finish(true));
    _engine.setCancelHandler(() => _finish(false));
    _engine.setPauseHandler(() => _finish(false));
    _engine.setErrorHandler((message) {
      final pending = _pending;
      if (pending != null && !pending.isCompleted) {
        pending.completeError(StateError('La narración falló: $message'));
      }
    });
    _engine.setProgressHandler((text, start, end, word) {
      final chunk = _chunk;
      if (chunk != null &&
          text == chunk.text &&
          start >= 0 &&
          end <= chunk.text.length) {
        _onWord?.call(chunk.start + start, chunk.start + end);
      }
    });
  }

  final FlutterTts _engine;
  final bool _android;
  final bool _ios;
  Completer<bool>? _pending;
  SpeechChunk? _chunk;
  void Function(int start, int end)? _onWord;
  int _generation = 0;
  bool _configured = false;
  bool _playing = false;
  Completer<void>? _idle;

  Future<List<LocalVoice>> voices() async =>
      LocalVoice.parse(await _engine.getVoices, android: _android);

  Future<void> configure(LocalVoice voice, double rate) async {
    await stop();
    _configured = false;
    if (_ios) {
      await _engine.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [],
        IosTextToSpeechAudioMode.spokenAudio,
      );
    }
    _check(
      await _engine.setVoice({
        'name': voice.name,
        'locale': voice.locale,
        if (voice.identifier != null) 'identifier': voice.identifier!,
      }),
      'seleccionar la voz',
    );
    _check(await _engine.setSpeechRate(rate), 'cambiar la velocidad');
    _configured = true;
  }

  void _check(Object? result, String operation) {
    if (result != 1) {
      throw StateError(
        'No se pudo $operation. Comprueba que la voz esté instalada.',
      );
    }
  }

  void _finish(bool completed) {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete(completed);
  }

  Future<bool> play(
    String text, {
    required int start,
    required void Function(int start, int end) onWord,
  }) async {
    if (!_configured) throw StateError('Selecciona primero una voz local.');
    if (_playing) throw StateError('Ya hay una narración en curso.');
    _playing = true;
    _idle = Completer<void>();
    final generation = _generation;
    _onWord = onWord;
    try {
      for (final chunk in speechChunks(readingText(text), start: start)) {
        if (generation != _generation) return false;
        if (chunk.text.trim().isEmpty) continue;
        _chunk = chunk;
        final pending = Completer<bool>();
        _pending = pending;
        // Attach the error listener before a native callback can arrive.
        final completion = pending.future
            .then<({bool completed, Object? error})>(
              (value) => (completed: value, error: null),
              onError: (Object error, StackTrace stack) =>
                  (completed: false, error: error),
            );
        _check(
          await _engine.speak(chunk.text, focus: true),
          'iniciar la narración',
        );
        final outcome = await completion;
        if (outcome.error != null) throw outcome.error!;
        if (!outcome.completed || generation != _generation) return false;
        onWord(chunk.end, chunk.end);
      }
      return generation == _generation;
    } finally {
      _pending = null;
      _chunk = null;
      _onWord = null;
      _playing = false;
      _idle?.complete();
      _idle = null;
    }
  }

  Future<void> stop() async {
    _generation++;
    _finish(false);
    _chunk = null;
    _onWord = null;
    await _engine.stop();
    await _idle?.future;
  }
}
