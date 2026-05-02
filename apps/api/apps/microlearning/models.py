"""Models do microlearning (PRD F7).

- `MicroLesson`: conteúdo estruturado associado a um Deck.
- `ContentBlock`: bloco ordenado de uma lição (texto, quiz ou highlight).
- `UserLessonCompletion`: registro de conclusão de lição por usuário —
  usado pra idempotência do endpoint de conclusão e para a UI marcar
  lições já feitas.
"""
from __future__ import annotations

import uuid

from django.conf import settings
from django.db import models


class MicroLesson(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    deck = models.ForeignKey(
        "decks.Deck",
        on_delete=models.CASCADE,
        related_name="lessons",
    )
    title = models.CharField(max_length=200)
    order = models.IntegerField(default=0)
    estimated_minutes = models.IntegerField(default=5)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["deck", "order", "created_at"]
        indexes = [
            models.Index(fields=["deck", "order"]),
        ]

    def __str__(self) -> str:  # pragma: no cover
        return self.title


class ContentBlock(models.Model):
    class Type(models.TextChoices):
        TEXT = "text", "Texto"
        QUIZ = "quiz", "Quiz"
        HIGHLIGHT = "highlight", "Highlight"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    lesson = models.ForeignKey(
        MicroLesson,
        on_delete=models.CASCADE,
        related_name="blocks",
    )
    type = models.CharField(max_length=16, choices=Type.choices)
    # Estrutura varia por type:
    #   text      → {"body": "markdown string"}
    #   quiz      → {"question": str, "options": [str], "correct": int,
    #                "explanation": str}
    #   highlight → {"body": str, "color": "yellow"|"blue"|"green"}
    content = models.JSONField(default=dict)
    order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["lesson", "order", "created_at"]
        indexes = [
            models.Index(fields=["lesson", "order"]),
        ]

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.type}#{self.order}"


class UserLessonCompletion(models.Model):
    """
    Registro de conclusão. Uma row por (user, lesson). O primeiro POST
    `/lessons/{id}/complete` cria; chamadas subsequentes são no-op (os
    cards já foram desbloqueados).
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="lesson_completions",
    )
    lesson = models.ForeignKey(
        MicroLesson,
        on_delete=models.CASCADE,
        related_name="completions",
    )
    completed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user", "lesson"], name="uniq_user_lesson_completion"
            )
        ]
        indexes = [models.Index(fields=["user", "completed_at"])]

    def __str__(self) -> str:  # pragma: no cover
        return f"Completion({self.user_id}, {self.lesson_id})"
