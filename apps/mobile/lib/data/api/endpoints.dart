import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import 'dio_client.dart';

class AuthApi {
  AuthApi(this._dio);
  final Dio _dio;

  Future<AuthResponse> login(String email, String password) async {
    final r = await _dio
        .post('/auth/login', data: {'email': email, 'password': password});
    return AuthResponse.fromJson(r.data as Map<String, dynamic>);
  }

  Future<AuthResponse> register(
      String name, String email, String password) async {
    final r = await _dio.post('/auth/register',
        data: {'name': name, 'email': email, 'password': password});
    return AuthResponse.fromJson(r.data as Map<String, dynamic>);
  }

  Future<UserDto> verifyEmail(String pin) async {
    final r = await _dio.post('/auth/email/verify', data: {'pin': pin});
    return UserDto.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> resendEmail() async {
    final r = await _dio.post('/auth/email/resend');
    return r.data as Map<String, dynamic>;
  }

  Future<UserDto> me() async {
    final r = await _dio.get('/auth/me');
    return UserDto.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
  }
}

class DeckApi {
  DeckApi(this._dio);
  final Dio _dio;

  Future<DeckDto> fetch(String deckId) async {
    final r = await _dio.get('/decks/$deckId');
    return DeckDto.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<DeckDto>> list() async {
    final r = await _dio.get('/decks/', queryParameters: {'limit': 100});
    final data = r.data as Map<String, dynamic>;
    final decks = (data['decks'] as List).cast<Map<String, dynamic>>();
    return decks.map(DeckDto.fromJson).toList();
  }

  Future<DeckDto> create({
    required String title,
    String? description,
    String? color,
  }) async {
    final r = await _dio.post('/decks/', data: {
      'title': title,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (color != null) 'color': color,
    });
    return DeckDto.fromJson(r.data as Map<String, dynamic>);
  }

  Future<DeckDto> update({
    required String deckId,
    String? title,
    String? description,
    String? color,
  }) async {
    final r = await _dio.put('/decks/$deckId', data: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (color != null) 'color': color,
    });
    return DeckDto.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> archive(String deckId) async {
    await _dio.delete('/decks/$deckId');
  }

  Future<List<CardDto>> cards(String deckId) async {
    final r =
        await _dio.get('/decks/$deckId/cards', queryParameters: {'limit': 100});
    final data = r.data as Map<String, dynamic>;
    final cards = (data['cards'] as List).cast<Map<String, dynamic>>();
    return cards.map(CardDto.fromJson).toList();
  }

  Future<CardDto> createCard({
    required String deckId,
    required String front,
    required String back,
  }) async {
    final r = await _dio.post('/decks/$deckId/cards', data: {
      'front': front,
      'back': back,
      'tags': <String>[],
    });
    return CardDto.fromJson(r.data as Map<String, dynamic>);
  }

  Future<CardDto> updateCard({
    required String cardId,
    required String front,
    required String back,
  }) async {
    final r = await _dio.put('/cards/$cardId', data: {
      'front': front,
      'back': back,
      'tags': <String>[],
    });
    return CardDto.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> deleteCard(String cardId) async {
    await _dio.delete('/cards/$cardId');
  }

  Future<AsyncJobDto> generateCards({
    required String deckId,
    required String topic,
    required int count,
    required String language,
    String? sourceText,
  }) async {
    final r = await _dio.post('/decks/$deckId/generate', data: {
      'topic': topic,
      'count': count,
      'language': language,
      if (sourceText != null && sourceText.trim().isNotEmpty)
        'source_text': sourceText.trim(),
    });
    return AsyncJobDto.fromJson(r.data as Map<String, dynamic>);
  }
}

class DashboardApi {
  DashboardApi(this._dio);
  final Dio _dio;

  Future<DashboardDto> fetch() async {
    final r = await _dio.get('/progress/dashboard');
    return DashboardDto.fromJson(r.data as Map<String, dynamic>);
  }
}

class ReviewApi {
  ReviewApi(this._dio);
  final Dio _dio;

  /// Envia um review. Retorna os campos atualizados do SM-2 (server source-of-truth).
  Future<Map<String, dynamic>> submit({
    required String cardId,
    required int quality,
    required int timeSpentMs,
  }) async {
    final r = await _dio.post('/review/$cardId', data: {
      'quality': quality,
      'time_spent_ms': timeSpentMs,
    });
    return r.data as Map<String, dynamic>;
  }
}

class JobApi {
  JobApi(this._dio);
  final Dio _dio;

  Future<AsyncJobDto> fetch(String jobId) async {
    final r = await _dio.get('/jobs/$jobId');
    return AsyncJobDto.fromJson(r.data as Map<String, dynamic>);
  }
}

class LessonApi {
  LessonApi(this._dio);
  final Dio _dio;

  Future<List<LessonSummaryDto>> list(String deckId) async {
    final r = await _dio.get('/decks/$deckId/lessons');
    final data = r.data as Map<String, dynamic>;
    final lessons = (data['lessons'] as List).cast<Map<String, dynamic>>();
    return lessons.map(LessonSummaryDto.fromJson).toList();
  }

  Future<LessonDetailDto> fetch(String lessonId) async {
    final r = await _dio.get('/lessons/$lessonId');
    return LessonDetailDto.fromJson(r.data as Map<String, dynamic>);
  }

  Future<CompleteLessonDto> complete(String lessonId) async {
    final r = await _dio.post('/lessons/$lessonId/complete');
    return CompleteLessonDto.fromJson(r.data as Map<String, dynamic>);
  }
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(apiClientProvider).dio);
});

final deckApiProvider = Provider<DeckApi>((ref) {
  return DeckApi(ref.watch(apiClientProvider).dio);
});

final reviewApiProvider = Provider<ReviewApi>((ref) {
  return ReviewApi(ref.watch(apiClientProvider).dio);
});

final dashboardApiProvider = Provider<DashboardApi>((ref) {
  return DashboardApi(ref.watch(apiClientProvider).dio);
});

final jobApiProvider = Provider<JobApi>((ref) {
  return JobApi(ref.watch(apiClientProvider).dio);
});

final lessonApiProvider = Provider<LessonApi>((ref) {
  return LessonApi(ref.watch(apiClientProvider).dio);
});
