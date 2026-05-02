import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/secure_storage.dart';
import '../domain/models.dart';
import 'api/endpoints.dart';
import 'db/database.dart';

bool _isSyncableFailure(Object error) {
  if (error is! DioException) return false;
  final status = error.response?.statusCode;
  return status == null || status >= 500;
}

String _localId(String scope) {
  return 'local-$scope-${DateTime.now().microsecondsSinceEpoch}';
}

// ─── Auth ────────────────────────────────────────────────────
class AuthRepository {
  AuthRepository(this._api, this._tokens, this._db);

  final AuthApi _api;
  final TokenStore _tokens;
  final AppDatabase _db;

  Future<UserDto> login(String email, String password) async {
    final res = await _api.login(email, password);
    await _tokens.saveTokens(res.tokens.access, res.tokens.refresh);
    await _db.upsertUser(UserRow(
      id: res.user.id,
      email: res.user.email,
      name: res.user.name,
      isEmailVerified: res.user.isEmailVerified,
    ));
    return res.user;
  }

  Future<UserDto> register(String name, String email, String password) async {
    final res = await _api.register(name, email, password);
    await _tokens.saveTokens(res.tokens.access, res.tokens.refresh);
    await _db.upsertUser(UserRow(
      id: res.user.id,
      email: res.user.email,
      name: res.user.name,
      isEmailVerified: res.user.isEmailVerified,
    ));
    return res.user;
  }

  Future<UserDto> verifyEmail(String pin) async {
    final user = await _api.verifyEmail(pin);
    await _db.setEmailVerified(verified: user.isEmailVerified);
    return user;
  }

  Future<Map<String, dynamic>> resendEmail() => _api.resendEmail();

  Future<void> logout() async {
    await _api.logout();
    await _tokens.clear();
  }
}

final authRepoProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(authApiProvider),
    ref.watch(tokenStoreProvider),
    ref.watch(databaseProvider),
  );
});

// ─── Dashboard ───────────────────────────────────────────────
class DashboardRepository {
  DashboardRepository(this._api, this._db);
  final DashboardApi _api;
  final AppDatabase _db;

  Future<DashboardDto> fetch() => _api.fetch();

  Future<DashboardDto> fetchLocalFirst() async {
    final local = await _db.localDashboardSnapshot();
    try {
      final remote = await _api.fetch();
      return _mergeDashboard(local: local, remote: remote);
    } catch (_) {
      return local;
    }
  }

  Stream<DashboardDto> watchLocalFirst() async* {
    yield await _db.localDashboardSnapshot();
    try {
      final remote = await _api.fetch();
      final local = await _db.localDashboardSnapshot();
      yield _mergeDashboard(local: local, remote: remote);
    } catch (_) {}
  }

  DashboardDto _mergeDashboard({
    required DashboardDto local,
    required DashboardDto remote,
  }) {
    return DashboardDto(
      dueToday: local.dueToday,
      reviewedToday: _maxInt(local.reviewedToday, remote.reviewedToday),
      reviewedWeek: _maxInt(local.reviewedWeek, remote.reviewedWeek),
      reviewedMonth: _maxInt(local.reviewedMonth, remote.reviewedMonth),
      retentionRate:
          remote.retentionRate > 0 ? remote.retentionRate : local.retentionRate,
      currentStreak: _maxInt(local.currentStreak, remote.currentStreak),
      longestStreak: _maxInt(local.longestStreak, remote.longestStreak),
      activityLast30Days: remote.activityLast30Days.isNotEmpty
          ? remote.activityLast30Days
          : local.activityLast30Days,
      cardDistribution: local.cardDistribution.total > 0
          ? local.cardDistribution
          : remote.cardDistribution,
    );
  }
}

int _maxInt(int a, int b) => a > b ? a : b;

final dashboardRepoProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    ref.watch(dashboardApiProvider),
    ref.watch(databaseProvider),
  );
});

// ─── Decks ───────────────────────────────────────────────────
class DeckRepository {
  DeckRepository(this._api, this._jobs, this._db);

  final DeckApi _api;
  final JobApi _jobs;
  final AppDatabase _db;

  Stream<List<DeckRow>> watchDecks() => _db.watchDecks();
  Stream<DeckRow?> watchDeck(String deckId) => _db.watchDeck(deckId);
  Future<List<DeckRow>> allDecks() => _db.allDecks();

