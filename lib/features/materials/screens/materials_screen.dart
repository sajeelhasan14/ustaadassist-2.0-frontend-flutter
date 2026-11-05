import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/card_list.dart';
import '../../../shared/widgets/empty_note.dart';
import '../../../shared/widgets/prompts.dart';
import '../../courses/data/courses_api.dart';
import '../../papers/data/papers_api.dart';
import '../data/materials_api.dart';

/// Slides and notes for a course, kept in one place and opened from any device.
class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key, required this.course});

  final Course course;

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  late Future<(List<CourseFile>, List<TopicRef>)> _data = _load();
  bool _uploading = false;

  Future<(List<CourseFile>, List<TopicRef>)> _load() => (MaterialsApi.list(widget.course.id), PapersApi.topics(widget.course.id)).wait;

  void _reload() => setState(() { _data = _load(); });

  Future<void> _upload() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'csv', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      await MaterialsApi.upload(widget.course.id, UploadFile(field: 'file', name: picked.name, bytes: bytes));
      if (mounted) _reload();
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _open(CourseFile file) async {
    try {
      final link = await MaterialsApi.link(file.id);
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    }
  }

  Future<void> _change(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) _reload();
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    }
  }

  Future<void> _rename(CourseFile file) async {
    final name = await askText(context, title: 'Rename', label: 'File name', initial: file.name);
    if (name != null) await _change(() => MaterialsApi.rename(file.id, name));
  }

  Future<void> _chooseTopic(CourseFile file, List<TopicRef> topics) async {
    final chosen = await showModalBottomSheet<({String? id})>(
      context: context,
      backgroundColor: AppColors.card,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text('No topic', style: AppText.rowTitle), onTap: () => Navigator.of(context).pop((id: null))),
            for (final topic in topics)
              ListTile(title: Text(topic.title, style: AppText.rowTitle), onTap: () => Navigator.of(context).pop((id: topic.id))),
          ],
        ),
      ),
    );
    if (chosen != null) await _change(() => MaterialsApi.setTopic(file.id, chosen.id));
  }

  Future<void> _remove(CourseFile file) async {
    final agreed = await confirmAction(context, title: 'Delete ${file.name}?', message: 'The file is gone for good.', action: 'Delete');
    if (agreed) await _change(() => MaterialsApi.remove(file.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Materials')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.onGreen,
        onPressed: _uploading ? null : _upload,
        icon: const Icon(Icons.upload_rounded),
        label: Text(_uploading ? 'Uploading…' : 'Upload', style: AppText.button),
      ),
      body: SafeArea(
        child: AsyncBody<(List<CourseFile>, List<TopicRef>)>(
          future: _data,
          onRetry: _reload,
          builder: (context, data) {
            final (files, topics) = data;
            if (files.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: EmptyNote(title: 'Nothing here yet', message: 'Upload slides or notes, up to 20 MB each. PDF, Word, PowerPoint, Excel, text or images.'),
              );
            }
            final topicNames = {for (final topic in topics) topic.id: topic.title};
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
              children: [
                CardList(
                  children: [
                    for (final file in files)
                      _Row(
                        file: file,
                        topic: topicNames[file.topicId],
                        onOpen: () => _open(file),
                        onRename: () => _rename(file),
                        onTopic: topics.isEmpty ? null : () => _chooseTopic(file, topics),
                        onRemove: () => _remove(file),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.file, required this.topic, required this.onOpen, required this.onRename, required this.onTopic, required this.onRemove});

  final CourseFile file;
  final String? topic;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback? onTopic;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8, right: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.name, style: AppText.rowTitle, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(topic == null ? file.size : '${file.size} · $topic', style: AppText.small.copyWith(color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            PopupMenuButton<void>(
              tooltip: 'File options',
              color: AppColors.line,
              icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMuted),
              itemBuilder: (_) => [
                PopupMenuItem(onTap: onRename, child: Text('Rename', style: AppText.body)),
                if (onTopic != null) PopupMenuItem(onTap: onTopic, child: Text('Choose topic', style: AppText.body)),
                PopupMenuItem(onTap: onRemove, child: Text('Delete', style: AppText.body.copyWith(color: AppColors.dangerText))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
