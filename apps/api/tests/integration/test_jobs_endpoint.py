"""Integração: POST /decks/{id}/generate cria AsyncJob mesmo se Temporal falhar.

Mockamos o `start_workflow` pra não depender do Temporal estar de pé no CI.
Validamos que:
  - 503 quando enfileirar falha (status do job vira `failed`).
  - 202 + AsyncJobOut quando enfileirar funciona.
  - GET /jobs/{id} faz polling correto.
  - Outro user não vê o job (404).
"""
from __future__ import annotations

import pytest

from apps.decks.models import Deck
from apps.jobs.models import AsyncJob

pytestmark = pytest.mark.django_db


def test_generate_returns_503_when_temporal_unreachable(api_user, user, monkeypatch):
    deck = Deck.objects.create(user=user, title="Bio")

    def _boom(*a, **kw):
        raise ConnectionError("temporal down")

    monkeypatch.setattr("apps.jobs.services.start_workflow", _boom)

    res = api_user.post(
        f"/api/v1/decks/{deck.id}/generate",
        {"topic": "Mitose e meiose", "count": 5, "language": "pt-BR"},
    )
    assert res.status_code == 503

    # AsyncJob criado com status failed, mesmo sem Temporal.
    job = AsyncJob.objects.filter(user=user).get()
    assert job.status == AsyncJob.Status.FAILED


def test_generate_returns_202_and_creates_pending_job(api_user, user, monkeypatch):
    deck = Deck.objects.create(user=user, title="Geo")
    monkeypatch.setattr(
        "apps.jobs.services.start_workflow",
        lambda *a, **kw: ("workflow-123", "run-456"),
    )

    res = api_user.post(
        f"/api/v1/decks/{deck.id}/generate",
        {"topic": "Capitais europeias", "count": 8},
    )
    assert res.status_code == 202, res.content
    body = res.json()
    assert body["status"] == "pending"
    assert body["workflow_id"] == "workflow-123"

    # Polling endpoint
    job_id = body["id"]
    res2 = api_user.get(f"/api/v1/jobs/{job_id}")
    assert res2.status_code == 200
    assert res2.json()["id"] == job_id


def test_generate_for_unknown_deck_returns_404(api_user):
    res = api_user.post(
        "/api/v1/decks/00000000-0000-0000-0000-000000000000/generate",
        {"topic": "qualquer tópico válido", "count": 1},
    )
    assert res.status_code == 404


def test_other_user_cannot_read_job(api, user, other_user, monkeypatch):
    deck = Deck.objects.create(user=user, title="Mat")
    monkeypatch.setattr(
        "apps.jobs.services.start_workflow",
        lambda *a, **kw: ("wf", ""),
    )

    job = api.auth_as(user).post(
        f"/api/v1/decks/{deck.id}/generate", {"topic": "frações", "count": 3}
    ).json()

    res = api.auth_as(other_user).get(f"/api/v1/jobs/{job['id']}")
    assert res.status_code == 404
