"""Regras de negócio para AsyncJobs."""
from __future__ import annotations

import uuid
from typing import Any

import structlog

from .models import AsyncJob
from .temporal_client import start_workflow

logger = structlog.get_logger(__name__)

GENERATE_CARDS_WORKFLOW = "GenerateCardsWorkflow"


class JobError(Exception):
    def __init__(self, detail: str):
        self.detail = detail
        super().__init__(detail)


def get_job_for_user(user, job_id: uuid.UUID) -> AsyncJob:
    job = AsyncJob.objects.filter(pk=job_id, user=user).first()
    if job is None:
        raise JobError("Job não encontrado.")
    return job


def enqueue_generate_cards(
    *,
    user,
    deck_id: uuid.UUID,
    topic: str,
    count: int,
    language: str,
    source_text: str | None,
) -> AsyncJob:
    """Cria o AsyncJob, dispara a workflow no Temporal e devolve o registro."""
    params: dict[str, Any] = {
        "deck_id": str(deck_id),
        "topic": topic,
        "count": count,
        "language": language,
        "source_text": source_text or "",
    }
    job = AsyncJob.objects.create(
        user=user,
        kind=AsyncJob.Kind.GENERATE_CARDS,
        status=AsyncJob.Status.PENDING,
        params=params,
    )

    workflow_id = f"generate-cards-{job.id}"
    try:
        wf_id, run_id = start_workflow(
            GENERATE_CARDS_WORKFLOW,
            {"job_id": str(job.id), **params},
            workflow_id=workflow_id,
        )
    except Exception as exc:  # pragma: no cover - depende do Temporal externo
        logger.error(
            "job.enqueue_failed", job_id=str(job.id), error=str(exc), exc_info=True
        )
        job.status = AsyncJob.Status.FAILED
        job.error = f"Falha ao agendar workflow: {exc}"
        job.save(update_fields=["status", "error", "updated_at"])
        raise JobError("Não foi possível enfileirar a geração agora.") from exc

    job.workflow_id = wf_id
    job.run_id = run_id
    job.save(update_fields=["workflow_id", "run_id", "updated_at"])
    logger.info(
        "job.enqueued",
        job_id=str(job.id),
        workflow_id=wf_id,
        kind=job.kind,
    )
    return job
