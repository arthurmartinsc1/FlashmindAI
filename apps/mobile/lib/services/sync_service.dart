import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connectivity_service.dart';
import '../data/db/database.dart';
import '../data/repositories.dart';

/// Coordena a sincronização entre o Drift local e a API.
///
/// - `pull()`  baixa decks + cards do servidor
/// - `push()`  envia operações locais pendentes e depois pending_reviews
/// - `start()` faz pull inicial e fica observando a conectividade — quando
///   o app volta a ter rede, dispara push (e um pull leve dos decks).
class SyncService {
  SyncService(this._ref);
  final Ref _ref;

  ProviderSubscription<AsyncValue<bool>>? _connSub;
  bool _running = false;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Sync inicial best-effort: envia mutações locais antes de puxar snapshots.
    unawaited(syncAll());

    // Reage a mudanças de conectividade.
    _connSub = _ref.listen<AsyncValue<bool>>(
      isOnlineProvider,
      (prev, next) {
        final wasOffline = prev?.value == false;
        final isOnline = next.value == true;
        if (wasOffline && isOnline) {
          unawaited(syncAll());
        }
      },
    );
  }

  void dispose() {
    _connSub?.close();
    _connSub = null;
    _started = false;
  }

  Future<void> syncAll() async {
    if (_running) return;
    _running = true;
    try {
      await push();
      await pull();
    } finally {
      _running = false;
    }
  }

  Future<void> pull() async {
    try {
      final deckRepo = _ref.read(deckRepoProvider);
      await deckRepo.pullDecks();

      final cardRepo = _ref.read(cardRepoProvider);
      final decks = await deckRepo.allDecks();
      for (final d in decks) {
        await cardRepo.pullCardsForDeck(d.id);
      }
    } catch (_) {
      // offline ou erro de rede: silencioso, dados locais continuam servindo.
    }
  }

  Future<void> pullDeck(String deckId) async {
    final deckRepo = _ref.read(deckRepoProvider);
    final cardRepo = _ref.read(cardRepoProvider);
    await deckRepo.pullDeck(deckId);
    await cardRepo.pullCardsForDeck(deckId);
  }

  Future<int> push() async {
    try {
      final opRepo = _ref.read(operationSyncRepoProvider);
      final reviewRepo = _ref.read(reviewRepoProvider);
      final ops = await opRepo.flushPending();
      final reviews = await reviewRepo.flushPending();
      return ops + reviews;
    } catch (_) {
      return 0;
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final svc = SyncService(ref);
  ref.onDispose(svc.dispose);
  return svc;
});

/// Stream do número de itens pendentes de sync (reviews + mutações locais).
final pendingReviewsCountProvider = StreamProvider<int>((ref) async* {
  final db = ref.watch(databaseProvider);
  Future<int> countAll() async =>
      await db.countPendingReviews() + await db.countPendingOperations();

  yield await countAll();
  // Re-emite a cada 2s. Simples; sem signal channel pra manter o app enxuto.
  yield* Stream.periodic(const Duration(seconds: 2))
      .asyncMap((_) => countAll());
});
