"""Fixtures compartilhadas para os testes de integração HTTP.

Usamos o `Client` do Django (não o `TestClient` do Ninja) porque ele
exercita o stack completo: middlewares, CORS, JWT real, etc — só assim
um teste merece ser chamado de "integração".
"""
from __future__ import annotations

import json
from typing import Any

import pytest
from django.test import Client
from rest_framework_simplejwt.tokens import RefreshToken

from apps.users.models import User, UserProgress


# ─── Users ───────────────────────────────────────────────────
@pytest.fixture
def make_user(db):
    counter = {"i": 0}

    def _factory(email: str | None = None, password: str = "Senha1234") -> User:
        counter["i"] += 1
        email = email or f"user{counter['i']}@example.com"
        user = User.objects.create_user(
            email=email, password=password, name=f"User {counter['i']}"
        )
        UserProgress.objects.create(user=user)
        return user

    return _factory


@pytest.fixture
def user(make_user):
    return make_user()


@pytest.fixture
def other_user(make_user):
    return make_user("other@example.com")


def _bearer(user: User) -> dict[str, str]:
    refresh = RefreshToken.for_user(user)
    return {"HTTP_AUTHORIZATION": f"Bearer {refresh.access_token}"}


# ─── HTTP client ─────────────────────────────────────────────
class ApiClient:
    """Wrapper fino sobre Django Client com helpers de auth + JSON."""

    def __init__(self, raw: Client, user: User | None = None):
        self._raw = raw
        self._user = user

    def auth_as(self, user: User) -> "ApiClient":
        return ApiClient(self._raw, user=user)

    def _hdrs(self, extra: dict[str, str] | None = None) -> dict[str, str]:
        h: dict[str, str] = {}
        if self._user is not None:
            h.update(_bearer(self._user))
        if extra:
            h.update(extra)
        return h

    def get(self, url: str, **kw: Any):
        return self._raw.get(url, **self._hdrs(kw.pop("headers", None)), **kw)

    def post(self, url: str, data: Any = None, **kw: Any):
        return self._raw.post(
            url,
            data=json.dumps(data) if data is not None else "",
            content_type="application/json",
            **self._hdrs(kw.pop("headers", None)),
            **kw,
        )

    def put(self, url: str, data: Any = None, **kw: Any):
        return self._raw.put(
            url,
            data=json.dumps(data) if data is not None else "",
            content_type="application/json",
            **self._hdrs(kw.pop("headers", None)),
            **kw,
        )

    def delete(self, url: str, **kw: Any):
        return self._raw.delete(url, **self._hdrs(kw.pop("headers", None)), **kw)


@pytest.fixture
def api(db) -> ApiClient:
    return ApiClient(Client())


@pytest.fixture
def api_user(api: ApiClient, user: User) -> ApiClient:
    return api.auth_as(user)
