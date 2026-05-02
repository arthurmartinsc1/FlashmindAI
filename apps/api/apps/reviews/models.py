"""Model do domínio `reviews`.

Cada linha representa uma avaliação (quality 0-5) feita pelo usuário para um
card em um dado momento. Reviews são imutáveis — qualquer correção gera um
novo registro.
"""
from __future__ import annotations

import uuid

from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models


class Review(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    card = models.ForeignKey(
        "decks.Card",
        on_delete=models.CASCADE,
        related_name="reviews",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="reviews",
    )
    quality = models.IntegerField(
        validators=[MinValueValidator(0), MaxValueValidator(5)],
    )
    time_spent_ms = models.IntegerField(default=0)
    reviewed_at = models.DateTimeField(auto_now_add=True)
    # `synced` é usado pelo fluxo offline-first do mobile: reviews criadas no
    # servidor começam com synced=True; no cliente começam False até push.
    synced = models.BooleanField(default=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "reviewed_at"]),
            models.Index(fields=["card", "reviewed_at"]),
        ]
        ordering = ["-reviewed_at"]

    def __str__(self) -> str:  # pragma: no cover
        return f"Review({self.card_id}, q={self.quality})"
