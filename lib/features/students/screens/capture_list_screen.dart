import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../courses/data/courses_api.dart';
import '../data/students_api.dart';
import 'review_list_screen.dart';

/// The backend's limits, checked here too so the teacher finds out before waiting.
const _maxFiles = 10;
const _maxBytes = 20 * 1024 * 1024;

/// Gathers the class list: photos of each page, or a PDF, Excel or CSV file.
/// Design: Night screen 28, using the phone's own camera instead of a live preview.
class CaptureListScreen extends StatefulWidget {
  const CaptureListScreen({super.key, required this.section});

  final Section section;

  @override
  State<CaptureListScreen> createState() => _CaptureListScreenState();
}

class _CaptureListScreenState extends State<CaptureListScreen> {
  final List<({String name, Uint8List bytes})> _pages = [];
  bool _reading = false;
  String? _error;

  int get _totalBytes => _pages.fold(0, (sum, page) => sum + page.bytes.length);

  void _add(String name, Uint8List bytes) {
    if (_pages.length >= _maxFiles) {
      setState(() => _error = 'At most $_maxFiles pages at once.');
    } else if (_totalBytes + bytes.length > _maxBytes) {
      setState(() => _error = 'These are too large together (20 MB at most).');
    } else {
      setState(() {
        _error = null;
        _pages.add((name: name, bytes: bytes));
      });
    }
  }

  Future<void> _takePhoto() async {
    // A smaller photo uploads faster, and printed text stays perfectly readable.
    final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 2200);
    if (photo == null) return;
    _add('page-${_pages.length + 1}.jpg', await photo.readAsBytes());
  }

  Future<void> _pickFiles() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'xlsx', 'xls', 'csv', 'jpg', 'jpeg', 'png', 'webp']);
    for (final file in files) {
      _add(file.name, await file.readAsBytes());
    }
  }

  Future<void> _read() async {
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final list = await StudentsApi.extract(widget.section.id, [
        for (final page in _pages) UploadFile(field: 'files', name: page.name, bytes: page.bytes),
      ]);
      if (!mounted) return;
      final added = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ReviewListScreen(section: widget.section, list: list)),
      );
      if (added == true && mounted) {
        Navigator.of(context).pop(true);
      } else if (mounted) {
        setState(() => _reading = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _reading = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Class list')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                children: [
                  Text('Hold the sheet', style: AppText.heroTitle.copyWith(fontSize: 32)),
                  Text('flat and steady.', style: AppText.heroTitle.copyWith(fontSize: 32, color: AppColors.greenText)),
                  const SizedBox(height: 10),
                  Text('Photograph each page, or pick a file. Any layout works, and nothing is saved until you check it.',
                      style: AppText.body.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 20),
                  if (_reading)
                    const _ReadingNote()
                  else ...[
                    FilledButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.photo_camera_outlined), label: const Text('Take a photo')),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(onPressed: _pickFiles, icon: const Icon(Icons.upload_file_rounded), label: const Text('Pick PDF, Excel or CSV')),
                  ],
                  const SizedBox(height: 20),
                  if (_pages.isNotEmpty) ...[
                    Text('${_pages.length} ${_pages.length == 1 ? 'PAGE' : 'PAGES'}', style: AppText.label),
                    const SizedBox(height: 10),
                    for (final (index, page) in _pages.indexed)
                      _PageRow(name: page.name, onRemove: _reading ? null : () => setState(() => _pages.removeAt(index))),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: AppText.small.copyWith(color: AppColors.dangerText)),
                    const SizedBox(height: 10),
                  ],
                  FilledButton(
                    onPressed: _pages.isEmpty || _reading ? null : _read,
                    child: Text(_reading ? 'Reading…' : (_error != null && _pages.isNotEmpty ? 'Try again' : 'Read the list')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingNote extends StatelessWidget {
  const _ReadingNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppGlass.box(AppRadius.card),
      child: Row(
        children: [
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(width: 16),
          Expanded(child: Text('Reading the list. This can take a minute or two.', style: AppText.body)),
        ],
      ),
    );
  }
}

class _PageRow extends StatelessWidget {
  const _PageRow({required this.name, required this.onRemove});

  final String name;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: AppGlass.box(AppRadius.inner),
      child: Row(
        children: [
          Icon(Icons.description_outlined, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: AppText.rowTitle, overflow: TextOverflow.ellipsis)),
          IconButton(tooltip: 'Remove $name', icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted), onPressed: onRemove),
        ],
      ),
    );
  }
}
