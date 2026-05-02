"""Cards novos ficam bloqueados em /review/d até micro-lição ser concluída no deck."""
from __future__ import annotations

from datetime import timedelta

import pytest
from django.utils import timezone

from apps.decks.models import Card, Deck
from apps.microlearning.models import MicroLesson

pytestmark = pytest.mark.django_db


def test_due_hides_new_cards_when_microlesson_pending(api_user, user):
    deck = Deck.objects.create(user=user, title="Deck ML", color="#6366F1")
    MicroLesson.objects.create(deck=deck, title="Lição 1", order=0)
    today = timezone.now().date()
    Card.objects.create(
        deck=deck,
        front="Q",
        back="A",
        repetitions=0,
        next_review=today,
    )

    res = api_user.get("/api/v1/review/due")
    assert res.status_code == 200
    assert res.json()["total_due"] == 0


def test_submit_review_returns_400_when_microlesson_pending(api_user, user):
    deck = Deck.objects.create(user=user, title="Deck ML", color="#6366F1")
    MicroLesson.objects.create(deck=deck, title="Lição 1", order=0)
    today = timezone.now().date()
    card = Card.objects.create(
        deck=deck,
        front="Q",
        back="A",
        repetitions=0,
        next_review=today,
    )

    res = api_user.post(
        f"/api/v1/review/{card.id}",
        {"quality": 4, "time_spent_ms": 0},
    )
    assert res.status_code == 400
    assert "micro" in res.json()["detail"].lower()


def test_after_lesson_complete_new_cards_appear_in_due(api_user, user):
    deck = Deck.objects.create(user=user, title="Deck ML", color="#6366F1")
    lesson = MicroLesson.objects.create(deck=deck, title="Lição 1", order=0)
    tomorrow = timezone.now().date() + timedelta(days=1)
    card = Card.objects.create(
        deck=deck,
        front="Q",
        back="A",
        repetitions=0,
        next_review=tomorrow,
    )

    assert api_user.get("/api/v1/review/due").json()["total_due"] == 0

    res_done = api_user.post(f"/api/v1/lessons/{lesson.id}/complete", {})
    assert res_done.status_code == 200

    res_due = api_user.get("/api/v1/review/due")
    assert res_due.status_code == 200
    body = res_due.json()
    assert body["total_due"] == 1
    assert body["cards"][0]["id"] == str(card.id)


def test_gate_not_applied_when_deck_has_no_lesson(api_user, user):
    deck = Deck.objects.create(user=user, title="Só cards", color="#6366F1")
    today = timezone.now().date()
    card = Card.objects.create(
        deck=deck,
        front="Q",
        back="A",
        repetitions=0,
        next_review=today,
    )

    res = api_user.get("/api/v1/review/due")
    assert res.status_code == 200
    assert res.json()["total_due"] == 1
    assert res.json()["cards"][0]["id"] == str(card.id)
