import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/status_pill.dart';

/// The top button that will open the assistant. For now the assistant is a
/// placeholder: this marks where it goes, and sends nothing anywhere.
class AssistantButton extends StatelessWidget {
  const AssistantButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Assistant',
      icon: const Icon(Icons.auto_awesome_outlined, color: AppColors.text),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.card,
        builder: (_) => const _AssistantSheet(),
      ),
    );
  }
}

class _AssistantSheet extends StatelessWidget {
  const _AssistantSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Assistant', style: AppText.screenTitle)),
                const StatusPill('Coming soon', tone: PillTone.setup),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Soon you can ask about your classes here, in your own words. It isn\'t connected yet.',
              style: AppText.body.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            const TextField(enabled: false, decoration: InputDecoration(hintText: 'Ask anything')),
          ],
        ),
      ),
    );
  }
}
