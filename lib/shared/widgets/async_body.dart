import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';

/// Shows loading shapes while [future] loads, the error with a "Try again" button if
/// it fails, and [builder] once the data is here. Every screen that loads data
/// uses this, so none of them can forget the loading or error case.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.future, required this.builder, required this.onRetry});

  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorView(message: '${snapshot.error}', onRetry: onRetry);
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingShapes();
        }
        return builder(context, snapshot.data as T);
      },
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: AppColors.textMuted, size: 40),
            const SizedBox(height: 16),
            Text(message, style: AppText.body.copyWith(color: AppColors.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// Grey blocks in the shape of a screen (a big panel, then rows), gently
/// pulsing while data loads. Feels faster than a spinner because the page
/// already seems to be there. Approved with the 2026-11-09 extras.
class LoadingShapes extends StatefulWidget {
  const LoadingShapes({super.key});

  @override
  State<LoadingShapes> createState() => _LoadingShapesState();
}

/// SingleTickerProviderStateMixin gives the widget a "ticker": a clock that
/// ticks once per frame, which an AnimationController needs to move.
class _LoadingShapesState extends State<LoadingShapes> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900), lowerBound: 0.45, upperBound: 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Teachers who turned animations off on their phone get still shapes.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget block(double height, {double? width, double radius = AppRadius.inner}) => Container(
          height: height,
          width: width,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(radius)),
        );
    return Semantics(
      label: 'Loading',
      child: FadeTransition(
        opacity: _pulse,
        // Some screens put this inside a scrolling list, where there's no height
        // limit; a list inside a list isn't allowed, so it's a plain column there.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shapes = [
              block(28, width: 180, radius: 10),
              const SizedBox(height: 8),
              block(150, radius: AppRadius.card),
              const SizedBox(height: 6),
              for (var i = 0; i < 4; i++) block(64),
            ];
            const padding = EdgeInsets.fromLTRB(20, 16, 20, 0);
            if (!constraints.hasBoundedHeight) {
              return Padding(padding: padding, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: shapes));
            }
            return ListView(physics: const NeverScrollableScrollPhysics(), padding: padding, children: shapes);
          },
        ),
      ),
    );
  }
}