  void pullDecksInBackground() {
    unawaited(pullDecks().catchError((_) {}));
  }

  void pullDeckInBackground(String deckId) {
    unawaited(pullDeck(deckId).catchError((_) {}));
  }

  Future<List<DeckRow>> fetchDecks() async {
    final remote = await _api.list();
    final rows = <DeckRow>[];
    for (final d in remote) {
      rows.add(await _deckRowFromDto(d));
    }
    await _db.replaceDecks(rows);
    return rows;
  }

  Future<void> pullDecks() async {
    await fetchDecks();
  }

  Future<DeckRow> fetchDeck(String deckId) async {
    final d = await _api.fetch(deckId);
    final row = await _deckRowFromDto(d);
    await _db.upsertDecks([row]);
    return row;
  }

  Future<void> pullDeck(String deckId) async {
    await fetchDeck(deckId);
  }

  Future<void> createDeck({
    required String title,
    String? description,
    String? color,
  }) async {
    try {
      final d = await _api.create(
        title: title,
        description: description,
        color: color,
      );
      await _db.upsertDecks([await _deckRowFromDto(d)]);
    } catch (e) {
      if (!_isSyncableFailure(e)) rethrow;
      final localId = _localId('deck');
      await _db.upsertDecks([
        DeckRow(
          id: localId,
          title: title,
          description: description ?? '',
          color: color ?? '#6366F1',
          cardCount: 0,
          dueCount: 0,
          updatedAt: DateTime.now(),
        )
      ]);
      await _db.enqueueOperation(
        type: 'deck.create',
        payload: {
          'local_id': localId,
          'title': title,
          'description': description ?? '',
          'color': color ?? '#6366F1',
        },
      );
    }
  }

  Future<void> updateDeck({
    required String deckId,
    String? title,
    String? description,
    String? color,
  }) async {
    try {
      final d = await _api.update(
        deckId: deckId,
        title: title,
        description: description,
        color: color,
      );
      await _db.upsertDecks([await _deckRowFromDto(d)]);
    } catch (e) {
      if (!_isSyncableFailure(e)) rethrow;
      final current = await _db.deckById(deckId);
      if (current != null) {
        await _db.updateDeckLocal(current.copyWith(
          title: title ?? current.title,
          description: description ?? current.description,
          color: color ?? current.color,
          updatedAt: DateTime.now(),
        ));
      }
      await _db.enqueueOperation(
        type: 'deck.update',
        payload: {
          'deck_id': deckId,
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          if (color != null) 'color': color,
        },
      );
    }
  }

  Future<void> archiveDeck(String deckId) async {
    try {
      await _api.archive(deckId);
      await _db.deleteDeck(deckId);
    } catch (e) {
      if (!_isSyncableFailure(e)) rethrow;
      await _db.deleteDeck(deckId);
      await _db.enqueueOperation(
        type: 'deck.archive',
        payload: {'deck_id': deckId},
      );
    }
  }

  Future<DeckRow> _deckRowFromDto(DeckDto d) async {
    final localCardCount = await _db.countCardsForDeck(d.id);
    final localDue = await _db.countDueForDeck(d.id);
    return DeckRow(
      id: d.id,
      title: d.title,
      description: d.description,
      color: d.color,
      cardCount: d.cardCount,
      dueCount: localCardCount == 0 ? d.dueCount : localDue,
      updatedAt: d.updatedAt,
    );
  }

  Future<AsyncJobDto> generateCards({
    required String deckId,
    required String topic,
    required int count,
    String language = 'pt-BR',
    String? sourceText,
  }) async {
    final started = await _api.generateCards(
      deckId: deckId,
      topic: topic,
      count: count,
      language: language,
      sourceText: sourceText,
    );

    var job = started;
    for (var attempt = 0; attempt < 60 && job.isRunning; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      job = await _jobs.fetch(job.id);
    }
    return job;
  }
}

final deckRepoProvider = Provider<DeckRepository>((ref) {
  return DeckRepository(
    ref.watch(deckApiProvider),
    ref.watch(jobApiProvider),
    ref.watch(databaseProvider),
  );
});

