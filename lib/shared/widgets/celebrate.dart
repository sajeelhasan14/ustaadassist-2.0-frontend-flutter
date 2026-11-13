import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// The reward moment after a finished job (design move 8): a short confetti
/// burst plus the "Saved" toast, with Undo when the job can be undone.
///
/// The confetti goes into the app's top layer (the root Overlay), so it keeps
/// playing while the screen that called this closes. The toast lives in the
/// app-wide ScaffoldMessenger, so it shows on the screen underneath.
void celebrate(BuildContext context, {required String message, VoidCallback? onUndo}) {
  if (!MediaQuery.disableAnimationsOf(context)) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _Confetti(onDone: () => entry.remove()));
    overlay.insert(entry);
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 20, color: AppColors.greenText),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      action: onUndo == null ? null : SnackBarAction(label: 'Undo', onPressed: onUndo),
    ));
}

/// 40 small coloured pieces thrown up from the bottom middle, falling back
/// with gravity and spinning. 1.4 seconds, then it removes itself.
class _Confetti extends StatefulWidget {
  const _Confetti({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  // Each piece: direction, speed, colour, size, spin. Picked once at the start.
  final _pieces = () {
    final random = math.Random();
    final colours = [for (final course in AppColors.courseColours) course.fill];
    return [
      for (var i = 0; i < 40; i++)
        (
          angle: -math.pi / 2 + (random.nextDouble() - 0.5) * 1.6, // mostly upwards, fanned out
          speed: 0.9 + random.nextDouble() * 0.7,
          colour: colours[i % colours.length],
          size: 6 + random.nextDouble() * 5,
          spin: (random.nextDouble() - 0.5) * 12,
        ),
    ];
  }();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) => CustomPaint(size: MediaQuery.sizeOf(context), painter: _ConfettiPainter(_pieces, _clock.value)),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<({double angle, double speed, Color colour, double size, double spin})> pieces;
  final double t; // 0 at the start, 1 at the end

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(size.width / 2, size.height * 0.78);
    final reach = size.height * 0.75;
    for (final piece in pieces) {
      // Thrown at `speed` in direction `angle`, pulled down by gravity: the arc of a ball.
      final dx = math.cos(piece.angle) * piece.speed * reach * t;
      final dy = math.sin(piece.angle) * piece.speed * reach * t + 0.9 * reach * t * t;
      final paint = Paint()..color = piece.colour.withValues(alpha: (1 - t * t).clamp(0, 1));
      canvas
        ..save()
        ..translate(start.dx + dx, start.dy + dy)
        ..rotate(piece.spin * t);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: piece.size, height: piece.size * 0.6), const Radius.circular(2)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// A number that counts up from 0 when it first appears (design move 8).
/// `TweenAnimationBuilder` animates between two values without a controller.
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, required this.style, this.suffix = '', this.suffixStyle});

  final num value;
  final TextStyle style;
  final String suffix; // "%" or " / 50", drawn smaller
  final TextStyle? suffixStyle;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? value.toDouble() : 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => Text.rich(
        TextSpan(children: [
          TextSpan(text: shown.round().toString()),
          if (suffix.isNotEmpty) TextSpan(text: suffix, style: suffixStyle),
        ]),
        style: style,
        semanticsLabel: '${value.round()}$suffix',
      ),
    );
  }
}

/// The playful rotated stamp on a finished state, e.g. "ALL DONE!" (design move 7).
class DoneStamp extends StatelessWidget {
  const DoneStamp(this.text, {super.key, this.colour});

  final String text;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final ink = colour ?? AppColors.greenText;
    return Transform.rotate(
      angle: -9 * math.pi / 180,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(border: Border.all(color: ink, width: 3), borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: AppText.cardTitle.copyWith(color: ink, fontSize: 22, letterSpacing: 0.5)),
      ),
    );
  }
}
