import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import 'library_store.dart';
import 'models.dart';
import 'pdf_book.dart';
import 'reader_screen.dart';
import 'ui_helpers.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.store});
  final LibraryStore store;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<List<Book>> _books = widget.store.books();
  bool _busy = false;

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error, stack) {
      if (mounted) showFailure(context, error, stack);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _books = widget.store.books();
        });
      }
    }
  }

  Future<void> _open(Book book) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(store: widget.store, book: book),
      ),
    );
  }

  Future<void> _import() async {
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (selected == null || !mounted) return;
    final title = await textPrompt(
      context,
      title: 'Un nuevo libro',
      label: 'Nombre del libro',
      initial: p.basenameWithoutExtension(selected.name),
    );
    if (title == null) return;
    final book = await widget.store.importPdf(
      selected.readAsByteStream(),
      title,
      inspect: PdfBook.inspect,
    );
    if (mounted) await _open(book);
  }

  Future<void> _rename(Book book) async {
    final title = await textPrompt(
      context,
      title: 'Renombrar libro',
      label: 'Nombre',
      initial: book.title,
    );
    if (title != null) await widget.store.rename(book, title);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Entre líneas'),
      actions: [
        IconButton(
          tooltip: 'Privacidad y licencias',
          onPressed: () => showAboutDialog(
            context: context,
            applicationName: 'Entre líneas',
            applicationVersion: '0.1.0 · versión inicial',
            children: const [
              Text(
                'Tus PDF y notas se guardan en este dispositivo. Sin cuenta '
                'ni servidores propios. Los archivos del proveedor pueden '
                'necesitar una descarga antes de importarlos.\n\n'
                'Esta versión aún no incluye copias de seguridad. '
                'Conserva tus PDF originales; desinstalar puede borrar tus notas.',
              ),
            ],
          ),
          icon: const Icon(Icons.info_outline),
        ),
      ],
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_busy) const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            'Tu biblioteca',
            style: Theme.of(context).textTheme.headlineLarge
                ?.copyWith(fontFamily: 'Lora'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Un espacio para leer, escuchar y recordar. Sin conexión.',
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Book>>(
            future: _books,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No se pudo cargar la biblioteca: ${snapshot.error}',
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _books = widget.store.books()),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final books = snapshot.requireData;
              if (books.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_stories_outlined, size: 80),
                        const SizedBox(height: 24),
                        Text(
                          'Tu próxima lectura empieza aquí',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Importa un PDF con texto seleccionable.\n'
                          'Podrás nombrarlo, anotarlo y retomar donde lo dejaste.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
                itemCount: books.length,
                separatorBuilder: (_, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final book = books[index];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        child: Text(book.title.characters.first.toUpperCase()),
                      ),
                      title: Text(
                        book.title,
                        style: const TextStyle(fontFamily: 'Lora'),
                      ),
                      subtitle: Text(
                        'Página ${book.reading.page} de ${book.pageCount} · PDF local',
                      ),
                      trailing: IconButton(
                        tooltip: 'Renombrar ${book.title}',
                        onPressed: _busy
                            ? null
                            : () => _action(() => _rename(book)),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      onTap: _busy ? null : () => _action(() => _open(book)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy ? null : () => _action(_import),
      icon: const Icon(Icons.add),
      label: const Text('Importar PDF'),
    ),
  );
}