// ─── Cards ───────────────────────────────────────────────────
class CardRepository {
  CardRepository(this._api, this._db);

  final DeckApi _api;
  final AppDatabase _db;

  Future<List<CardRow>> dueForDeck(String deckId) =>
      _db.dueCardsForDeck(deckId);

  Stream<List<CardRow>> watchCardsForDeck(String deckId) =>
      _db.watchCardsForDeck(deckId);

  void pullCardsForDeckInBackground(String deckId) {
    unawaited(pullCardsForDeck(deckId).catchError((_) {}));
  }

  Future<List<CardRow>> fetchCardsForDeck(String deckId) async {
    final remote = await _api.cards(deckId);
    final rows = remote.map(_cardRowFromDto).toList();
    await _db.replaceCardsForDeck(deckId, rows);
    await _db.refreshCardStatsForDeck(deckId);
    return rows;
  }

  Future<void> pullCardsForDeck(String deckId) async {
    await fetchCardsForDeck(deckId);
  }

  Future<void> createCard({
    required String deckId,
    required String front,
    required String back,
  }) async {
    try {
      final c = await _api.createCard(deckId: deckId, front: front, back: back);
      await _db.upsertCards([_cardRowFromDto(c)]);
      await _db.refreshCardStatsForDeck(deckId);
    } catch (e) {
      if (!_isSyncableFailure(e)) rethrow;
      final localId = _localId('card');
      await _db.upsertCards([
        CardRow(
          id: localId,
          deckId: deckId,
          front: front,
          back: back,
          easeFactor: 2.5,
          intervalDays: 0,
          repetitions: 0,
          nextReview: DateTime.now(),
          updatedAt: DateTime.now(),
        )
      ]);
      await _db.refreshCardStatsForDeck(deckId);
      await _db.enqueueOperation(
        type: 'card.create',
        payload: {
          'local_id': localId,
          'deck_id': deckId,
          'front': front,
          'back': back,
        },
      );
    }
  }

  Future<void> updateCard({
    required String deckId,
    required String cardId,
    required String front,
    required String back,
  }) async {
    try {
      final c = await _api.updateCard(cardId: cardId, front: front, back: back);
      await _db.upsertCards([_cardRowFromDto(c)]);
      await _db.refreshCardStatsForDeck(deckId);
    } catch (e) {
      if (!_isSyncableFailure(e)) rethrow;
      await _db.updateCardContent(cardId: cardId, front: front, back: back);
      await _db.enqueueOperation(
        type: 'card.update',
        payload: {
          'deck_id': deckId,
          'card_id': cardId,
          'front': front,
          'back': back,
        },
      );
    }
  }

  Future<void> deleteCard({
    required String deckId,
    required String cardId,
  }) async {
    try {
      await _api.deleteCard(cardId);
      await _db.deleteCard(cardId);
      await _db.refreshCardStatsForDeck(deckId);
    } catch (e) {
      if (!_isSyncableFailure(e)) rethrow;
      await _db.deleteCard(cardId);
      await _db.refreshCardStatsForDeck(deckId);
      await _db.enqueueOperation(
        type: 'card.delete',
        payload: {'deck_id': deckId, 'card_id': cardId},
      );
    }
  }

  CardRow _cardRowFromDto(CardDto c) {
    return CardRow(
      id: c.id,
      deckId: c.deckId,
      front: c.front,
      back: c.back,
      easeFactor: c.easeFactor,
      intervalDays: c.intervalDays,
      repetitions: c.repetitions,
      nextReview: c.nextReview,
      updatedAt: c.updatedAt,
    );
  }
}

final cardRepoProvider = Provider<CardRepository>((ref) {
  return CardRepository(
    ref.watch(deckApiProvider),
    ref.watch(databaseProvider),
  );
});

// ─── Microlearning ───────────────────────────────────────────
class LessonRepository {
  LessonRepository(this._api, this._db);

  final LessonApi _api;
  final AppDatabase _db;

  Stream<List<LessonSummaryDto>> watchLessons(String deckId) {
    pullLessonsInBackground(deckId);
    return _db.watchLessonsForDeck(deckId);
  }

  Stream<LessonDetailDto?> watchLesson(String lessonId) {
    pullLessonInBackground(lessonId);
    return _db.watchLessonDetail(lessonId);
  }

