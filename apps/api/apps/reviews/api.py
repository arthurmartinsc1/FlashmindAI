"""Endpoints de review (PRD F4) e dashboard (PRD F5)."""
from __future__ import annotations

import uuid
from datetime import date
from typing import Optional

from ninja import Query, Router

from apps.users.security import JWTAuth

from .schemas import (
    DashboardOut,
    DueCardsOut,
    ErrorOut,
    ReviewIn,
    ReviewOut,
    ReviewSummaryOut,
)
from .services.dashboard import build_dashboard
from .services.review import (
    ReviewBlockedError,
    ReviewError,
    daily_summary,
    list_due_cards,
    submit_review,
)

jwt_auth = JWTAuth()

review_router = Router(tags=["Review"], auth=jwt_auth)
progress_router = Router(tags=["Progress"], auth=jwt_auth)


# ═════════════════════════════════════════════════════════════
#  REVIEW
# ═════════════════════════════════════════════════════════════
@review_router.get(
    "/due",
    response=DueCardsOut,
    summary="Cards para revisar hoje (opcionalmente filtrando por deck).",
)
def due_cards(
    request,
    deck_id: Optional[uuid.UUID] = Query(None),
    limit: int = Query(50, ge=1, le=200),
):
    qs = list_due_cards(request.auth, deck_id=deck_id)
    total = qs.count()
    cards = list(qs[:limit])
    return {"cards": cards, "total_due": total}


@review_router.get(
    "/summary",
    response=ReviewSummaryOut,
    summary="Resumo diário (quantos, acertos, tempo total).",
)
def summary(
    request,
    day: Optional[date] = Query(None, alias="date"),
):
    return daily_summary(request.auth, day=day)


# IMPORTANTE: esta rota com parâmetro dinâmico precisa ficar depois das
# rotas estáticas (`/due`, `/summary`) — caso contrário o matcher do Ninja
# tenta interpretar "summary" como `card_id`.
@review_router.post(
    "/{card_id}",
    response={200: ReviewOut, 400: ErrorOut, 404: ErrorOut},
    summary="Submete a avaliação de um card (aplica SM-2 e atualiza streak).",
)
def submit(request, card_id: uuid.UUID, payload: ReviewIn):
    try:
        card, _review, result = submit_review(
            request.auth,
            card_id,
            quality=payload.quality,
            time_spent_ms=payload.time_spent_ms,
        )
    except ReviewBlockedError as exc:
        return 400, {"detail": exc.detail}
    except ReviewError as exc:
        return 404, {"detail": exc.detail}
    return 200, {
        "card_id": card.id,
        "ease_factor": result.ease_factor,
        "interval": result.interval,
        "repetitions": result.repetitions,
        "next_review": result.next_review,
    }


# ═════════════════════════════════════════════════════════════
#  PROGRESS / DASHBOARD
# ═════════════════════════════════════════════════════════════
@progress_router.get(
    "/dashboard",
    response=DashboardOut,
    summary="Métricas consolidadas do usuário (streaks, retenção, heatmap).",
)
def dashboard(request):
    return build_dashboard(request.auth)
