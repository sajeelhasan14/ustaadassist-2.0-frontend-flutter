import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// A short message at the bottom of the screen, such as "Saved" or an error.
void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text))); // look comes from the theme's snackBarTheme
}

/// Asks before anything that can't be undone. Returns true only if the teacher agrees.
Future<bool> confirmAction(BuildContext context, {required String title, required String message, required String action}) async {
  final agreed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.sheet,
      title: Text(title, style: AppText.cardTitle),
      content: Text(message, style: AppText.body.copyWith(color: AppColors.textMuted)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: AppColors.onDanger),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return agreed ?? false;
}

/// Asks for one piece of text, such as a new name. Returns null if cancelled.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  bool number = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextDialog(title: title, label: label, initial: initial, number: number),
  );
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.title, required this.label, required this.initial, required this.number});

  final String title;
  final String label;
  final String initial;
  final bool number;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final value = _text.text.trim();
    if (value.isNotEmpty) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.sheet,
      title: Text(widget.title, style: AppText.cardTitle),
      content: TextField(
        controller: _text,
        autofocus: true,
        style: AppText.input,
        keyboardType: widget.number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        inputFormatters: widget.number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// "7.50" shows as 7.5 and "10.0" as 10, the way a teacher writes marks.
String markText(num value) {
  final text = value.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}
