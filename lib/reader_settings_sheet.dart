import 'package:material_ui/material_ui.dart';

import 'models.dart';

class ReaderSettingsSheet extends StatefulWidget {
  const ReaderSettingsSheet({super.key, required this.settings});
  final ReaderSettings settings;

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  late ReaderSettings _value = widget.settings;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('A tu manera', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          const Text('Tipografía incluida · sin descargas'),
          Wrap(
            spacing: 12,
            children: [
              for (final font in ['Lora', 'Atkinson'])
                ChoiceChip(
                  label: Text(font, style: TextStyle(fontFamily: font)),
                  selected: _value.font == font,
                  onSelected: (_) =>
                      setState(() => _value = _value.copyWith(font: font)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Tamaño de texto · ${_value.fontSize.round()}'),
          Slider(
            value: _value.fontSize,
            min: 16,
            max: 36,
            divisions: 20,
            label: '${_value.fontSize.round()}',
            onChanged: (size) =>
                setState(() => _value = _value.copyWith(fontSize: size)),
          ),
          const Text('Espacio entre líneas'),
          Slider(
            value: _value.lineHeight,
            min: 1.2,
            max: 2.2,
            divisions: 10,
            label: _value.lineHeight.toStringAsFixed(1),
            onChanged: (height) =>
                setState(() => _value = _value.copyWith(lineHeight: height)),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final (theme, label) in [
                (ReadingTheme.paper, 'Papel'),
                (ReadingTheme.sepia, 'Sepia'),
                (ReadingTheme.dark, 'Noche'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _value.theme == theme,
                  onSelected: (_) =>
                      setState(() => _value = _value.copyWith(theme: theme)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Velocidad de narración · lenta a rápida'),
          Slider(
            value: _value.speechRate,
            min: 0.2,
            max: 0.7,
            divisions: 10,
            onChanged: (rate) =>
                setState(() => _value = _value.copyWith(speechRate: rate)),
          ),
          const SizedBox(height: 16),
          Text(
            'La lectura encuentra su propio ritmo.',
            style: TextStyle(
              fontFamily: _value.font,
              fontSize: _value.fontSize,
              height: _value.lineHeight,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context, _value),
            child: const Text('Guardar preferencias'),
          ),
        ],
      ),
    ),
  );
}