  void pullLessonsInBackground(String deckId) {
    unawaited(list(deckId).then<void>((_) {}, onError: (_, __) {}));
  }

  void pullLessonInBackground(String lessonId) {
    unawaited(fetch(lessonId).then<void>((_) {}, onError: (_, __) {}));
  }

  Future<List<LessonSummaryDto>> list(String deckId) async {
    final remote = await _api.list(deckId);
    await _db.replaceLessons(deckId, remote);
    for (final lesson in remote) {
      try {
        await fetch(lesson.id);
      } catch (_) {
        // A lista ainda é útil offline mesmo se algum detalhe falhar.
      }
    }
    return remote;
  }

  Future<LessonDetailDto> fetch(String lessonId) async {
    final lesson = await _api.fetch(lessonId);
    await _db.upsertLessonDetail(lesson);
    return lesson;
  }

  Future<CompleteLessonDto> complete(String lessonId) async {
    try {
      final result = await _api.complete(lessonId);
      await _db.markLessonCompleted(lessonId);
      return result;
    } catch (e) {
      if (!_isSyncableFailure(e)) rethrow;
      await _db.markLessonCompleted(lessonId);
      await _db.enqueueOperation(
        type: 'lesson.complete',
        payload: {'lesson_id': lessonId},
      );
      return CompleteLessonDto(
        lessonId: lessonId,
        alreadyCompleted: false,
        unlockedCardsCount: 0,
      );
    }
  }
}

final lessonRepoProvider = Provider<LessonRepository>((ref) {
  return LessonRepository(
    ref.watch(lessonApiProvider),
    ref.watch(databaseProvider),
  );
});

// ─── Pending operations ──────────────────────────────────────
class OperationSyncRepository {
  OperationSyncRepository(this._deckApi, this._lessonApi, this._db);

  final DeckApi _deckApi;
  final LessonApi _lessonApi;
  final AppDatabase _db;

  Future<int> flushPending() async {
    final ops = await _db.pendingOperationsAll();
    var sent = 0;

    for (final op in ops) {
      try {
        final payload =
            (jsonDecode(op.payloadJson) as Map).cast<String, dynamic>();
        await _send(op.type, payload);
        await _db.deletePendingOperation(op.id);
        sent++;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status != null && status < 500 && status != 401) {
          await _db.deletePendingOperation(op.id);
          sent++;
          continue;
        }
        break;
      } catch (_) {
        break;
      }
    }

    return sent;
  }

  Future<void> _send(String type, Map<String, dynamic> payload) async {
    switch (type) {
      case 'deck.create':
        final deck = await _deckApi.create(
          title: payload['title'] as String,
          description: payload['description'] as String?,
          color: payload['color'] as String?,
        );
        final localId = payload['local_id'] as String;
        await _db.deleteDeck(localId);
        await _db.upsertDecks([_deckRowFromDto(deck)]);
        await _db.replacePendingOperationReference(
          fromId: localId,
          toId: deck.id,
        );
        break;
      case 'deck.update':
        final deck = await _deckApi.update(
          deckId: payload['deck_id'] as String,
          title: payload['title'] as String?,
          description: payload['description'] as String?,
          color: payload['color'] as String?,
        );
        await _db.upsertDecks([_deckRowFromDto(deck)]);
        break;
      case 'deck.archive':
        await _deckApi.archive(payload['deck_id'] as String);
        break;
      case 'card.create':
        final card = await _deckApi.createCard(
          deckId: payload['deck_id'] as String,
          front: payload['front'] as String,
          back: payload['back'] as String,
        );
        final localId = payload['local_id'] as String;
        await _db.deleteCard(localId);
        await _db.upsertCards([_cardRowFromDto(card)]);
        await _db.refreshCardStatsForDeck(card.deckId);
        await _db.replacePendingOperationReference(
          fromId: localId,
          toId: card.id,
        );
        await _db.replacePendingReviewCardId(fromId: localId, toId: card.id);
        break;
      case 'card.update':
        final card = await _deckApi.updateCard(
          cardId: payload['card_id'] as String,
          front: payload['front'] as String,
          back: payload['back'] as String,
        );
        await _db.upsertCards([_cardRowFromDto(card)]);
        await _db.refreshCardStatsForDeck(card.deckId);
        break;
      case 'card.delete':
        await _deckApi.deleteCard(payload['card_id'] as String);
        await _db.refreshCardStatsForDeck(payload['deck_id'] as String);
        break;
      case 'lesson.complete':
        await _lessonApi.complete(payload['lesson_id'] as String);
        await _db.markLessonCompleted(payload['lesson_id'] as String);
        break;
      default:
        throw StateError('Operação pendente desconhecida: $type');
    }
  }

  DeckRow _deckRowFromDto(DeckDto deck) {
    return DeckRow(
      id: deck.id,
      title: deck.title,
      description: deck.description,
      color: deck.color,
      cardCount: deck.cardCount,
      dueCount: deck.dueCount,
      updatedAt: deck.updatedAt,
    );
  }

  CardRow _cardRowFromDto(CardDto card) {
    return CardRow(
      id: card.id,
      deckId: card.deckId,
      front: card.front,
      back: card.back,
      easeFactor: card.easeFactor,
      intervalDays: card.intervalDays,
      repetitions: card.repetitions,
      nextReview: card.nextReview,
      updatedAt: card.updatedAt,
    );
  }
}

