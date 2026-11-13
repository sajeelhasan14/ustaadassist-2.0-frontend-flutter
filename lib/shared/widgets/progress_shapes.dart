import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';

/// Progress as shapes (design move 6). Green = done, violet = behind or in
/// progress, grey = still to come.

/// A row of small blocks, one per topic (or class). Each block's colour says
/// where that one stands, so the teacher sees the whole syllabus at a glance.
class SegmentBar extends StatelessWidget {
  const SegmentBar({super.key, required this.colours, this.height = 10});

  final List<Color> colours;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, colour) in colours.indexed) ...[
          if (index > 0) const SizedBox(width: 3),
          Expanded(
            child: Container(height: height, decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(3))),
          ),
        ],
      ],
    );
  }
}

/// A circle that fills up to [value] (0 to 1), with [child] in the middle.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, required this.child, this.size = 76, this.colour});

  final double value;
  final Widget child;
  final double size;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(value.clamp(0, 1).toDouble(), colour ?? AppColors.greenText, AppColors.line),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.colour, this.track);

  final double value;
  final Color colour;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    // Starts at 12 o'clock (-90°) and goes clockwise.
    if (value > 0) canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, paint..color = colour);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.colour != colour || old.track != track;
}
