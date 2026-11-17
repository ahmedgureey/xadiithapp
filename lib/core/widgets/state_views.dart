import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_exception.dart';
import '../providers.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.padding = const EdgeInsets.all(32)});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: padding, child: const Center(child: CircularProgressIndicator()));
}

class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.icon, required this.message, this.action, this.actionLabel});

  final IconData icon;
  final String message;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            if (action != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: action, child: Text(actionLabel ?? '')),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon = Icons.inbox_outlined});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => MessageView(icon: icon, message: message);
}

class ErrorView extends ConsumerWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final isNetwork = error is ApiException && (error as ApiException).isConnectivity;
    return MessageView(
      icon: isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      message: isNetwork ? s.errorNetwork : s.errorGeneric,
      action: onRetry,
      actionLabel: s.retry,
    );
  }
}

/// Renders an [AsyncValue] with consistent loading / error states.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({super.key, required this.value, required this.data, this.onRetry, this.loading});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) => value.when(
        data: data,
        loading: () => loading ?? const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: onRetry),
      );
}
