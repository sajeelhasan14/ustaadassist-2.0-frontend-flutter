import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_client.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/step_scaffold.dart';
import '../data/setup_api.dart';
import 'setup_holidays_screen.dart';

/// Step 2: paste the outline, one topic per line. Design: Night screen 26.
/// With [standalone] it adds topics to an existing course, then simply closes.
class SetupTopicsScreen extends StatefulWidget {
  const SetupTopicsScreen({super.key, required this.progress, this.standalone = false});

  final SetupProgress progress;
  final bool standalone;

  @override
  State<SetupTopicsScreen> createState() => _SetupTopicsScreenState();
}

class _SetupTopicsScreenState extends State<SetupTopicsScreen> {
  final _outline = TextEditingController();
  int? _classes;
  bool _busy = false;
  bool _reading = false; // the AI is reading a photo or PDF of the outline
  String? _error;

  @override
  void initState() {
    super.initState();
    _outline.addListener(() => setState(() {}));
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final classes = await SetupApi.classesAvailable(widget.progress.sectionId);
      if (mounted) setState(() => _classes = classes);
    } catch (_) {
      // Only shown for information. It's fetched again when saving.
    }
  }

  @override
  void dispose() {
    _outline.dispose();
    super.dispose();
  }

  /// Topic import: a photo of the printed outline, or a PDF or photo file. The topics
  /// found are added to the box (below anything already typed), so nothing is saved
  /// until the teacher has looked and pressed the main button.
  Future<void> _readOutline({required bool camera}) async {
    final files = <UploadFile>[];
    if (camera) {
      // A smaller photo uploads faster, and printed text stays perfectly readable.
      final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 2200);
      if (photo != null) files.add(UploadFile(field: 'files', name: 'outline.jpg', bytes: await photo.readAsBytes()));
    } else {
      final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'txt']);
      for (final file in picked) {
        files.add(UploadFile(field: 'files', name: file.name, bytes: await file.readAsBytes()));
      }
    }
    if (files.isEmpty || !mounted) return;
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final topics = await SetupApi.extractTopics(files);
      final typed = _outline.text.trimRight();
      _outline.text = [if (typed.isNotEmpty) typed, ...topics].join('\n');
    } catch (error) {
      _error = '$error';
    }
    if (mounted) setState(() => _reading = false);
  }

  /// Pasted outlines often carry numbers or bullets: "1. Intro", "- Intro". We keep only the topic.
  List<String> get _topics => [
        for (final line in _outline.text.split('\n'))
          if (line.trim().replaceFirst(RegExp(r'^(\d+[.)]|[-•*])\s*'), '').trim() case final topic when topic.isNotEmpty) topic,
      ];

  Future<void> _next() async {
    final topics = _topics;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (topics.isNotEmpty) {
        final classes = _classes ?? await SetupApi.classesAvailable(widget.progress.sectionId);
        await SetupApi.addTopics(widget.progress.course.id, topics, classes);
      }
      if (!mounted) return;
      if (widget.standalone) {
        Navigator.of(context).pop(true);
      } else {
        await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SetupHolidaysScreen(progress: widget.progress)));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  String get _buttonLabel {
    if (_busy) return 'Saving…';
    if (widget.standalone) return 'Save topics';
    return _topics.isEmpty ? 'Skip for now' : 'Next: holidays';
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      title: widget.progress.course.title,
      step: widget.standalone ? 'Topics' : '2 / 3',
      headingTop: 'What are you',
      headingBottom: 'teaching?',
      subtitle: 'One topic per line. Paste your outline, or photograph it, and the classes are shared out for you.',
      error: _error,
      buttonLabel: _buttonLabel,
      onPressed: _busy || _reading || (widget.standalone && _topics.isEmpty) ? null : _next,
      children: [
        // Topic import: the outline is often printed, so reading it beats typing it.
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _reading ? null : () => _readOutline(camera: true),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Photo of outline'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _reading ? null : () => _readOutline(camera: false),
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('PDF or photo'),
              ),
            ),
          ],
        ),
        if (_reading) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
              const SizedBox(width: 10),
              Expanded(child: Text('Reading your outline…', style: AppText.body.copyWith(color: AppColors.textMuted))),
            ],
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _outline,
          minLines: 9,
          maxLines: 14,
          style: AppText.input.copyWith(height: 1.6),
          decoration: const InputDecoration(hintText: 'Introduction to Databases\nRelational Model\nNormalization'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _Count(value: '${_topics.length}', label: 'topics', accent: true)),
            const SizedBox(width: 10),
            Expanded(child: _Count(value: _classes == null ? '–' : '$_classes', label: 'classes left')),
          ],
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label, this.accent = false});

  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final foreground = accent ? AppColors.onGreen : AppColors.text;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: accent ? AppColors.green : AppColors.card, borderRadius: BorderRadius.circular(AppRadius.inner)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppText.cardTitle.copyWith(color: foreground, fontSize: 26)),
          const SizedBox(height: 2),
          Text(label, style: AppText.small.copyWith(color: accent ? AppColors.onGreenSoft : AppColors.textMuted)),
        ],
      ),
    );
  }
}
