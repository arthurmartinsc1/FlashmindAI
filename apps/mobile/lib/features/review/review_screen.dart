import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/sync_pull_reminder.dart';
import '../../data/db/database.dart';
import '../../services/sync_service.dart';

final _reviewDecksProvider = StreamProvider<List<DeckRow>>((ref) {
  return ref.watch(databaseProvider).watchDecks();
});

class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decksAsync = ref.watch(_reviewDecksProvider);

    Future<void> handleRefresh() async {
      await ref.read(syncServiceProvider).syncAll();
    }

    return RefreshIndicator(
      onRefresh: handleRefresh,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFF0B0B12),
            title: decksAsync.when(
              loading: () => const Text('Revisar hoje'),
              error: (_, __) => const Text('Revisar hoje'),
              data: (decks) {
                final total = decks.fold(0, (s, d) => s + d.dueCount);
                return total > 0
                    ? Text('Revisar hoje · $total cards')
                    : const Text('Revisar hoje');
              },
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
            sliver: SliverToBoxAdapter(child: SyncPullReminder()),
          ),
          decksAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child:
                    Text('$e', style: const TextStyle(color: Colors.white54)),
              ),
            ),
            data: (decks) {
              final due = decks.where((d) => d.dueCount > 0).toList();

              if (due.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyReview(onSync: handleRefresh),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                sliver: SliverList.separated(
                  itemCount: due.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ReviewDeckTile(deck: due[i]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Tile de deck com cards pendentes ────────────────────────

class _ReviewDeckTile extends StatelessWidget {
  final DeckRow deck;
  const _ReviewDeckTile({required this.deck});

  @override
  Widget build(BuildContext context) {
    Color accent;
    try {
      accent =
          Color(int.parse('FF${deck.color.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      accent = const Color(0xFF6366F1);
    }

    return Material(
      color: const Color(0xFF13131F),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/study/${deck.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withAlpha(60)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.school_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deck.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${deck.cardCount} cards no deck',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withAlpha(40),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${deck.dueCount}',
                  style: TextStyle(
                      color: accent, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: accent.withAlpha(180)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────

class _EmptyReview extends StatelessWidget {
  final VoidCallback onSync;
  const _EmptyReview({required this.onSync});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.celebration_outlined,
              size: 64, color: Colors.white24),
          const SizedBox(height: 20),
          const Text('Tudo em dia! 🎉',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'O algoritmo já agendou suas próximas revisões. Volte mais tarde ou crie novos decks.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: onSync,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sync_rounded, size: 16),
                SizedBox(width: 6),
                Text('Sincronizar'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
