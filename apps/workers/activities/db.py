"""Activities que persistem estado via Django ORM.

Inclui:
- mark_job_running / mark_job_failed: atualizam AsyncJob
- persist_generated_cards: cria Cards em bulk
- persist_generated_lesson: cria MicroLesson + ContentBlocks

Como o ORM é síncrono, encapsulamos as chamadas com `sync_to_async` —
o `temporalio` aceita activities `async` ou `sync`, mas se rodar sync
o worker precisa de threadpool. Manter async + sync_to_async é o
padrão mais previsível com Django.
"""
from __future__ import annotations

from typing import Any

import structlog
from asgiref.sync import sync_to_async
from temporalio import activity
from temporalio.exceptions import ApplicationError

logger = structlog.get_logger(__name__)


@sync_to_async
def _mark_running(job_id: str) -> None:
    from django.utils import timezone

    from apps.jobs.models import AsyncJob

    AsyncJob.objects.filter(pk=job_id).update(
        status=AsyncJob.Status.RUNNING,
        started_at=timezone.now(),
    )


@activity.defn(name="mark_job_running")
async def mark_job_running(job_id: str) -> None:
    await _mark_running(job_id)
    logger.info("job.running", job_id=job_id)


@sync_to_async
def _mark_failed(job_id: str, error: str) -> None:
    from django.utils import timezone

    from apps.jobs.models import AsyncJob

    AsyncJob.objects.filter(pk=job_id).update(
        status=AsyncJob.Status.FAILED,
        error=error[:4000],
        finished_at=timezone.now(),
    )


@activity.defn(name="mark_job_failed")
async def mark_job_failed(job_id: str, error: str) -> None:
    await _mark_failed(job_id, error)
    logger.error("job.failed", job_id=job_id, error=error[:200])


@sync_to_async
def _save_cards(deck_id: str, cards: list[dict[str, str]]) -> dict[str, Any]:
    from apps.decks.models import Card, Deck
    from apps.decks.services import MAX_CARDS_PER_DECK

    deck = Deck.objects.filter(pk=deck_id, is_archived=False).first()
    if deck is None:
        raise RuntimeError("Deck não encontrado ou arquivado.")

    current = Card.objects.filter(deck=deck).count()
    room = max(0, MAX_CARDS_PER_DECK - current)
    to_create = cards[:room]

    from datetime import timedelta

    from django.utils import timezone

    # Mesma data “hoje” que a API usa (TIME_ZONE do Django), não date.today() do OS — evita
    # cards aparecerem como devidos quando o worker está em UTC e a API em America/Sao_Paulo.
    tomorrow = timezone.now().date() + timedelta(days=1)

    Card.objects.bulk_create([
        Card(
            deck=deck,
            front=c["front"],
            back=c["back"],
            tags=[],
            source=Card.Source.AI,
            next_review=tomorrow,  # bloqueado até o usuário concluir a micro-lição
        )
        for c in to_create
    ])

    return {
        "deck_id": str(deck.id),
        "created_count": len(to_create),
        "skipped_count": len(cards) - len(to_create),
    }


@activity.defn(name="persist_generated_cards")
async def persist_generated_cards(
    deck_id: str, job_id: str, cards: list[dict[str, str]]
) -> dict[str, Any]:
    try:
        result = await _save_cards(deck_id, cards)
    except RuntimeError as exc:
        raise ApplicationError(str(exc), type="PersistError", non_retryable=True) from exc
    logger.info(
        "cards.persisted",
        job_id=job_id,
        deck_id=deck_id,
        created=result["created_count"],
        skipped=result["skipped_count"],
    )
    return result


@sync_to_async
def _mark_complete(job_id: str, result: dict[str, Any]) -> None:
    from django.utils import timezone

    from apps.jobs.models import AsyncJob

    AsyncJob.objects.filter(pk=job_id).update(
        status=AsyncJob.Status.COMPLETED,
        result=result,
        finished_at=timezone.now(),
    )


@activity.defn(name="mark_job_complete")
async def mark_job_complete(job_id: str, result: dict[str, Any]) -> None:
    await _mark_complete(job_id, result)
    logger.info("job.completed", job_id=job_id, created=result.get("created_count"))


MAX_LESSONS_PER_DECK = 3


@sync_to_async
def _persist_lesson(deck_id: str, lesson_data: dict[str, Any]) -> list[str]:
    from django.db import transaction

    from apps.decks.models import Deck
    from apps.microlearning.models import ContentBlock, MicroLesson

    deck = Deck.objects.filter(pk=deck_id, is_archived=False).first()
    if deck is None:
        raise RuntimeError("Deck não encontrado ou arquivado.")

    raw_lessons = lesson_data.get("lessons")
    lesson_items = raw_lessons if isinstance(raw_lessons, list) else [lesson_data]
    current_count = MicroLesson.objects.filter(deck=deck).count()
    existing_titles = set(
        MicroLesson.objects.filter(deck=deck).values_list("title", flat=True)
    )
    created_ids: list[str] = []

    with transaction.atomic():
        for item in lesson_items:
            if current_count >= MAX_LESSONS_PER_DECK:
                break
            if not isinstance(item, dict):
                continue

            title = item["title"]
            if title in existing_titles:
                continue

            lesson = MicroLesson.objects.create(
                deck=deck,
                title=title,
                order=current_count,
                estimated_minutes=item.get("estimated_minutes", 5),
            )
            ContentBlock.objects.bulk_create([
                ContentBlock(
                    lesson=lesson,
                    type=b["type"],
                    order=b["order"],
                    content=b["content"],
                )
                for b in item.get("blocks", [])
            ])
            current_count += 1
            existing_titles.add(title)
            created_ids.append(str(lesson.id))

    return created_ids


@activity.defn(name="persist_generated_lesson")
async def persist_generated_lesson(
    deck_id: str,
    lesson_data: dict[str, Any],
) -> list[str] | None:
    try:
        lesson_ids = await _persist_lesson(deck_id, lesson_data)
    except RuntimeError as exc:
        raise ApplicationError(str(exc), type="PersistError", non_retryable=True) from exc
    if not lesson_ids:
        logger.info(
            "lesson.skipped_limit_reached",
            deck_id=deck_id,
            limit=MAX_LESSONS_PER_DECK,
        )
        return None
    raw_lessons = lesson_data.get("lessons")
    lesson_items = raw_lessons if isinstance(raw_lessons, list) else [lesson_data]
    logger.info(
        "lessons.persisted",
        deck_id=deck_id,
        lesson_ids=lesson_ids,
        count=len(lesson_ids),
        blocks=sum(
            len(item.get("blocks", []))
            for item in lesson_items
            if isinstance(item, dict)
        ),
    )
    return lesson_ids
