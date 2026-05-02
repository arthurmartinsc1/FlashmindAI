/// DTOs do backend FlashMind. Espelham as schemas Pydantic do Django Ninja.
class UserDto {
  UserDto({
    required this.id,
    required this.email,
    required this.name,
    required this.isEmailVerified,
  });

  final String id;
  final String email;
  final String name;
  final bool isEmailVerified;

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        isEmailVerified: (json['is_email_verified'] as bool?) ?? false,
      );
}

class TokenPair {
  TokenPair({required this.access, required this.refresh});

  final String access;
  final String refresh;

  factory TokenPair.fromJson(Map<String, dynamic> json) => TokenPair(
        access: json['access_token'] as String,
        refresh: json['refresh_token'] as String,
      );
}

class AuthResponse {
  AuthResponse({required this.user, required this.tokens});

  final UserDto user;
  final TokenPair tokens;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        user: UserDto.fromJson(json['user'] as Map<String, dynamic>),
        tokens: TokenPair.fromJson(json['tokens'] as Map<String, dynamic>),
      );
}

class ActivityPoint {
  ActivityPoint({required this.date, required this.count});
  final String date;
  final int count;

  factory ActivityPoint.fromJson(Map<String, dynamic> json) => ActivityPoint(
        date: json['date'] as String,
        count: (json['count'] as int?) ?? 0,
      );
}

class CardDistribution {
  CardDistribution(
      {required this.newCards, required this.learning, required this.mature});
  final int newCards;
  final int learning;
  final int mature;
  int get total => newCards + learning + mature;

  factory CardDistribution.fromJson(Map<String, dynamic> json) =>
      CardDistribution(
        newCards: (json['new'] as int?) ?? 0,
        learning: (json['learning'] as int?) ?? 0,
        mature: (json['mature'] as int?) ?? 0,
      );
}

class DashboardDto {
  DashboardDto({
    required this.dueToday,
    required this.reviewedToday,
    required this.reviewedWeek,
    required this.reviewedMonth,
    required this.retentionRate,
    required this.currentStreak,
    required this.longestStreak,
    required this.activityLast30Days,
    required this.cardDistribution,
  });

  final int dueToday;
  final int reviewedToday;
  final int reviewedWeek;
  final int reviewedMonth;
  final double retentionRate;
  final int currentStreak;
  final int longestStreak;
  final List<ActivityPoint> activityLast30Days;
  final CardDistribution cardDistribution;

