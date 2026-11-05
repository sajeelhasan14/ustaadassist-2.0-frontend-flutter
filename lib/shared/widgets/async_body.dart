import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Shows a spinner while [future] loads, the error with a "Try again" button if
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
          return const Center(child: CircularProgressIndicator());
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
            const Icon(Icons.cloud_off_rounded, color: AppColors.textMuted, size: 40),
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
