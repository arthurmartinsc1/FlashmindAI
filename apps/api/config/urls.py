"""URLs raiz do FlashMind.

Os routers específicos de cada app serão plugados em `api_v1` conforme as
features forem sendo implementadas (auth, decks, reviews, etc.).
"""
from __future__ import annotations

from django.contrib import admin
from django.db import connection
from django.http import HttpResponse, JsonResponse
from django.urls import path
from django.core.cache import cache
from ninja import NinjaAPI

from apps.decks.api import cards_router, decks_router
from apps.jobs.api import jobs_router
from apps.microlearning.api import decks_lessons_router, lessons_router
from apps.reviews.api import progress_router, review_router
from apps.users.api import router as auth_router

api_v1 = NinjaAPI(
    title="FlashMind API",
    version="1.0.0",
    description="Backend da plataforma FlashMind (flashcards + microlearning).",
    docs_url="/docs",
)

api_v1.add_router("/auth", auth_router)
api_v1.add_router("/decks", decks_router)
api_v1.add_router("/decks", decks_lessons_router)  # /decks/{id}/lessons e /decks/{id}/lessons
api_v1.add_router("/cards", cards_router)
api_v1.add_router("/review", review_router)
api_v1.add_router("/progress", progress_router)
api_v1.add_router("/lessons", lessons_router)
api_v1.add_router("/jobs", jobs_router)


@api_v1.get("/health/", tags=["Health"])
def health_check(request):
    """Health detalhado: liveness + readiness em um só payload (compat).

    Para K8s/load balancers, prefira `/health/live` (não toca em DB) e
    `/health/ready` (verifica db + redis + temporal).
    """
    return _readiness_payload(include_temporal=True)


@api_v1.get("/health/live", tags=["Health"])
def health_live(request):
    """Liveness probe: o processo respondeu? (sem checar dependências)."""
    return {"status": "ok"}


@api_v1.get("/health/ready", tags=["Health"])
def health_ready(request, response: HttpResponse = None):
    """Readiness probe: db, redis e temporal acessíveis?"""
    payload = _readiness_payload(include_temporal=True)
    return payload


def _check_temporal() -> str:
    """Conecta no Temporal só pra ver se o gRPC responde. Não levanta."""
    try:
        import asyncio

        from temporalio.client import Client
        from django.conf import settings as dj_settings

        async def _ping():
            client = await Client.connect(
                dj_settings.TEMPORAL["ADDRESS"],
                namespace=dj_settings.TEMPORAL["NAMESPACE"],
            )
            return client is not None

        ok = asyncio.run(asyncio.wait_for(_ping(), timeout=2.5))
        return "ok" if ok else "error: no client"
    except Exception as exc:  # pragma: no cover
        return f"error: {exc.__class__.__name__}"


def _readiness_payload(include_temporal: bool) -> dict:
    status: dict = {"status": "ok", "checks": {}}

    try:
        connection.ensure_connection()
        status["checks"]["database"] = "ok"
    except Exception as exc:  # pragma: no cover
        status["checks"]["database"] = f"error: {exc.__class__.__name__}"
        status["status"] = "degraded"

    try:
        cache.set("health_check", "ok", timeout=5)
        assert cache.get("health_check") == "ok"
        status["checks"]["redis"] = "ok"
    except Exception as exc:  # pragma: no cover
        status["checks"]["redis"] = f"error: {exc.__class__.__name__}"
        status["status"] = "degraded"

    if include_temporal:
        status["checks"]["temporal"] = _check_temporal()
        if status["checks"]["temporal"] != "ok":
            # Temporal indisponível não é fatal pra reads, mas marcamos.
            status["status"] = "degraded"

    return status


def root(_request):
    return JsonResponse(
        {
            "name": "FlashMind API",
            "docs": "/api/docs",
            "health": "/api/v1/health/",
        }
    )


urlpatterns = [
    path("", root),
    path("admin/", admin.site.urls),
    path("api/v1/", api_v1.urls),
]
