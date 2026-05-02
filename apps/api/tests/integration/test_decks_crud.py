"""Integração: CRUD de decks + ownership."""
from __future__ import annotations

import pytest

from apps.decks.models import Deck

pytestmark = pytest.mark.django_db


def test_create_list_get_update_delete_deck(api_user):
    # CREATE
    res = api_user.post(
        "/api/v1/decks/",
        {"title": "Inglês", "description": "Vocab", "color": "#22C55E"},
    )
    assert res.status_code == 201, res.content
    deck = res.json()
    deck_id = deck["id"]
    assert deck["title"] == "Inglês"
    assert deck["card_count"] == 0
    assert deck["due_count"] == 0

    # LIST
    res = api_user.get("/api/v1/decks/")
    assert res.status_code == 200
    assert res.json()["count"] == 1
    assert res.json()["decks"][0]["id"] == deck_id

    # GET
    res = api_user.get(f"/api/v1/decks/{deck_id}")
    assert res.status_code == 200
    assert res.json()["title"] == "Inglês"

    # UPDATE
    res = api_user.put(f"/api/v1/decks/{deck_id}", {"title": "Inglês — Pro"})
    assert res.status_code == 200
    assert res.json()["title"] == "Inglês — Pro"

    # DELETE (soft)
    res = api_user.delete(f"/api/v1/decks/{deck_id}")
    assert res.status_code == 204

    # Após archive, /decks/ não retorna mais o deck
    res = api_user.get("/api/v1/decks/")
    assert res.json()["count"] == 0


def test_user_cannot_read_others_private_deck(api, user, other_user):
    """Deck do `other_user` não público — `user` recebe 404."""
    private = Deck.objects.create(
        user=other_user, title="Privado", color="#000000"
    )

    api_as_user = api.auth_as(user)
    res = api_as_user.get(f"/api/v1/decks/{private.id}")
    assert res.status_code == 404


def test_create_card_in_deck_then_list(api_user):
    deck = api_user.post("/api/v1/decks/", {"title": "Mat"}).json()
    deck_id = deck["id"]

    create = api_user.post(
        f"/api/v1/decks/{deck_id}/cards",
        {"front": "2+2", "back": "4", "tags": ["soma"]},
    )
    assert create.status_code == 201
    card = create.json()
    assert card["front"] == "2+2"
    assert card["source"] == "manual"

    listing = api_user.get(f"/api/v1/decks/{deck_id}/cards")
    assert listing.status_code == 200
    assert listing.json()["count"] == 1


def test_create_deck_invalid_color_returns_422(api_user):
    res = api_user.post("/api/v1/decks/", {"title": "X", "color": "verdão"})
    assert res.status_code == 422
