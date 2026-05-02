"""Middlewares transversais.

`TimingMiddleware`:
    - Mede o tempo de cada request em ms (`time.perf_counter`).
    - Anexa o header `X-Response-Time` na resposta.
    - Loga via `structlog` com nível `info` (ok) ou `warning` (>= 1s).
    - Reporta `request.id` (UUID curto) em todo log e header `X-Request-Id`,
      útil pra correlacionar com Sentry/Datadog.

Mantemos esse middleware o mais leve possível: nada de I/O síncrono e
nenhum import pesado fora da função (executa em todo request).
"""
from __future__ import annotations

import time
import uuid
from typing import Callable

import structlog
from django.http import HttpRequest, HttpResponse

logger = structlog.get_logger("http")

_HEALTH_PATHS = ("/api/v1/health", "/admin/jsi18n/")


class TimingMiddleware:
    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        request_id = (
            request.headers.get("X-Request-Id") or uuid.uuid4().hex[:12]
        )
        request.request_id = request_id  # type: ignore[attr-defined]

        # Bind no contexto do structlog para todo log emitido na request herdar.
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

        # Health/admin static — silêncio para não poluir logs.
        if not request.path.startswith(_HEALTH_PATHS):
            level = logger.warning if elapsed_ms >= 1000 else logger.info
            level(
                "http.request",
                status=response.status_code,
                duration_ms=round(elapsed_ms, 2),
            )

        return response
