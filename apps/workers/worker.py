"""Worker do Temporal — registra workflows e activities do FlashMind."""
from __future__ import annotations

import asyncio
import os
import signal

import structlog

from django_setup import configure_django

# Boota o Django ANTES de importar qualquer coisa que toque o ORM
# (incluindo as activities de DB).
configure_django()


def _init_sentry() -> None:
    dsn = os.environ.get("SENTRY_DSN", "")
    if not dsn:
        return
    import sentry_sdk

    sentry_sdk.init(
        dsn=dsn,
        traces_sample_rate=float(os.environ.get("SENTRY_TRACES_SAMPLE_RATE", "0.1")),
        environment=os.environ.get("SENTRY_ENVIRONMENT", "development"),
        release=os.environ.get("SENTRY_RELEASE") or None,
        send_default_pii=False,
    )
    sentry_sdk.set_tag("service", "worker")


_init_sentry()

from temporalio.client import Client, TLSConfig  # noqa: E402
from temporalio.worker import Worker  # noqa: E402

from activities import (  # noqa: E402
    call_groq_for_cards,
    generate_lesson_content,
    mark_job_complete,
    mark_job_failed,
    mark_job_running,
    persist_generated_cards,
    persist_generated_lesson,
)
from workflows import GenerateCardsWorkflow  # noqa: E402

logger = structlog.get_logger("worker")


def _build_tls_config() -> TLSConfig | None:
    cert = os.environ.get("TEMPORAL_TLS_CERT", "")
    key = os.environ.get("TEMPORAL_TLS_KEY", "")
    if not cert or not key:
        return None
    return TLSConfig(
        client_cert=cert.encode("utf-8"),
        client_private_key=key.encode("utf-8"),
    )


async def _run() -> None:
    address = os.environ.get("TEMPORAL_ADDRESS", "temporal:7233")
    namespace = os.environ.get("TEMPORAL_NAMESPACE", "default")
    task_queue = os.environ.get("TEMPORAL_TASK_QUEUE", "flashmind-queue")

    tls = _build_tls_config()

    logger.info(
        "worker.connecting",
        address=address,
        namespace=namespace,
        task_queue=task_queue,
        tls=bool(tls),
    )

    client = await Client.connect(address, namespace=namespace, tls=tls)

    worker = Worker(
        client,
        task_queue=task_queue,
        workflows=[GenerateCardsWorkflow],
        activities=[
            call_groq_for_cards,
            generate_lesson_content,
            mark_job_complete,
            mark_job_running,
            mark_job_failed,
            persist_generated_cards,
            persist_generated_lesson,
        ],
    )

    logger.info("worker.started", task_queue=task_queue)

    stop_event = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, stop_event.set)
        except NotImplementedError:  # pragma: no cover
            pass

    async with worker:
        await stop_event.wait()
        logger.info("worker.shutting_down")


def main() -> None:
    asyncio.run(_run())


if __name__ == "__main__":
    main()
