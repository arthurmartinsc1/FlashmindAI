"""Schemas Ninja do módulo de microlearning."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Literal

from ninja import Schema
from pydantic import Field, field_validator


# ─── Content blocks (entrada tipada por tipo) ────────────────
class TextContent(Schema):
    body: str = Field(min_length=1)


class QuizContent(Schema):
    question: str = Field(min_length=1)
    options: list[str] = Field(min_length=2, max_length=6)
    correct: int = Field(ge=0)
    explanation: str = ""

    @field_validator("correct")
    @classmethod
    def _correct_in_range(cls, v: int, info):
        options = info.data.get("options") or []
        if options and v >= len(options):
            raise ValueError("`correct` precisa apontar para um índice válido em `options`.")
        return v


class HighlightContent(Schema):
    body: str = Field(min_length=1)
    color: Literal["yellow", "blue", "green"] = "yellow"


BlockType = Literal["text", "quiz", "highlight"]


class ContentBlockIn(Schema):
    type: BlockType
    order: int = 0
    content: dict[str, Any]

    @field_validator("content")
    @classmethod
    def _validate_by_type(cls, v: dict, info):
        block_type = info.data.get("type")
        if block_type == "text":
            TextContent.model_validate(v)
        elif block_type == "quiz":
            QuizContent.model_validate(v)
        elif block_type == "highlight":
            HighlightContent.model_validate(v)
        return v


class ContentBlockOut(Schema):
    id: uuid.UUID
    type: BlockType
    order: int
    content: dict[str, Any]


# ─── Lessons ─────────────────────────────────────────────────
class LessonIn(Schema):
    title: str = Field(min_length=1, max_length=200)
    order: int = 0
    estimated_minutes: int = Field(default=5, ge=1, le=120)


class LessonSummaryOut(Schema):
    """Sem blocks — usada no list."""

    id: uuid.UUID
    deck_id: uuid.UUID
    title: str
    order: int
    estimated_minutes: int
    created_at: datetime
    updated_at: datetime
    completed: bool = False


class LessonDetailOut(LessonSummaryOut):
    blocks: list[ContentBlockOut]


class LessonListOut(Schema):
    lessons: list[LessonSummaryOut]
    count: int


class CompleteLessonOut(Schema):
    lesson_id: uuid.UUID
    already_completed: bool
    unlocked_cards_count: int


class ErrorOut(Schema):
    detail: str
