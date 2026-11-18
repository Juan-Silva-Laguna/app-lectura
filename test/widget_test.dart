import 'dart:io';

import 'package:app_lectura/library_store.dart';
import 'package:app_lectura/main.dart';
import 'package:app_lectura/models.dart';
import 'package:app_lectura/reflow_page.dart';
import 'package:app_lectura/ui_helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('empty library guides import without a login or sample books', (
    tester,
  ) async {
    sqfliteFfiInit();
    late Directory root;
    late LibraryStore store;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('lectura_widget_test_');
      store = await LibraryStore.open(root, factory: databaseFactoryFfi);
    });
    await tester.pumpWidget(LecturaApp(store: store));
    await tester.runAsync(
      () async => await Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Importar PDF'), findsOneWidget);
    expect(find.text('Tu próxima lectura empieza aquí'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await store.close();
      await root.delete(recursive: true);
    });
  });

  testWidgets('name dialog rejects whitespace without closing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  textPrompt(context, title: 'Importar', label: 'Nombre'),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Este campo no puede estar vacío.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets(
    'reflow restores an anchor after font change at narrow screen size',
    (tester) async {
      tester.view.physicalSize = const Size(375, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final text = List.generate(
        100,
        (i) => 'Línea $i con texto para leer. ',
      ).join();
      var lastPosition = 0;
      Future<void> build(ReaderSettings settings) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReflowPage(
              text: text,
              settings: settings,
              annotations: const [],
              targetOffset: 1200,
              onPosition: (offset) => lastPosition = offset,
              onAnnotate: (_, end, note) {},
              onBookmark: (_) {},
            ),
          ),
        ),
      );
      await build(const ReaderSettings());
      await tester.pumpAndSettle();
      final before = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      expect(before, greaterThan(0));
      await build(const ReaderSettings(fontSize: 30, font: 'Atkinson'));
      await tester.pumpAndSettle();
      final after = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      expect(after, greaterThan(before));
      final editable = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      final caret = editable.renderEditable.getLocalRectForCaret(
        const TextPosition(offset: 1200),
      );
      final caretY = editable.renderEditable.localToGlobal(caret.topLeft).dy;
      expect(
        caretY,
        inInclusiveRange(-1, 80),
        reason: 'The saved character must remain at the top of the viewport',
      );
      expect(
        lastPosition,
        0,
        reason: 'Restoration must not overwrite the saved anchor',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
