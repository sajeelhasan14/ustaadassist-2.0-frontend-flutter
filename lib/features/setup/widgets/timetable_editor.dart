import 'package:material_ui/material_ui.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../data/setup_api.dart';

const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S'];
const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

/// Picks the class days and their times. It changes [slots] directly and calls
/// [onChanged], so the screen that owns the list decides when to save it.
class TimetableEditor extends StatelessWidget {
  const TimetableEditor({super.key, required this.slots, required this.onChanged});

  final List<ClassSlot> slots;
  final VoidCallback onChanged;

  void _toggleDay(int weekday) {
    final existing = slots.where((slot) => slot.weekday == weekday).firstOrNull;
    if (existing != null) {
      slots.remove(existing);
    } else {
      // A new day copies the last day's time, which is usually right.
      final last = slots.lastOrNull;
      slots.add(ClassSlot(weekday: weekday, startTime: last?.startTime ?? '09:00', endTime: last?.endTime ?? '10:00'));
      slots.sort((a, b) => a.weekday.compareTo(b.weekday));
    }
    onChanged();
  }

  Future<void> _pickTime(BuildContext context, ClassSlot slot, {required bool start}) async {
    final parts = (start ? slot.startTime : slot.endTime).split(':');
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])));
    if (picked == null) return;
    final text = timeText(picked.hour, picked.minute);
    start ? slot.startTime = text : slot.endTime = text;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var index = 0; index < _dayLetters.length; index++)
              _DayChip(
                letter: _dayLetters[index],
                name: _dayNames[index],
                selected: slots.any((slot) => slot.weekday == index + 1),
                onTap: () => _toggleDay(index + 1),
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (final slot in slots)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text(_dayNames[slot.weekday - 1], style: AppText.rowTitle)),
                Expanded(flex: 3, child: ValueBox(value: slot.startTime, onTap: () => _pickTime(context, slot, start: true))),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: ValueBox(value: slot.endTime, onTap: () => _pickTime(context, slot, start: false))),
              ],
            ),
          ),
      ],
    );
  }
}

/// A tappable box that looks like a text field, for values chosen from a picker.
class ValueBox extends StatelessWidget {
  const ValueBox({super.key, required this.value, required this.onTap, this.label});

  final String value;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.field),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null) ...[
                Text(label!, style: AppText.small.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
              ],
              Text(value, style: AppText.mono),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.letter, required this.name, required this.selected, required this.onTap});

  final String letter;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: Material(
        color: selected ? AppColors.green : AppColors.card,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: ExcludeSemantics(
                child: Text(letter, style: AppText.rowTitle.copyWith(color: selected ? AppColors.onGreen : AppColors.textMuted)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