  factory DashboardDto.fromJson(Map<String, dynamic> json) => DashboardDto(
        dueToday: (json['due_today'] as int?) ?? 0,
        reviewedToday: (json['reviewed_today'] as int?) ?? 0,
        reviewedWeek: (json['reviewed_week'] as int?) ?? 0,
        reviewedMonth: (json['reviewed_month'] as int?) ?? 0,
        retentionRate: ((json['retention_rate'] as num?) ?? 0).toDouble(),
        currentStreak: (json['current_streak'] as int?) ?? 0,
        longestStreak: (json['longest_streak'] as int?) ?? 0,
        activityLast30Days: ((json['activity_last_30_days'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(ActivityPoint.fromJson)
            .toList(),
        cardDistribution: CardDistribution.fromJson(
            (json['card_distribution'] as Map<String, dynamic>?) ?? {}),
      );
}

class DeckDto {
  DeckDto({
    required this.id,
    required this.title,
    required this.description,
    required this.color,
    required this.cardCount,
    required this.dueCount,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final String color;
  final int cardCount;
  final int dueCount;
  final DateTime updatedAt;

  factory DeckDto.fromJson(Map<String, dynamic> json) => DeckDto(
        id: json['id'] as String,
        title: json['title'] as String,
        description: (json['description'] as String?) ?? '',
        color: (json['color'] as String?) ?? '#6366F1',
        cardCount: (json['card_count'] as int?) ?? 0,
        dueCount: (json['due_count'] as int?) ?? 0,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class CardDto {
  CardDto({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitions,
    required this.nextReview,
    required this.updatedAt,
  });

  final String id;
  final String deckId;
  final String front;
  final String back;
  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime nextReview;
  final DateTime updatedAt;

  factory CardDto.fromJson(Map<String, dynamic> json) => CardDto(
        id: json['id'] as String,
        deckId: json['deck_id'] as String,
        front: json['front'] as String,
        back: json['back'] as String,
        easeFactor: (json['ease_factor'] as num).toDouble(),
        intervalDays: json['interval'] as int,
        repetitions: json['repetitions'] as int,
        nextReview: DateTime.parse(json['next_review'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class AsyncJobDto {
  AsyncJobDto({
    required this.id,
    required this.status,
    required this.result,
    required this.error,
  });

  final String id;
  final String status;
  final Map<String, dynamic>? result;
  final String error;

  bool get isRunning => status == 'pending' || status == 'running';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  factory AsyncJobDto.fromJson(Map<String, dynamic> json) => AsyncJobDto(
        id: json['id'] as String,
        status: json['status'] as String,
        result: json['result'] as Map<String, dynamic>?,
        error: (json['error'] as String?) ?? '',
      );
}

class LessonSummaryDto {
  LessonSummaryDto({
    required this.id,
    required this.deckId,
    required this.title,
    required this.order,
    required this.estimatedMinutes,
    required this.completed,
  });

  final String id;
  final String deckId;
  final String title;
  final int order;
  final int estimatedMinutes;
  final bool completed;

  factory LessonSummaryDto.fromJson(Map<String, dynamic> json) =>
      LessonSummaryDto(
        id: json['id'] as String,
        deckId: json['deck_id'] as String,
        title: json['title'] as String,
        order: (json['order'] as int?) ?? 0,
        estimatedMinutes: (json['estimated_minutes'] as int?) ?? 5,
        completed: (json['completed'] as bool?) ?? false,
      );
}

class ContentBlockDto {
  ContentBlockDto({
    required this.id,
    required this.type,
    required this.order,
    required this.content,
  });

  final String id;
  final String type;
  final int order;
  final Map<String, dynamic> content;

  factory ContentBlockDto.fromJson(Map<String, dynamic> json) =>
      ContentBlockDto(
        id: json['id'] as String,
        type: json['type'] as String,
        order: (json['order'] as int?) ?? 0,
        content: (json['content'] as Map).cast<String, dynamic>(),
      );
}

class LessonDetailDto extends LessonSummaryDto {
  LessonDetailDto({
    required super.id,
    required super.deckId,
    required super.title,
    required super.order,
    required super.estimatedMinutes,
    required super.completed,
    required this.blocks,
  });

  final List<ContentBlockDto> blocks;

  factory LessonDetailDto.fromJson(Map<String, dynamic> json) =>
      LessonDetailDto(
        id: json['id'] as String,
        deckId: json['deck_id'] as String,
        title: json['title'] as String,
        order: (json['order'] as int?) ?? 0,
        estimatedMinutes: (json['estimated_minutes'] as int?) ?? 5,
        completed: (json['completed'] as bool?) ?? false,
        blocks: ((json['blocks'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(ContentBlockDto.fromJson)
            .toList(),
      );
}

class CompleteLessonDto {
  CompleteLessonDto({
    required this.lessonId,
    required this.alreadyCompleted,
    required this.unlockedCardsCount,
  });

  final String lessonId;
  final bool alreadyCompleted;
  final int unlockedCardsCount;

  factory CompleteLessonDto.fromJson(Map<String, dynamic> json) =>
      CompleteLessonDto(
        lessonId: json['lesson_id'] as String,
        alreadyCompleted: (json['already_completed'] as bool?) ?? false,
        unlockedCardsCount: (json['unlocked_cards_count'] as int?) ?? 0,
      );
}
