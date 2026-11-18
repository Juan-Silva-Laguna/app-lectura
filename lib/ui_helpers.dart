import 'package:material_ui/material_ui.dart';

void reportFailure(Object error, StackTrace stack) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'app_lectura',
      context: ErrorDescription('durante una operación local'),
    ),
  );
}

void showFailure(BuildContext context, Object error, StackTrace stack) {
  reportFailure(error, stack);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('No se completó la operación. $error'),
      duration: const Duration(seconds: 8),
    ),
  );
}

Future<String?> textPrompt(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  bool multiline = false,
  bool allowEmpty = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPrompt(
    title: title,
    label: label,
    initial: initial,
    multiline: multiline,
    allowEmpty: allowEmpty,
  ),
);

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.label,
    required this.initial,
    required this.multiline,
    required this.allowEmpty,
  });

  final String title;
  final String label;
  final String initial;
  final bool multiline;
  final bool allowEmpty;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!widget.allowEmpty && _controller.text.trim().isEmpty) {
      setState(() => _error = 'Este campo no puede estar vacío.');
      return;
    }
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      minLines: widget.multiline ? 3 : 1,
      maxLines: widget.multiline ? 8 : 1,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: widget.label, errorText: _error),
      onSubmitted: widget.multiline ? null : (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Guardar')),
    ],
  );
}
