"""Schemas Ninja para os módulos `decks` e `cards`."""
from __future__ import annotations

import re
import uuid
from datetime import date, datetime
from typing import Optional

from ninja import Schema
from pydantic import Field, field_validator

HEX_COLOR_RE = re.compile(r"^#(?:[0-9a-fA-F]{3}){1,2}$")


def _validate_hex_color(value: str) -> str:
    if not HEX_COLOR_RE.match(value):
        raise ValueError("Cor inválida. Use formato hexadecimal (#RGB ou #RRGGBB).")
    return value


# ─── Deck ────────────────────────────────────────────────────
class DeckIn(Schema):
    title: str = Field(min_length=1, max_length=100)
    description: str = Field(default="", max_length=500)
    color: str = Field(default="#6366F1")
    is_public: bool = False

    @field_validator("color")
    @classmethod
    def _color(cls, v: str) -> str:
        return _validate_hex_color(v)


class DeckUpdateIn(Schema):
    title: Optional[str] = Field(default=None, min_length=1, max_length=100)
    description: Optional[str] = Field(default=None, max_length=500)
    color: Optional[str] = None
    is_public: Optional[bool] = None

    @field_validator("color")
    @classmethod
    def _color(cls, v: Optional[str]) -> Optional[str]:
        return _validate_hex_color(v) if v is not None else None


class DeckOut(Schema):
    id: uuid.UUID
    title: str
    description: str
    color: str
    is_public: bool
    is_archived: bool
    card_count: int = 0
    due_count: int = 0
    lesson_locked_cards_count: int = 0
    has_pending_lesson_gate: bool = False
    created_at: datetime
    updated_at: datetime


class DeckListOut(Schema):
    decks: list[DeckOut]
    count: int
    limit: int
    offset: int


# ─── Card ────────────────────────────────────────────────────
class CardIn(Schema):
    front: str = Field(min_length=1)
    back: str = Field(min_length=1)
    tags: list[str] = Field(default_factory=list)


class CardUpdateIn(Schema):
    front: Optional[str] = Field(default=None, min_length=1)
    back: Optional[str] = Field(default=None, min_length=1)
    tags: Optional[list[str]] = None


class CardOut(Schema):
    id: uuid.UUID
    deck_id: uuid.UUID
    front: str
    back: str
    tags: list[str]
    source: str
    ease_factor: float
    interval: int
    repetitions: int
    next_review: date
    created_at: datetime
    updated_at: datetime


class CardListOut(Schema):
    cards: list[CardOut]
    count: int
    limit: int
    offset: int


class CardImportOut(Schema):
    imported_count: int
    skipped_count: int = 0


class ErrorOut(Schema):
    detail: str
