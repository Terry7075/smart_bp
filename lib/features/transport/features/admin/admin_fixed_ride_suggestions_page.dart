import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../models/fixed_ride_suggestion.dart';

class AdminFixedRideSuggestionsPage extends ConsumerStatefulWidget {
  const AdminFixedRideSuggestionsPage({super.key});

  @override
  ConsumerState<AdminFixedRideSuggestionsPage> createState() =>
      _AdminFixedRideSuggestionsPageState();
}

class _AdminFixedRideSuggestionsPageState
    extends ConsumerState<AdminFixedRideSuggestionsPage> {
  late Future<List<FixedRideSuggestion>> _suggestionsFuture;

  @override
  void initState() {
    super.initState();
    _suggestionsFuture = _loadSuggestions();
  }

  Future<List<FixedRideSuggestion>> _loadSuggestions() {
    return ref.read(fixedRidePredictionServiceProvider).fetchAdminSuggestions();
  }

  Future<void> _refresh() async {
    setState(() {
      _suggestionsFuture = _loadSuggestions();
    });
    await _suggestionsFuture;
  }

  void _reload() {
    setState(() {
      _suggestionsFuture = _loadSuggestions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('固定接送建議'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<FixedRideSuggestion>>(
          future: _suggestionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _MessageState(
                icon: Icons.error_outline,
                title: '載入固定接送建議失敗',
                message: '${snapshot.error}',
                actionLabel: '重新整理',
                onAction: _reload,
              );
            }

            final items = snapshot.data ?? const <FixedRideSuggestion>[];
            if (items.isEmpty) {
              return _MessageState(
                icon: Icons.event_repeat,
                title: '目前沒有固定接送建議',
                message: '系統尚未偵測到符合條件的固定接送模式。',
                actionLabel: '重新整理',
                onAction: _reload,
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _FixedRideSuggestionTile(suggestion: items[index]);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FixedRideSuggestionTile extends StatelessWidget {
  const _FixedRideSuggestionTile({required this.suggestion});

  final FixedRideSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final createdAt = DateFormat(
      'yyyy/MM/dd HH:mm',
    ).format(suggestion.createdAt.toLocal());
    final elderLabel = suggestion.elderName?.isNotEmpty == true
        ? suggestion.elderName!
        : suggestion.userId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_repeat,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suggestion.destination,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StatusChip(status: suggestion.status),
              ],
            ),
            const SizedBox(height: 12),
            Text('長者：$elderLabel'),
            Text('星期：${suggestion.weekdayLabel}'),
            Text('建議時間：${suggestion.displayTime}'),
            Text('建立時間：$createdAt'),
            Text('出現次數：${suggestion.occurrenceCount}'),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final FixedRideSuggestionStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(status.label),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
