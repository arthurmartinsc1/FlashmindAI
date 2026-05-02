"""Schemas Ninja para o app `jobs`."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Optional

from ninja import Schema
from pydantic import Field


class GenerateCardsIn(Schema):
    topic: str = Field(min_length=3, max_length=500, description="Tópico/contexto base.")
    count: int = Field(default=10, ge=1, le=20, description="Quantidade de cards (1-20).")
    language: str = Field(default="pt-BR", max_length=10)
    source_text: Optional[str] = Field(
        default=None,
        max_length=8000,
        description="Texto-fonte opcional para embasar a geração.",
    )


class AsyncJobOut(Schema):
    id: uuid.UUID
    kind: str
    status: str
    params: dict[str, Any] = {}
    result: Optional[dict[str, Any]] = None
    error: str = ""
    workflow_id: str = ""
    created_at: datetime
    updated_at: datetime
    started_at: Optional[datetime] = None
    finished_at: Optional[datetime] = None
