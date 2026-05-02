import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/connectivity_service.dart';
import '../../core/sync_pull_reminder.dart';
import '../../data/db/database.dart';
import '../../data/repositories.dart';
import '../../services/sync_service.dart';
import 'deck_detail_screen.dart';

final _decksProvider = StreamProvider<List<DeckRow>>((ref) {
  final repo = ref.watch(deckRepoProvider);
  repo.pullDecksInBackground();
  return repo.watchDecks();
});

class DecksScreen extends ConsumerWidget {
  const DecksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decksAsync = ref.watch(_decksProvider);
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    final pending = ref.watch(pendingReviewsCountProvider).value ?? 0;

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
            title: const Text('Meus decks'),
            actions: [
              _ConnectivityDot(isOnline: isOnline, pending: pending),
              IconButton(
                icon: const Icon(Icons.sync_rounded),
                tooltip: 'Sincronizar',
                onPressed: handleRefresh,
              ),
            ],
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
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    readableDeckError(e),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            ),
            data: (decks) {
              if (decks.isEmpty) {
                return SliverFillRemaining(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.style_outlined,
                          size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text(
                        'Nenhum deck ainda.',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Toque no + para criar seu primeiro deck.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: handleRefresh,
                        icon: const Icon(Icons.sync_rounded, size: 16),
                        label: const Text('Sincronizar'),
                      ),
                    ],
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                sliver: SliverList.separated(
                  itemCount: decks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _DeckCard(deck: decks[i]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Card do deck ────────────────────────────────────────────

class _DeckCard extends StatelessWidget {
  final DeckRow deck;
  const _DeckCard({required this.deck});

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
        onTap: () => context.push('/decks/${deck.id}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2A3D)),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(4),
                ),
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
                    const SizedBox(height: 3),
                    Text(
                      '${deck.cardCount} cards',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (deck.dueCount > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${deck.dueCount} para revisar',
                    style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Indicador de conectividade ──────────────────────────────

class _ConnectivityDot extends StatelessWidget {
  final bool isOnline;
  final int pending;
  const _ConnectivityDot({required this.isOnline, required this.pending});

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? Colors.greenAccent : Colors.amberAccent;
    final label =
        isOnline ? (pending > 0 ? '$pending pendentes' : 'Online') : 'Offline';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}
