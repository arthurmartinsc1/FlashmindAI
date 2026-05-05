"""Middlewares transversais.

`TimingMiddleware`:
    - Mede o tempo de cada request em ms (`time.perf_counter`).
    - Anexa o header `X-Response-Time` na resposta.
    - Loga via `structlog` com nível `info` (ok) ou `warning` (>= 1s).
    - Reporta `request.id` (UUID curto) em todo log e header `X-Request-Id`,
      útil pra correlacionar com Sentry/Datadog.

`CacheControlMiddleware`:
    - Define `Cache-Control` adequado por tipo de endpoint:
      · Rotas autenticadas  → `no-store` (não armazenar em proxy/browser)
      · Health check        → `public, max-age=30`
      · Demais GETs da API  → `no-cache, private` (revalida sempre)
    - Isso garante que qualquer CDN colocado na frente respeite as regras
      certas sem configuração extra.
"""
from __future__ import annotations

import time
import uuid
from typing import Callable

import structlog
from django.http import HttpRequest, HttpResponse

logger = structlog.get_logger("http")

_HEALTH_PATHS = ("/api/v1/health", "/admin/jsi18n/")
_API_PREFIX = "/api/v1/"


class TimingMiddleware:
    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        request_id = (
            request.headers.get("X-Request-Id") or uuid.uuid4().hex[:12]
        )
        request.request_id = request_id  # type: ignore[attr-defined]

        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(
            request_id=request_id,
            method=request.method,
            path=request.path,
        )

        start = time.perf_counter()
        try:
            response = self.get_response(request)
        except Exception:
            elapsed_ms = (time.perf_counter() - start) * 1000
            logger.exception(
                "http.request.error",
                duration_ms=round(elapsed_ms, 2),
            )
            raise

        elapsed_ms = (time.perf_counter() - start) * 1000
        response["X-Response-Time"] = f"{elapsed_ms:.2f}ms"
        response["X-Request-Id"] = request_id

        if not request.path.startswith(_HEALTH_PATHS):
            level = logger.warning if elapsed_ms >= 1000 else logger.info
            level(
                "http.request",
                status=response.status_code,
                duration_ms=round(elapsed_ms, 2),
            )

        return response


class CacheControlMiddleware:
    """Define Cache-Control adequado para cada tipo de rota da API."""

    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        response = self.get_response(request)

        # Não sobrescreve se já foi definido explicitamente.
        if "Cache-Control" in response:
            return response

        path = request.path

        if path.startswith("/api/v1/health"):
            # Health check pode ser cacheado por proxies por 30 s.
            response["Cache-Control"] = "public, max-age=30"

        elif path.startswith(_API_PREFIX):
            if request.method == "GET":
                # GETs autenticados: browser/CDN nunca armazena.
                # O cache server-side (Redis) cuida da performance.
                response["Cache-Control"] = "no-store, private"
                response["Vary"] = "Authorization"
            else:
                # POST/PUT/DELETE: sem cache.
                response["Cache-Control"] = "no-store"

        return response
