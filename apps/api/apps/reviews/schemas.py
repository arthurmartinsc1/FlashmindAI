"""Schemas Ninja de review e dashboard."""
from __future__ import annotations

import uuid
from datetime import date

from ninja import Schema
from pydantic import Field

from apps.decks.schemas import CardOut


# ═════════════════════════════════════════════════════════════
#  Review
# ═════════════════════════════════════════════════════════════
class DueCardsOut(Schema):
    cards: list[CardOut]
    total_due: int


class ReviewIn(Schema):
    quality: int = Field(ge=0, le=5, description="Auto-avaliação 0-5.")
    time_spent_ms: int = Field(default=0, ge=0)


class ReviewOut(Schema):
    """Retorno do POST /review/{card_id} — projeção enxuta para a UI avançar rápido."""

    card_id: uuid.UUID
    ease_factor: float
    interval: int
    repetitions: int
    next_review: date


class ReviewSummaryOut(Schema):
    """Resumo diário de reviews (PRD F4)."""

    date: date
    reviewed: int
    correct: int
    time_total_ms: int


class ErrorOut(Schema):
    detail: str


# ═════════════════════════════════════════════════════════════
#  Dashboard (PRD F5)
# ═════════════════════════════════════════════════════════════
class ActivityPoint(Schema):
    date: date
    count: int


class CardDistribution(Schema):
    new: int
    learning: int
    mature: int


class DashboardOut(Schema):
    due_today: int
    reviewed_today: int
    reviewed_week: int
    reviewed_month: int
    retention_rate: float  # 0-100 (%)
    current_streak: int
    longest_streak: int
    activity_last_30_days: list[ActivityPoint]
    card_distribution: CardDistribution
