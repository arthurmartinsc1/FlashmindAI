import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flashmind_mobile/data/api/endpoints.dart';
import 'package:flashmind_mobile/data/db/database.dart';
import 'package:flashmind_mobile/data/repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('review repository', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('gradeOffline updates due count and queues a pending review',
        () async {
      final card = await _seedDeckAndCard(db);
      final repo = ReviewRepository(ReviewApi(_jsonDio((_) => _json({}))), db);

      await repo.gradeOffline(card: card, quality: 5, timeSpentMs: 1200);

      expect(await db.countDueForDeck(card.deckId), 0);
      expect(await db.countPendingReviews(), 1);

      final updated = await db.cardById(card.id);
      expect(updated, isNotNull);
      expect(updated!.repetitions, 1);
      expect(updated.nextReview.isAfter(DateTime.now()), isTrue);
    });

    test('flushPending submits reviews and clears the review queue', () async {
      final card = await _seedDeckAndCard(db);
      await db.enqueueReview(cardId: card.id, quality: 4, timeSpentMs: 900);
      final adapter = _JsonAdapter((_) => _json({}));
      final repo = ReviewRepository(ReviewApi(_dioWithAdapter(adapter)), db);

      final sent = await repo.flushPending();

      expect(sent, 1);
      expect(await db.countPendingReviews(), 0);
      expect(adapter.requests.single.path, '/review/${card.id}');
      expect(adapter.requests.single.method, 'POST');
    });
  });

  group('dashboard repository', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('keeps local dueToday after local reviews even when backend is stale',
        () async {
      final card = await _seedDeckAndCard(db);
      final reviewRepo =
          ReviewRepository(ReviewApi(_jsonDio((_) => _json({}))), db);
      await reviewRepo.gradeOffline(card: card, quality: 5, timeSpentMs: 1000);

      final dashboardRepo = DashboardRepository(
        DashboardApi(_jsonDio((_) => _json(_dashboardJson(dueToday: 16)))),
        db,
      );

      final values = await dashboardRepo.watchLocalFirst().take(2).toList();

      expect(values.first.dueToday, 0);
      expect(values.last.dueToday, 0);
      expect(values.last.reviewedToday, 1);
    });
  });

  group('pending operations sync', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('CardRepository stores a local card and queues create when offline',
        () async {
      await _seedDeck(db);
      final repo = CardRepository(
        DeckApi(_jsonDio((_) => _json({'detail': 'offline'}, statusCode: 503))),
        db,
      );

      await repo.createCard(
        deckId: 'deck-1',
        front: 'Pergunta local',
        back: 'Resposta local',
      );

      final cards = await db.cardsForDeck('deck-1');
      expect(cards, hasLength(1));
      expect(cards.single.id, startsWith('local-card-'));
      expect(cards.single.front, 'Pergunta local');
      expect(await db.countPendingOperations(), 1);
    });

    test('OperationSyncRepository sends queued card creates and rewrites ids',
        () async {
      await _seedDeck(db);
      await db.upsertCards([
        CardRow(
          id: 'local-card-1',
          deckId: 'deck-1',
          front: 'Frente',
          back: 'Verso',
          easeFactor: 2.5,
          intervalDays: 0,
          repetitions: 0,
          nextReview: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);
      await db.enqueueReview(
        cardId: 'local-card-1',
        quality: 5,
        timeSpentMs: 400,
      );
      await db.enqueueOperation(
        type: 'card.create',
        payload: {
          'local_id': 'local-card-1',
          'deck_id': 'deck-1',
          'front': 'Frente',
          'back': 'Verso',
        },
      );

      final adapter = _JsonAdapter((options) {
        expect(options.path, '/decks/deck-1/cards');
        return _json(_cardJson(id: 'card-remote-1'));
      });
      final repo = OperationSyncRepository(
        DeckApi(_jsonDio(adapter.handle)),
        LessonApi(_jsonDio((_) => _json({}))),
        db,
      );

      final sent = await repo.flushPending();

      expect(sent, 1);
      expect(await db.countPendingOperations(), 0);
      expect(await db.cardById('local-card-1'), isNull);
      expect(await db.cardById('card-remote-1'), isNotNull);
      expect((await db.pendingReviewsAll()).single.cardId, 'card-remote-1');
    });
  });
}

Future<void> _seedDeck(AppDatabase db) {
  return db.upsertDecks([
    DeckRow(
      id: 'deck-1',
      title: 'Deck',
      description: '',
      color: '#6366F1',
      cardCount: 0,
      dueCount: 0,
      updatedAt: DateTime.now(),
    ),
  ]);
}

Future<CardRow> _seedDeckAndCard(AppDatabase db) async {
  await _seedDeck(db);
  final card = CardRow(
    id: 'card-1',
    deckId: 'deck-1',
    front: 'Frente',
    back: 'Verso',
    easeFactor: 2.5,
    intervalDays: 0,
    repetitions: 0,
    nextReview: DateTime.now().subtract(const Duration(minutes: 1)),
    updatedAt: DateTime.now(),
  );
  await db.upsertCards([card]);
  await db.refreshCardStatsForDeck('deck-1');
  return card;
}

Dio _jsonDio(FutureOr<_FakeResponse> Function(RequestOptions) handler) {
  return _dioWithAdapter(_JsonAdapter(handler));
}

Dio _dioWithAdapter(_JsonAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handle);

  final FutureOr<_FakeResponse> Function(RequestOptions) handle;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = await handle(options);
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeResponse {
  _FakeResponse(this.body, this.statusCode);

  final Object body;
  final int statusCode;
}

_FakeResponse _json(Object body, {int statusCode = 200}) {
  return _FakeResponse(body, statusCode);
}

Map<String, dynamic> _cardJson({required String id}) {
  return {
    'id': id,
    'deck_id': 'deck-1',
    'front': 'Frente',
    'back': 'Verso',
    'ease_factor': 2.5,
    'interval': 0,
    'repetitions': 0,
    'next_review': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  };
}

Map<String, dynamic> _dashboardJson({required int dueToday}) {
  return {
    'due_today': dueToday,
    'reviewed_today': 0,
    'reviewed_week': 0,
    'reviewed_month': 0,
    'retention_rate': 0,
    'current_streak': 0,
    'longest_streak': 0,
    'activity_last_30_days': <Map<String, dynamic>>[],
    'card_distribution': {
      'new': 0,
      'learning': 0,
      'mature': 0,
    },
  };
}
