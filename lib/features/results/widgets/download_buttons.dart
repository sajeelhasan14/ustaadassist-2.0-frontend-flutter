import 'package:material_ui/material_ui.dart';

import '../../../core/save_file.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/prompts.dart';
import '../../courses/data/courses_api.dart';
import '../data/results_api.dart';

/// "PDF" and "Excel" buttons for one sheet of one section.
class DownloadButtons extends StatefulWidget {
  const DownloadButtons({super.key, required this.course, required this.section, required this.kind});

  final Course course;
  final Section section;
  final SheetKind kind;

  @override
  State<DownloadButtons> createState() => _DownloadButtonsState();
}

class _DownloadButtonsState extends State<DownloadButtons> {
  String? _busy; // the format being fetched

  Future<void> _download(String format) async {
    setState(() => _busy = format);
    try {
      final bytes = await ResultsApi.file(widget.section.id, widget.kind, format);
      // The server's own file name can't be read from a browser, so the same name is built here.
      await saveFile(bytes, '${widget.kind.name} ${widget.course.code} Sec ${widget.section.name}.$format');
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    }
    if (mounted) setState(() => _busy = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.kind.name, style: AppText.rowTitle),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _busy != null ? null : () => _download('pdf'),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: Text(_busy == 'pdf' ? 'Preparing…' : 'PDF'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _busy != null ? null : () => _download('xlsx'),
                icon: const Icon(Icons.grid_on_rounded, size: 18),
                label: Text(_busy == 'xlsx' ? 'Preparing…' : 'Excel'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
