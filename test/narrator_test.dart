import 'dart:async';

import 'package:app_lectura/models.dart';
import 'package:app_lectura/narrator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reflow preserves offsets and speech chunks preserve every character',
    () {
      const raw = 'Primera línea.\r\nSegunda línea. 😊\n\nOtro párrafo.';
      final text = readingText(raw);
      expect(text.length, raw.length);
      expect(text.indexOf('Segunda'), raw.indexOf('Segunda'));
      final chunks = speechChunks(text, limit: 12).toList();
      expect(chunks.map((c) => c.text).join(), text);
      expect(chunks.every((c) => c.text.length <= 12), isTrue);
      for (final chunk in chunks) {
        expect(text.substring(chunk.start, chunk.end), chunk.text);
        final last = chunk.text.codeUnitAt(chunk.text.length - 1);
        expect(last >= 0xD800 && last <= 0xDBFF, isFalse);
      }
      expect(
        speechChunks(text, start: 16, limit: 12).map((c) => c.text).join(),
        text.substring(16),
      );
      expect(() => speechChunks(text, start: -1).toList(), throwsArgumentError);
    },
  );

  test('Android exposes only installed Spanish voices that explicitly work offline', () {
    final voices = LocalVoice.parse([
      {
        'name': 'Local',
        'locale': 'es-ES',
        'network_required': '0',
        'features': '',
      },
      {'name': 'Cloud', 'locale': 'es-ES', 'network_required': '1'},
      {
        'name': 'Missing',
        'locale': 'es-MX',
        'network_required': '0',
        'features': 'notInstalled',
      },
      {'name': 'Unknown', 'locale': 'es-CO'},
      {'name': 'English', 'locale': 'en-US', 'network_required': '0'},
    ], android: true);
    expect(voices.map((v) => v.name), ['Local']);
    expect(
      () => LocalVoice.parse('invalid response', android: true),
      throwsFormatException,
    );
  });

  const channel = MethodChannel('flutter_tts');
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> event(String method, [Object? arguments]) async {
    final completed = Completer<void>();
    messenger.handlePlatformMessage(
      'flutter_tts',
      codec.encodeMethodCall(MethodCall(method, arguments)),
      (_) => completed.complete(),
    );
    await completed.future;
  }

  test('native word progress maps back to source and stop releases pending playback', () async {
    final spoke = Completer<String>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'speak') {
        final args = call.arguments;
        spoke.complete(args is String ? args : (args as Map)['text'] as String);
      }
      return 1;
    });
    final narrator = Narrator(engine: FlutterTts(), android: true, ios: false);
    await narrator.configure(
      const LocalVoice('Local', 'es-ES', null, ''),
      0.45,
    );
    final offsets = <int>[];
    final playing = narrator.play(
      'Antes. Hola mundo.',
      start: 7,
      onWord: (start, end) => offsets.add(start),
    );
    final text = await spoke.future;
    await event('speak.onProgress', {
      'text': text,
      'start': '0',
      'end': '4',
      'word': 'Hola',
    });
    expect(offsets, [7]);
    await narrator.stop();
    expect(await playing, isFalse);
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'native speech failure is surfaced rather than reported as completion',
    () async {
      final spoke = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'speak') spoke.complete();
        return 1;
      });
      final narrator = Narrator(
        engine: FlutterTts(),
        android: true,
        ios: false,
      );
      await narrator.configure(
        const LocalVoice('Local', 'es-ES', null, ''),
        0.45,
      );
      final playing = narrator.play('Texto.', start: 0, onWord: (_, end) {});
      final failed = expectLater(playing, throwsStateError);
      await spoke.future;
      await event('speak.onError', 'Voice unavailable');
      await failed;
      await narrator.stop();
      messenger.setMockMethodCallHandler(channel, null);
    },
  );

  test('completed chunks advance without losing source offsets', () async {
    final spoken = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'speak') {
        final args = call.arguments;
        spoken.add(args is String ? args : (args as Map)['text'] as String);
        scheduleMicrotask(() => event('speak.onComplete'));
      }
      return 1;
    });
    final narrator = Narrator(engine: FlutterTts(), android: true, ios: false);
    await narrator.configure(
      const LocalVoice('Local', 'es-ES', null, ''),
      0.45,
    );
    final text = List.filled(200, 'Una frase completa. ').join();
    final offsets = <int>[];
    final completed = await narrator.play(
      text,
      start: 20,
      onWord: (start, end) => offsets.add(end),
    );
    expect(completed, isTrue);
    expect(spoken.length, greaterThan(1));
    expect(spoken.join(), text.substring(20));
    expect(offsets.last, text.length);
    await narrator.stop();
    messenger.setMockMethodCallHandler(channel, null);
  });
}
