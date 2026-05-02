"""Models do domínio `decks`: Deck e Card.

Cada card carrega os campos do algoritmo SM-2 (`ease_factor`, `interval`,
`repetitions`, `next_review`). O cálculo em si vive em
`apps.reviews.services.sm2` (puro, testável fora do ORM).
"""
from __future__ import annotations

import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone


class Deck(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="decks",
    )
    title = models.CharField(max_length=100)
    description = models.TextField(max_length=500, blank=True, default="")
    color = models.CharField(max_length=7, default="#6366F1")
    is_public = models.BooleanField(default=False)
    is_archived = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]
        indexes = [
            models.Index(fields=["user", "is_archived"]),
            models.Index(fields=["is_public", "is_archived"]),
        ]

    def __str__(self) -> str:  # pragma: no cover
        return self.title


def _today():
    return timezone.now().date()


class Card(models.Model):
    class Source(models.TextChoices):
        MANUAL = "manual", "Manual"
        AI = "ai", "IA"
        IMPORT = "import", "Importado"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    deck = models.ForeignKey(Deck, on_delete=models.CASCADE, related_name="cards")
    front = models.TextField()
    back = models.TextField()
    tags = models.JSONField(default=list, blank=True)
    source = models.CharField(
        max_length=10, choices=Source.choices, default=Source.MANUAL
    )

    # ─── Campos do SM-2 ────────────────────────────────────────
    ease_factor = models.FloatField(default=2.5)
    interval = models.IntegerField(default=0)  # em dias
    repetitions = models.IntegerField(default=0)
    next_review = models.DateField(default=_today)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["deck", "next_review"]),
            models.Index(fields=["next_review"]),
        ]
        ordering = ["ease_factor", "next_review"]

    def __str__(self) -> str:  # pragma: no cover
        return f"Card({self.id})"
