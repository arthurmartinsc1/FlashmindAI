import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models.dart';

part 'database.g.dart';

// ─────────────────────────────────────────────────────────────
//  Tables
// ─────────────────────────────────────────────────────────────
@DataClassName('UserRow')
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get name => text()();
  BoolColumn get isEmailVerified =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DeckRow')
class Decks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get color => text().withDefault(const Constant('#6366F1'))();
  IntColumn get cardCount => integer().withDefault(const Constant(0))();
  IntColumn get dueCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CardRow')
class Cards extends Table {
  TextColumn get id => text()();
  TextColumn get deckId => text().references(Decks, #id)();
  TextColumn get front => text()();
  TextColumn get back => text()();
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextReview => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PendingReviewRow')
class PendingReviews extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get cardId => text()();
  IntColumn get quality => integer()();
  IntColumn get timeSpentMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('LessonRow')
class Lessons extends Table {
  TextColumn get id => text()();
  TextColumn get deckId => text().references(Decks, #id)();
  TextColumn get title => text()();
  IntColumn get order => integer().withDefault(const Constant(0))();
  IntColumn get estimatedMinutes => integer().withDefault(const Constant(5))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ContentBlockRow')
class ContentBlocks extends Table {
  TextColumn get id => text()();
  TextColumn get lessonId => text().references(Lessons, #id)();
  TextColumn get type => text()();
  IntColumn get order => integer().withDefault(const Constant(0))();
  TextColumn get contentJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PendingOperationRow')
class PendingOperations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
}

// ─────────────────────────────────────────────────────────────
//  Database
// ─────────────────────────────────────────────────────────────
@DriftDatabase(tables: [
  Users,
  Decks,
  Cards,
  PendingReviews,
  Lessons,
  ContentBlocks,
  PendingOperations,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(users);
          }
          if (from < 3) {
            await m.createTable(lessons);
            await m.createTable(contentBlocks);
          }
          if (from < 4) {
            await m.createTable(pendingOperations);
          }
        },
      );

  // ── Users ──
  Future<UserRow?> getUser() => (select(users)).getSingleOrNull();

  Future<void> upsertUser(UserRow row) =>
      into(users).insertOnConflictUpdate(row);

  Future<void> setEmailVerified({required bool verified}) =>
      (update(users)).write(UsersCompanion(isEmailVerified: Value(verified)));

  // ── Decks ──
  Future<List<DeckRow>> allDecks() =>
      (select(decks)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();

  Future<DeckRow?> deckById(String deckId) =>
      (select(decks)..where((d) => d.id.equals(deckId))).getSingleOrNull();

  Stream<DeckRow?> watchDeck(String deckId) =>
      (select(decks)..where((d) => d.id.equals(deckId))).watchSingleOrNull();

  Stream<List<DeckRow>> watchDecks() =>
      (select(decks)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  Future<void> upsertDecks(List<DeckRow> rows) async {
    await batch((b) {
      for (final d in rows) {
        b.insert(decks, d, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> replaceDecks(List<DeckRow> rows) async {
    final remoteIds = rows.map((deck) => deck.id).toSet();
    await transaction(() async {
      final existing = await allDecks();
      for (final deck in existing) {
        if (!remoteIds.contains(deck.id)) {
          await _deleteLessonsForDeck(deck.id);
          await (delete(cards)..where((c) => c.deckId.equals(deck.id))).go();
          await (delete(decks)..where((d) => d.id.equals(deck.id))).go();
        }
      }
      await upsertDecks(rows);
    });
  }

  Future<void> deleteDeck(String deckId) async {
    await transaction(() async {
      await _deleteLessonsForDeck(deckId);
      await (delete(cards)..where((c) => c.deckId.equals(deckId))).go();
      await (delete(decks)..where((d) => d.id.equals(deckId))).go();
    });
  }

  Future<void> updateDeckLocal(DeckRow row) => upsertDecks([row]);

  // ── Cards ──
  Future<void> upsertCards(List<CardRow> rows) async {
    await batch((b) {
      for (final c in rows) {
        b.insert(cards, c, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> replaceCardsForDeck(String deckId, List<CardRow> rows) async {
    final remoteIds = rows.map((card) => card.id).toSet();
    await transaction(() async {
      final existing = await cardsForDeck(deckId);
      for (final card in existing) {
        if (!remoteIds.contains(card.id)) {
          await deleteCard(card.id);
        }
      }
      await upsertCards(rows);
    });
  }

  Future<void> deleteCard(String cardId) =>
      (delete(cards)..where((c) => c.id.equals(cardId))).go();

  Future<CardRow?> cardById(String cardId) =>
      (select(cards)..where((c) => c.id.equals(cardId))).getSingleOrNull();

  Future<void> updateCardContent({
    required String cardId,
    required String front,
    required String back,
  }) async {
    await (update(cards)..where((c) => c.id.equals(cardId))).write(
      CardsCompanion(
        front: Value(front),
        back: Value(back),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<CardRow>> cardsForDeck(String deckId) {
    return (select(cards)
          ..where((c) => c.deckId.equals(deckId))
          ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)]))
        .get();
  }

  Stream<List<CardRow>> watchCardsForDeck(String deckId) {
    return (select(cards)
          ..where((c) => c.deckId.equals(deckId))
          ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)]))
        .watch();
  }

  Future<List<CardRow>> dueCardsForDeck(String deckId) {
    final today = DateTime.now();
    return (select(cards)
          ..where((c) =>
              c.deckId.equals(deckId) &
              c.nextReview.isSmallerOrEqualValue(today))
          ..orderBy([(c) => OrderingTerm.asc(c.nextReview)]))
        .get();
  }

  Future<int> countDueForDeck(String deckId) async {
    final today = DateTime.now();
    final q = selectOnly(cards)
      ..addColumns([cards.id.count()])
      ..where(cards.deckId.equals(deckId) &
          cards.nextReview.isSmallerOrEqualValue(today));
    final row = await q.getSingleOrNull();
    return row?.read(cards.id.count()) ?? 0;
  }

  Future<int> countCardsForDeck(String deckId) async {
    final q = selectOnly(cards)
      ..addColumns([cards.id.count()])
      ..where(cards.deckId.equals(deckId));
    final row = await q.getSingleOrNull();
    return row?.read(cards.id.count()) ?? 0;
  }

  Future<int> countDueCards() async {
    final today = DateTime.now();
    final q = selectOnly(cards)
      ..addColumns([cards.id.count()])
      ..where(cards.nextReview.isSmallerOrEqualValue(today));
    final row = await q.getSingleOrNull();
    return row?.read(cards.id.count()) ?? 0;
  }

  Future<DashboardDto> localDashboardSnapshot() async {
    final allCards = await select(cards).get();
    final pendingReviews = await pendingReviewsAll();
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final dueToday =
        allCards.where((card) => !card.nextReview.isAfter(today)).length;
    final reviewedToday = pendingReviews
        .where((review) => !review.createdAt.isBefore(startOfToday))
        .length;
    final reviewedWeek = pendingReviews
        .where((review) => !review.createdAt
            .isBefore(startOfToday.subtract(const Duration(days: 6))))
        .length;
    final reviewedMonth = pendingReviews
        .where((review) => !review.createdAt
            .isBefore(startOfToday.subtract(const Duration(days: 29))))
        .length;
    final recentReviews = pendingReviews
        .where((review) => !review.createdAt
            .isBefore(startOfToday.subtract(const Duration(days: 29))))
        .toList();
    final correct = recentReviews.where((review) => review.quality >= 3).length;
    final activity = List.generate(30, (idx) {
      final day = startOfToday.subtract(Duration(days: 29 - idx));
      final nextDay = day.add(const Duration(days: 1));
      final count = pendingReviews
          .where((review) =>
              !review.createdAt.isBefore(day) &&
              review.createdAt.isBefore(nextDay))
          .length;
      return ActivityPoint(
        date:
            '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
        count: count,
      );
    });

    return DashboardDto(
      dueToday: dueToday,
      reviewedToday: reviewedToday,
      reviewedWeek: reviewedWeek,
      reviewedMonth: reviewedMonth,
      retentionRate:
          recentReviews.isEmpty ? 0 : (correct / recentReviews.length * 100),
      currentStreak: reviewedToday > 0 ? 1 : 0,
      longestStreak: reviewedToday > 0 ? 1 : 0,
      activityLast30Days: activity,
      cardDistribution: CardDistribution(
        newCards: allCards.where((card) => card.repetitions == 0).length,
        learning: allCards
            .where((card) => card.repetitions > 0 && card.intervalDays < 21)
            .length,
        mature: allCards.where((card) => card.intervalDays >= 21).length,
      ),
    );
  }

  Future<int> refreshDueCountForDeck(String deckId) async {
    final due = await countDueForDeck(deckId);
    await (update(decks)..where((d) => d.id.equals(deckId))).write(
      DecksCompanion(dueCount: Value(due)),
    );
    return due;
  }

  Future<void> refreshCardStatsForDeck(String deckId) async {
    final count = await countCardsForDeck(deckId);
    final due = await countDueForDeck(deckId);
    await (update(decks)..where((d) => d.id.equals(deckId))).write(
      DecksCompanion(
        cardCount: Value(count),
        dueCount: Value(due),
      ),
    );
  }

  // ── Micro-lessons ──
  Stream<List<LessonSummaryDto>> watchLessonsForDeck(String deckId) {
    return (select(lessons)
          ..where((l) => l.deckId.equals(deckId))
          ..orderBy([(l) => OrderingTerm.asc(l.order)]))
        .watch()
        .map((rows) => rows.map(_lessonSummaryFromRow).toList());
  }

  Stream<LessonDetailDto?> watchLessonDetail(String lessonId) {
    return (select(lessons)..where((l) => l.id.equals(lessonId)))
        .watchSingleOrNull()
        .asyncMap((lesson) async {
      if (lesson == null) return null;
      final blocks = await _blocksForLesson(lessonId);
      return _lessonDetailFromRows(lesson, blocks);
    });
  }

  Future<void> replaceLessons(
    String deckId,
    List<LessonSummaryDto> remoteLessons,
  ) async {
    final remoteIds = remoteLessons.map((lesson) => lesson.id).toSet();
    await transaction(() async {
      final existing = await (select(lessons)
            ..where((lesson) => lesson.deckId.equals(deckId)))
          .get();
      for (final lesson in existing) {
        if (!remoteIds.contains(lesson.id)) {
          await _deleteLesson(lesson.id);
        }
      }
      await batch((b) {
        for (final lesson in remoteLessons) {
          b.insert(
            lessons,
            _lessonCompanion(lesson),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    });
  }

  Future<void> upsertLessonDetail(LessonDetailDto lesson) async {
    await transaction(() async {
      await into(lessons).insert(
        _lessonCompanion(lesson),
        mode: InsertMode.insertOrReplace,
      );
      await (delete(contentBlocks)
            ..where((block) => block.lessonId.equals(lesson.id)))
          .go();
      await batch((b) {
        for (final block in lesson.blocks) {
          b.insert(
            contentBlocks,
            ContentBlocksCompanion.insert(
              id: block.id,
              lessonId: lesson.id,
              type: block.type,
              order: Value(block.order),
              contentJson: jsonEncode(block.content),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    });
  }

  Future<void> markLessonCompleted(String lessonId) async {
    await (update(lessons)..where((lesson) => lesson.id.equals(lessonId)))
        .write(const LessonsCompanion(completed: Value(true)));
  }

  Future<List<ContentBlockRow>> _blocksForLesson(String lessonId) {
    return (select(contentBlocks)
          ..where((block) => block.lessonId.equals(lessonId))
          ..orderBy([(block) => OrderingTerm.asc(block.order)]))
        .get();
  }

  Future<void> _deleteLesson(String lessonId) async {
    await (delete(contentBlocks)..where((b) => b.lessonId.equals(lessonId)))
        .go();
    await (delete(lessons)..where((l) => l.id.equals(lessonId))).go();
  }

  Future<void> _deleteLessonsForDeck(String deckId) async {
    final deckLessons =
        await (select(lessons)..where((l) => l.deckId.equals(deckId))).get();
    for (final lesson in deckLessons) {
      await _deleteLesson(lesson.id);
    }
  }

  LessonsCompanion _lessonCompanion(LessonSummaryDto lesson) {
    return LessonsCompanion.insert(
      id: lesson.id,
      deckId: lesson.deckId,
      title: lesson.title,
      order: Value(lesson.order),
      estimatedMinutes: Value(lesson.estimatedMinutes),
      completed: Value(lesson.completed),
    );
  }

  LessonSummaryDto _lessonSummaryFromRow(LessonRow row) {
    return LessonSummaryDto(
      id: row.id,
      deckId: row.deckId,
      title: row.title,
      order: row.order,
      estimatedMinutes: row.estimatedMinutes,
      completed: row.completed,
    );
  }

  LessonDetailDto _lessonDetailFromRows(
    LessonRow lesson,
    List<ContentBlockRow> blocks,
  ) {
    return LessonDetailDto(
      id: lesson.id,
      deckId: lesson.deckId,
      title: lesson.title,
      order: lesson.order,
      estimatedMinutes: lesson.estimatedMinutes,
      completed: lesson.completed,
      blocks: blocks
          .map((block) => ContentBlockDto(
                id: block.id,
                type: block.type,
                order: block.order,
                content: (jsonDecode(block.contentJson) as Map)
                    .cast<String, dynamic>(),
              ))
          .toList(),
    );
  }

  Future<void> updateCardSm2(
    String cardId, {
    required double easeFactor,
    required int intervalDays,
    required int repetitions,
    required DateTime nextReview,
  }) async {
    await (update(cards)..where((c) => c.id.equals(cardId))).write(
      CardsCompanion(
        easeFactor: Value(easeFactor),
        intervalDays: Value(intervalDays),
        repetitions: Value(repetitions),
        nextReview: Value(nextReview),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── Pending reviews ──
  Future<void> enqueueReview({
    required String cardId,
    required int quality,
    required int timeSpentMs,
  }) {
    return into(pendingReviews).insert(
      PendingReviewsCompanion.insert(
        cardId: cardId,
        quality: quality,
        timeSpentMs: Value(timeSpentMs),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<List<PendingReviewRow>> pendingReviewsAll() =>
      (select(pendingReviews)..orderBy([(p) => OrderingTerm.asc(p.id)])).get();

  Future<int> countPendingReviews() async {
    final q = selectOnly(pendingReviews)
      ..addColumns([pendingReviews.id.count()]);
    final row = await q.getSingleOrNull();
    return row?.read(pendingReviews.id.count()) ?? 0;
  }

  Future<void> deletePendingReview(int id) =>
      (delete(pendingReviews)..where((p) => p.id.equals(id))).go();

  Future<void> replacePendingReviewCardId({
    required String fromId,
    required String toId,
  }) async {
    await (update(pendingReviews)..where((p) => p.cardId.equals(fromId)))
        .write(PendingReviewsCompanion(cardId: Value(toId)));
  }

  Future<void> clearAll() async {
    await transaction(() async {
      await delete(pendingOperations).go();
      await delete(pendingReviews).go();
      await delete(contentBlocks).go();
      await delete(lessons).go();
      await delete(cards).go();
      await delete(decks).go();
      await delete(users).go();
    });
  }

  // ── Pending operations ──
  Future<void> enqueueOperation({
    required String type,
    required Map<String, dynamic> payload,
  }) {
    return into(pendingOperations).insert(
      PendingOperationsCompanion.insert(
        type: type,
        payloadJson: jsonEncode(payload),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<List<PendingOperationRow>> pendingOperationsAll() {
    return (select(pendingOperations)
          ..orderBy([(op) => OrderingTerm.asc(op.id)]))
        .get();
  }

  Future<int> countPendingOperations() async {
    final q = selectOnly(pendingOperations)
      ..addColumns([pendingOperations.id.count()]);
    final row = await q.getSingleOrNull();
    return row?.read(pendingOperations.id.count()) ?? 0;
  }

  Future<void> deletePendingOperation(int id) =>
      (delete(pendingOperations)..where((op) => op.id.equals(id))).go();

  Future<void> replacePendingOperationReference({
    required String fromId,
    required String toId,
  }) async {
    final ops = await pendingOperationsAll();
    for (final op in ops) {
      if (!op.payloadJson.contains(fromId)) continue;
      await (update(pendingOperations)..where((row) => row.id.equals(op.id)))
          .write(
        PendingOperationsCompanion(
          payloadJson: Value(op.payloadJson.replaceAll(fromId, toId)),
        ),
      );
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'flashmind.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
