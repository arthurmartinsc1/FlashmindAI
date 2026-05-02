"""Modelo genérico de jobs assíncronos disparados via Temporal.

Cada `AsyncJob` é uma representação persistida de um workflow em execução
(ou já finalizado). A workflow no `apps/workers/` atualiza o status via
activity `update_job_status`.
"""
from __future__ import annotations

import uuid

from django.conf import settings
from django.db import models


class AsyncJob(models.Model):
    class Kind(models.TextChoices):
        GENERATE_CARDS = "generate_cards", "Gerar cards via IA"

    class Status(models.TextChoices):
        PENDING = "pending", "Pendente"
        RUNNING = "running", "Em execução"
        COMPLETED = "completed", "Concluído"
        FAILED = "failed", "Falhou"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="async_jobs",
    )
    kind = models.CharField(max_length=32, choices=Kind.choices)
    status = models.CharField(
        max_length=16, choices=Status.choices, default=Status.PENDING
    )
    params = models.JSONField(default=dict, blank=True)
    result = models.JSONField(null=True, blank=True)
    error = models.TextField(blank=True, default="")

    workflow_id = models.CharField(max_length=128, blank=True, default="")
    run_id = models.CharField(max_length=128, blank=True, default="")

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    started_at = models.DateTimeField(null=True, blank=True)
    finished_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "status"]),
            models.Index(fields=["kind", "status"]),
        ]

    def __str__(self) -> str:  # pragma: no cover
        return f"AsyncJob({self.kind}, {self.status})"
