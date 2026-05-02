"""GenerateCardsWorkflow — orquestra a geração de flashcards + micro-lição via Groq.

Fluxo:
    1. mark_job_running(job_id)
    2. call_groq_for_cards(payload)           → lista de {front, back}
    3. persist_generated_cards(deck_id, cards) → salva cards, retorna result dict
    4. generate_lesson_content(payload)        → blocos estruturados  [best-effort]
    5. persist_generated_lesson(deck_id, data) → salva lição + blocos [best-effort]
    6. mark_job_complete(job_id, result)        → marca job como completed

    O job só fica "completed" depois que cards E lição estão no banco.
    Se os passos 4-5 falharem, a lição é pulada mas o job ainda é marcado completed.
    Se qualquer passo 1-3 falhar, mark_job_failed(job_id, msg) e re-raise.

Tudo dentro do workflow é determinístico — chamadas externas e
acesso a I/O ficam nas activities.
"""
from __future__ import annotations

from datetime import timedelta
from typing import Any

from temporalio import workflow
from temporalio.common import RetryPolicy

with workflow.unsafe.imports_passed_through():
    from activities import (
        call_groq_for_cards,
        generate_lesson_content,
        mark_job_complete,
        mark_job_failed,
        mark_job_running,
        persist_generated_cards,
        persist_generated_lesson,
    )


GROQ_RETRY = RetryPolicy(
    initial_interval=timedelta(seconds=2),
    maximum_interval=timedelta(seconds=30),
    backoff_coefficient=2.0,
    maximum_attempts=4,
    non_retryable_error_types=[
        "GroqMissingKey",
        "GroqClientError",
        "GroqInvalidJSON",
        "GroqInvalidSchema",
        "GroqInvalidShape",
        "GroqEmptyResult",
    ],
)

DB_RETRY = RetryPolicy(
    initial_interval=timedelta(seconds=1),
    maximum_attempts=3,
)


@workflow.defn(name="GenerateCardsWorkflow")
class GenerateCardsWorkflow:
    @workflow.run
    async def run(self, payload: dict[str, Any]) -> dict[str, Any]:
        job_id: str = payload["job_id"]
        deck_id: str = payload["deck_id"]

        try:
            await workflow.execute_activity(
                mark_job_running,
                job_id,
                start_to_close_timeout=timedelta(seconds=15),
                retry_policy=DB_RETRY,
            )

            cards = await workflow.execute_activity(
                call_groq_for_cards,
                payload,
                start_to_close_timeout=timedelta(seconds=90),
                retry_policy=GROQ_RETRY,
            )

            # Salva os cards mas NÃO marca o job como completed ainda.
            result = await workflow.execute_activity(
                persist_generated_cards,
                args=[deck_id, job_id, cards],
                start_to_close_timeout=timedelta(seconds=30),
                retry_policy=DB_RETRY,
            )

            # Gera e persiste a micro-lição — best-effort.
            # Falha aqui pula a lição mas não cancela os cards nem o job.
            try:
                lesson_data = await workflow.execute_activity(
                    generate_lesson_content,
                    payload,
                    start_to_close_timeout=timedelta(seconds=90),
                    retry_policy=GROQ_RETRY,
                )
                await workflow.execute_activity(
                    persist_generated_lesson,
                    args=[deck_id, lesson_data],
                    start_to_close_timeout=timedelta(seconds=30),
                    retry_policy=DB_RETRY,
                )
            except Exception as lesson_exc:
                workflow.logger.warning(
                    f"lesson.generation_skipped: {type(lesson_exc).__name__}: {lesson_exc}"
                )

            # Marca job como completed somente após cards + lição estarem no banco.
            await workflow.execute_activity(
                mark_job_complete,
                args=[job_id, result],
                start_to_close_timeout=timedelta(seconds=15),
                retry_policy=DB_RETRY,
            )

            return result

        except Exception as exc:
            # Best-effort: registra o erro no job antes de propagar.
            try:
                await workflow.execute_activity(
                    mark_job_failed,
                    args=[job_id, f"{type(exc).__name__}: {exc}"],
                    start_to_close_timeout=timedelta(seconds=15),
                    retry_policy=DB_RETRY,
                )
            except Exception:
                pass
            raise
