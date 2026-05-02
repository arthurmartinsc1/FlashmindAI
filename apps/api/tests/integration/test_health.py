"""Integração: health checks e timing middleware."""
from __future__ import annotations

import pytest

pytestmark = pytest.mark.django_db


def test_health_live_is_always_ok(api):
    res = api.get("/api/v1/health/live")
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}


def test_health_ready_includes_db_check(api):
    res = api.get("/api/v1/health/ready")
    assert res.status_code == 200
    body = res.json()
    assert "database" in body["checks"]
    assert body["checks"]["database"] == "ok"


def test_health_endpoint_does_not_emit_request_log(api):
    """Smoke: o middleware não deveria explodir nas rotas de health.

    Não verificamos os logs em si (depende de captura), só que a request
    completa com headers de timing/request-id presentes.
    """
    res = api.get("/api/v1/health/")
    assert res.status_code == 200
    assert "X-Response-Time" in res
    assert "X-Request-Id" in res
