import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'library_screen.dart';
import 'library_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final font in ['Lora', 'Atkinson']) {
      yield LicenseEntryWithLineBreaks([
        font,
      ], await rootBundle.loadString('assets/fonts/$font-OFL.txt'));
    }
  });
  runApp(const LecturaApp());
}

class LecturaApp extends StatelessWidget {
  const LecturaApp({super.key, this.store});
  final LibraryStore? store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Entre líneas',
    debugShowCheckedModeBanner: false,
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF365C4D),
        surface: const Color(0xFFFAF7EF),
      ),
      fontFamily: 'Atkinson',
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false),
    ),
    home: store != null ? LibraryScreen(store: store!) : const _Startup(),
  );
}

class _Startup extends StatefulWidget {
  const _Startup();

  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  late Future<LibraryStore> _loading = _open();

  Future<LibraryStore> _open() async {
    await pdfrxFlutterInitialize();
    final support = await getApplicationSupportDirectory();
    return LibraryStore.open(Directory(p.join(support.path, 'library')));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<LibraryStore>(
    future: _loading,
    builder: (context, snapshot) {
      if (snapshot.hasData) return LibraryScreen(store: snapshot.requireData);
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: snapshot.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 16),
                      Text('No se pudo abrir la biblioteca: ${snapshot.error}'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(() => _loading = _open()),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );
}
