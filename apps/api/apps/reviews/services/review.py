"""Orquestração: aplica SM-2, persiste Review, atualiza UserProgress/streak."""
from __future__ import annotations

import uuid
from datetime import date, timedelta
from typing import Optional

import structlog
from django.db import transaction
from django.db.models import Exists, OuterRef, QuerySet
from django.utils import timezone

from apps.decks.models import Card
from apps.microlearning.models import MicroLesson, UserLessonCompletion
from apps.reviews.models import Review
from apps.users.models import User, UserProgress

from apps.microlearning.services import deck_requires_microlesson_gate

from .sm2 import SM2Result, calculate_sm2

logger = structlog.get_logger(__name__)


class ReviewError(Exception):
    def __init__(self, detail: str):
        self.detail = detail
        super().__init__(detail)


class ReviewBlockedError(ReviewError):
    """Card existe, mas regra de negócio impede revisão (ex.: micro-lição pendente)."""


def queryset_exclude_microlesson_gate(qs: QuerySet[Card], user: User) -> QuerySet[Card]:
    """
    Remove cards novos de decks com micro-lição quando o usuário ainda não
    concluiu nenhuma lição nesse deck — mesmo que `next_review` esteja ≤ hoje
    (defesa contra inconsistência de timezone / dados legados).
    """
    return qs.annotate(
        _deck_has_lesson=Exists(
            MicroLesson.objects.filter(deck_id=OuterRef("deck_id")),
        ),
        _user_completed_lesson_here=Exists(
            UserLessonCompletion.objects.filter(
                user=user,
                lesson__deck_id=OuterRef("deck_id"),
            ),
        ),
    ).exclude(
        repetitions=0,
        _deck_has_lesson=True,
        _user_completed_lesson_here=False,
    )


# ─── Due cards ───────────────────────────────────────────────
def list_due_cards(
    user: User, *, deck_id: Optional[uuid.UUID] = None, today: Optional[date] = None
) -> QuerySet[Card]:
    """
    Retorna cards com `next_review <= hoje` do usuário. O PRD pede ordem
    `ease_factor ASC` (mais difíceis primeiro), com desempate determinístico.

    Cards novos (`repetitions == 0`) em deck com micro-lição ficam fora da lista
    até o usuário concluir pelo menos uma lição nesse deck.
    """
    today = today or timezone.now().date()
    qs = Card.objects.filter(
        deck__user=user,
        deck__is_archived=False,
        next_review__lte=today,
    )
    if deck_id is not None:
        qs = qs.filter(deck_id=deck_id)
    qs = queryset_exclude_microlesson_gate(qs, user)
    return qs.select_related("deck").order_by("ease_factor", "next_review", "id")


# ─── Submit review ───────────────────────────────────────────
def _get_user_card(user: User, card_id: uuid.UUID) -> Card:
    card = (
        Card.objects.select_related("deck")
        .filter(pk=card_id, deck__user=user, deck__is_archived=False)
        .first()
    )
    if card is None:
        raise ReviewError("Card não encontrado.")
    return card


def _update_streak(progress: UserProgress, today: date) -> None:
    """Atualiza current/longest streak baseado em `last_review_date`."""
    last = progress.last_review_date
    if last == today:
        # Mais de um review no mesmo dia não afeta streak.
        pass
    elif last == today - timedelta(days=1):
        progress.current_streak += 1
    else:
        # Primeira revisão ou sequência quebrada.
        progress.current_streak = 1
    progress.longest_streak = max(progress.longest_streak, progress.current_streak)
    progress.last_review_date = today


@transaction.atomic
def submit_review(
    user: User,
    card_id: uuid.UUID,
    *,
    quality: int,
    time_spent_ms: int = 0,
    today: Optional[date] = None,
) -> tuple[Card, Review, SM2Result]:
    """
    Aplica SM-2 no card, cria um Review e atualiza o progresso do usuário.
    Tudo numa transação atômica para garantir consistência.
    """
    today = today or timezone.now().date()
    card = _get_user_card(user, card_id)

    if card.repetitions == 0 and deck_requires_microlesson_gate(user, card.deck):
        raise ReviewBlockedError(
            "Conclua pelo menos uma micro-lição neste deck antes de revisar estes cards."
        )

    result = calculate_sm2(
        quality=quality,
        ease_factor=card.ease_factor,
        interval=card.interval,
        repetitions=card.repetitions,
        today=today,
    )

    card.ease_factor = result.ease_factor
    card.interval = result.interval
    card.repetitions = result.repetitions
    card.next_review = result.next_review
    card.save(
        update_fields=[
            "ease_factor",
            "interval",
            "repetitions",
            "next_review",
            "updated_at",
        ]
    )

    review = Review.objects.create(
        card=card,
        user=user,
        quality=quality,
        time_spent_ms=time_spent_ms,
    )

    # UserProgress é criado no register; get_or_create garante robustez caso
    # o usuário tenha sido importado por outra via.
    progress, _ = UserProgress.objects.get_or_create(user=user)
    _update_streak(progress, today)
    progress.total_reviews = (progress.total_reviews or 0) + 1
    progress.save()

    logger.info(
        "review.submitted",
        user_id=str(user.id),
        card_id=str(card.id),
        quality=quality,
        ease_factor=result.ease_factor,
        interval=result.interval,
        next_review=str(result.next_review),
        time_spent_ms=time_spent_ms,
    )

    return card, review, result


# ─── Summary diário ──────────────────────────────────────────
def daily_summary(user: User, *, day: Optional[date] = None) -> dict:
    day = day or timezone.now().date()
    start = timezone.make_aware(
        timezone.datetime.combine(day, timezone.datetime.min.time())
    )
    end = start + timedelta(days=1)

    qs = Review.objects.filter(user=user, reviewed_at__gte=start, reviewed_at__lt=end)
    reviewed = qs.count()
    correct = qs.filter(quality__gte=3).count()
    time_total_ms = sum(qs.values_list("time_spent_ms", flat=True))

    return {
        "date": day,
        "reviewed": reviewed,
        "correct": correct,
        "time_total_ms": time_total_ms,
    }