final operationSyncRepoProvider = Provider<OperationSyncRepository>((ref) {
  return OperationSyncRepository(
    ref.watch(deckApiProvider),
    ref.watch(lessonApiProvider),
    ref.watch(databaseProvider),
  );
});

// ─── Reviews (offline-first) ─────────────────────────────────
class ReviewRepository {
  ReviewRepository(this._api, this._db);

  final ReviewApi _api;
  final AppDatabase _db;

  /// Aplica SM-2 localmente, atualiza o card e enfileira o review pra sync.
  /// Retorna o card com SM-2 já atualizado.
  Future<CardRow> gradeOffline({
    required CardRow card,
    required int quality,
    required int timeSpentMs,
  }) async {
    final next = applySm2(
      easeFactor: card.easeFactor,
      intervalDays: card.intervalDays,
      repetitions: card.repetitions,
      quality: quality,
    );
    await _db.updateCardSm2(
      card.id,
      easeFactor: next.easeFactor,
      intervalDays: next.intervalDays,
      repetitions: next.repetitions,
      nextReview: next.nextReview,
    );
    await _db.refreshDueCountForDeck(card.deckId);
    await _db.enqueueReview(
      cardId: card.id,
      quality: quality,
      timeSpentMs: timeSpentMs,
    );
    return card.copyWith(
      easeFactor: next.easeFactor,
      intervalDays: next.intervalDays,
      repetitions: next.repetitions,
      nextReview: next.nextReview,
    );
  }

  /// Esvazia a fila enviando cada review para o backend.
  Future<int> flushPending() async {
    final pendings = await _db.pendingReviewsAll();
    var sent = 0;
    for (final p in pendings) {
      try {
        await _api.submit(
          cardId: p.cardId,
          quality: p.quality,
          timeSpentMs: p.timeSpentMs,
        );
        await _db.deletePendingReview(p.id);
        sent++;
      } catch (_) {
        break; // sem rede / erro: para e tenta depois
      }
    }
    return sent;
  }

  Future<int> pendingCount() => _db.countPendingReviews();
}

final reviewRepoProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(
    ref.watch(reviewApiProvider),
    ref.watch(databaseProvider),
  );
});

// ─── SM-2 (puro) ─────────────────────────────────────────────
class Sm2Result {
  Sm2Result(
      this.easeFactor, this.intervalDays, this.repetitions, this.nextReview);
  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime nextReview;
}

Sm2Result applySm2({
  required double easeFactor,
  required int intervalDays,
  required int repetitions,
  required int quality,
}) {
  int reps = repetitions;
  int interval = intervalDays;
  double ef = easeFactor;

  if (quality < 3) {
    reps = 0;
    interval = 1;
  } else {
    if (reps == 0) {
      interval = 1;
    } else if (reps == 1) {
      interval = 6;
    } else {
      interval = (interval * ef).round();
    }
    reps = reps + 1;
  }

  ef = ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  if (ef < 1.3) ef = 1.3;

  final today = DateTime.now();
  final next = DateTime(today.year, today.month, today.day + interval);
  return Sm2Result(ef, interval, reps, next);
}
