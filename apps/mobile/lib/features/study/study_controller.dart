import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/repositories.dart';
import '../../services/sync_service.dart';

class StudyState {
  StudyState({
    required this.loading,
    required this.queue,
    required this.index,
    required this.reviewed,
    required this.correct,
    required this.wrong,
    required this.totalTimeMs,
    required this.flipped,
  });

  final bool loading;
  final List<CardRow> queue;
  final int index;
  final int reviewed;
  final int correct;
  final int wrong;
  final int totalTimeMs;
  final bool flipped;

  CardRow? get current => index < queue.length ? queue[index] : null;
  bool get finished => !loading && index >= queue.length;

  StudyState copyWith({
    bool? loading,
    List<CardRow>? queue,
    int? index,
    int? reviewed,
    int? correct,
    int? wrong,
    int? totalTimeMs,
    bool? flipped,
  }) {
    return StudyState(
      loading: loading ?? this.loading,
      queue: queue ?? this.queue,
      index: index ?? this.index,
      reviewed: reviewed ?? this.reviewed,
      correct: correct ?? this.correct,
      wrong: wrong ?? this.wrong,
      totalTimeMs: totalTimeMs ?? this.totalTimeMs,
      flipped: flipped ?? this.flipped,
    );
  }

  static final initial = StudyState(
    loading: true,
    queue: const [],
    index: 0,
    reviewed: 0,
    correct: 0,
    wrong: 0,
    totalTimeMs: 0,
    flipped: false,
  );
}

class StudyController extends AutoDisposeFamilyNotifier<StudyState, String> {
  late final String _deckId;
  DateTime _shownAt = DateTime.now();

  @override
  StudyState build(String deckId) {
    _deckId = deckId;
    Future.microtask(_load);
    return StudyState.initial;
  }

  Future<void> _load() async {
    final cards = await ref.read(cardRepoProvider).dueForDeck(_deckId);
    state = state.copyWith(
      loading: false,
      queue: cards,
      index: 0,
      reviewed: 0,
      correct: 0,
      wrong: 0,
      totalTimeMs: 0,
      flipped: false,
    );
    _shownAt = DateTime.now();
  }

  void flip() {
    state = state.copyWith(flipped: !state.flipped);
  }

  Future<void> grade(int quality) async {
    final card = state.current;
    if (card == null) return;
    final spent = DateTime.now().difference(_shownAt).inMilliseconds;

    await ref.read(reviewRepoProvider).gradeOffline(
          card: card,
          quality: quality,
          timeSpentMs: spent,
        );

    state = state.copyWith(
      index: state.index + 1,
      reviewed: state.reviewed + 1,
      correct: state.correct + (quality >= 3 ? 1 : 0),
      wrong: state.wrong + (quality < 3 ? 1 : 0),
      totalTimeMs: state.totalTimeMs + spent,
      flipped: false,
    );
    _shownAt = DateTime.now();

    // Tenta despachar a fila já — se estiver offline, fica esperando.
    unawaited(ref.read(syncServiceProvider).push());
  }
}

final studyControllerProvider =
    AutoDisposeNotifierProviderFamily<StudyController, StudyState, String>(
        StudyController.new);
