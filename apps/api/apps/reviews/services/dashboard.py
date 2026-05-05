"""Agrega as métricas do dashboard (PRD F5) em uma consulta por bloco."""
from __future__ import annotations

from datetime import date, timedelta
from typing import Optional

from django.core.cache import cache
from django.db.models import Count, Q
from django.db.models.functions import TruncDate
from django.utils import timezone

from apps.core.cache import TTL_DASHBOARD, dashboard_key
from apps.decks.models import Card
from apps.reviews.models import Review
from apps.reviews.services.review import queryset_exclude_microlesson_gate
from apps.users.models import User, UserProgress

# Limiar (em dias) que separa cards "aprendendo" de "maduros" — PRD F5.
MATURE_INTERVAL_DAYS = 21


def _range(user: User, start: date, end_exclusive: date):
    start_dt = timezone.make_aware(
        timezone.datetime.combine(start, timezone.datetime.min.time())
    )
    end_dt = timezone.make_aware(
        timezone.datetime.combine(end_exclusive, timezone.datetime.min.time())
    )
    return Review.objects.filter(
        user=user, reviewed_at__gte=start_dt, reviewed_at__lt=end_dt
    )


def _build_dashboard_uncached(user: User, today: date) -> dict:
    tomorrow = today + timedelta(days=1)

    due_today = queryset_exclude_microlesson_gate(
        Card.objects.filter(
            deck__user=user, deck__is_archived=False, next_review__lte=today
        ),
        user,
    ).count()

    reviewed_today = _range(user, today, tomorrow).count()
    reviewed_week = _range(user, today - timedelta(days=6), tomorrow).count()
    reviewed_month = _range(user, today - timedelta(days=29), tomorrow).count()

    last_30 = _range(user, today - timedelta(days=29), tomorrow)
    total_30 = last_30.count()
    correct_30 = last_30.filter(quality__gte=3).count()
    retention_rate = round((correct_30 / total_30) * 100, 1) if total_30 else 0.0

    progress, _ = UserProgress.objects.get_or_create(user=user)
    current_streak = progress.current_streak
    longest_streak = progress.longest_streak

    if progress.last_review_date and progress.last_review_date < today - timedelta(days=1):
        current_streak = 0

    grouped = (
        _range(user, today - timedelta(days=29), tomorrow)
        .annotate(day=TruncDate("reviewed_at"))
        .values("day")
        .annotate(count=Count("id"))
    )
    by_day = {row["day"]: row["count"] for row in grouped}
    activity = [
        {"date": (today - timedelta(days=i)).isoformat(), "count": by_day.get(today - timedelta(days=i), 0)}
        for i in range(29, -1, -1)
    ]

    card_qs = Card.objects.filter(deck__user=user, deck__is_archived=False)
    distribution_rows = card_qs.aggregate(
        new=Count("id", filter=Q(repetitions=0)),
        learning=Count(
            "id",
            filter=Q(repetitions__gt=0, interval__lt=MATURE_INTERVAL_DAYS),
        ),
        mature=Count("id", filter=Q(interval__gte=MATURE_INTERVAL_DAYS)),
    )

    return {
        "due_today": due_today,
        "reviewed_today": reviewed_today,
        "reviewed_week": reviewed_week,
        "reviewed_month": reviewed_month,
        "retention_rate": retention_rate,
        "current_streak": current_streak,
        "longest_streak": longest_streak,
        "activity_last_30_days": activity,
        "card_distribution": distribution_rows,
    }


def build_dashboard(user: User, *, today: Optional[date] = None) -> dict:
    today = today or timezone.now().date()
    key = dashboard_key(user.pk)
    result = cache.get(key)
    if result is None:
        result = _build_dashboard_uncached(user, today)
        cache.set(key, result, timeout=TTL_DASHBOARD)
    return result
