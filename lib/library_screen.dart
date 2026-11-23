import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import 'design_system/provit_design_system.dart';
import 'design_system/provit_widgets.dart';
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

  Future<void> _delete(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Eliminar "${book.title}"?'),
        content: const Text(
          'Se borrarán el PDF importado, el progreso, las notas y todos los '
          'resaltados guardados. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.store.deleteBook(book);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('PROVIT'),
      actions: [
        IconButton(
          tooltip: 'Privacidad y licencias',
          onPressed: () => showAboutDialog(
            context: context,
            applicationName: 'PROVIT',
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
        const ProvitSectionHeader(
          title: 'Tu biblioteca',
          subtitle:
              'Un espacio para leer, escuchar y recordar. Sin conexión.\n'
              'Cada página tiene un propósito.',
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
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(ProvitSpacing.md),
                  child: const ProvitEmptyState(
                    icon: Icons.auto_stories_outlined,
                    title: 'Tu próxima lectura empieza aquí',
                    description:
                        'Importa un PDF con texto seleccionable.\n'
                        'Podrás nombrarlo, anotarlo y retomar donde lo dejaste.',
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  ProvitSpacing.md,
                  ProvitSpacing.lg,
                  ProvitSpacing.md,
                  100,
                ),
                itemCount: books.length,
                separatorBuilder: (_, index) =>
                    const SizedBox(height: ProvitSpacing.xs),
                itemBuilder: (context, index) {
                  final book = books[index];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(ProvitSpacing.md),
                      leading: CircleAvatar(
                        child: Text(book.title.characters.first.toUpperCase()),
                      ),
                      title: Text(book.title),
                      subtitle: Text(
                        'Página ${book.reading.page} de ${book.pageCount} · PDF local',
                      ),
                      trailing: PopupMenuButton<String>(
                        enabled: !_busy,
                        onSelected: (action) {
                          if (action == 'rename') {
                            _action(() => _rename(book));
                          } else if (action == 'delete') {
                            _action(() => _delete(book));
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'rename',
                            child: Text('Renombrar'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Eliminar'),
                          ),
                        ],
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
