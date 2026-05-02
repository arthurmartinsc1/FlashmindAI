"""Integração: due cards + submit review aplica SM-2 e atualiza next_review."""
from __future__ import annotations

from datetime import date, timedelta

import pytest

from apps.decks.models import Card, Deck

pytestmark = pytest.mark.django_db


def _create_deck_with_due_card(user) -> Card:
    deck = Deck.objects.create(user=user, title="Quiz", color="#6366F1")
    return Card.objects.create(
        deck=deck,
        front="Capital do Brasil?",
        back="Brasília",
        next_review=date.today() - timedelta(days=1),
    )


def test_due_endpoint_returns_only_due_cards(api_user, user):
    card = _create_deck_with_due_card(user)
    Card.objects.create(
        deck=card.deck, front="Futuro", back="...",
        next_review=date.today() + timedelta(days=10),
    )

    res = api_user.get("/api/v1/review/due")
    assert res.status_code == 200
    body = res.json()
    assert body["total_due"] == 1
    assert body["cards"][0]["id"] == str(card.id)


def test_submit_review_quality_5_pushes_next_review_into_future(api_user, user):
    card = _create_deck_with_due_card(user)

    res = api_user.post(
        f"/api/v1/review/{card.id}",
        {"quality": 5, "time_spent_ms": 1234},
    )
    assert res.status_code == 200, res.content
    body = res.json()
    assert body["card_id"] == str(card.id)
    assert body["repetitions"] == 1
    # Acerto no primeiro card → interval = 1.
    assert body["interval"] == 1

    next_review = date.fromisoformat(body["next_review"])
    assert next_review > date.today()


def test_submit_review_quality_0_resets_repetitions(api_user, user):
    card = _create_deck_with_due_card(user)
    card.repetitions = 4
    card.interval = 30
    card.save()

    res = api_user.post(
        f"/api/v1/review/{card.id}",
        {"quality": 0, "time_spent_ms": 0},
    )
    assert res.status_code == 200
    body = res.json()
    assert body["repetitions"] == 0
    assert body["interval"] == 1


def test_submit_review_invalid_quality_returns_422(api_user, user):
    card = _create_deck_with_due_card(user)
    res = api_user.post(f"/api/v1/review/{card.id}", {"quality": 9})
    assert res.status_code == 422


def test_submit_review_for_other_users_card_returns_404(api, user, other_user):
    card = _create_deck_with_due_card(other_user)
    res = api.auth_as(user).post(f"/api/v1/review/{card.id}", {"quality": 4})
    assert res.status_code == 404
