"""Integração: register → login → me → refresh → logout."""
from __future__ import annotations

import pytest

pytestmark = pytest.mark.django_db


def test_register_creates_user_and_returns_tokens(api):
    res = api.post(
        "/api/v1/auth/register",
        {"email": "newbie@example.com", "password": "Senha12345", "name": "Novo"},
    )
    assert res.status_code == 201, res.content
    body = res.json()
    assert body["user"]["email"] == "newbie@example.com"
    assert body["tokens"]["access_token"]
    assert body["tokens"]["refresh_token"]


def test_login_then_me_returns_authenticated_user(api, user):
    login = api.post(
        "/api/v1/auth/login",
        {"email": user.email, "password": "Senha1234"},
    )
    assert login.status_code == 200, login.content
    access = login.json()["tokens"]["access_token"]

    me = api.get(
        "/api/v1/auth/me",
        headers={"HTTP_AUTHORIZATION": f"Bearer {access}"},
    )
    assert me.status_code == 200
    assert me.json()["email"] == user.email


def test_login_with_wrong_password_returns_401(api, user):
    res = api.post(
        "/api/v1/auth/login",
        {"email": user.email, "password": "errada-de-proposito"},
    )
    assert res.status_code == 401
    assert "Credenciais" in res.json()["detail"]


def test_refresh_rotates_token(api, user):
    login = api.post(
        "/api/v1/auth/login",
        {"email": user.email, "password": "Senha1234"},
    ).json()
    refresh = login["tokens"]["refresh_token"]

    res = api.post("/api/v1/auth/refresh", {"refresh_token": refresh})
    assert res.status_code == 200
    body = res.json()
    assert body["access_token"] and body["access_token"] != login["tokens"]["access_token"]


def test_me_requires_auth(api):
    res = api.get("/api/v1/auth/me")
    assert res.status_code == 401


def test_response_includes_timing_headers(api, user):
    res = api.post(
        "/api/v1/auth/login",
        {"email": user.email, "password": "Senha1234"},
    )
    assert "X-Response-Time" in res
    assert "X-Request-Id" in res
    assert res["X-Response-Time"].endswith("ms")
