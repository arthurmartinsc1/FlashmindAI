"""Helper síncrono para disparar workflows do Temporal a partir do Django.

`temporalio` é assíncrono. Como nossas views Ninja são sync, usamos
`asyncio.run` em uma função utilitária. Para alto volume seria melhor
mover essa chamada pra uma view async ou um background thread, mas para
o MVP é suficiente.

Em produção (Temporal Cloud), as vars `TEMPORAL_TLS_CERT` e
`TEMPORAL_TLS_KEY` carregam o conteúdo PEM do par mTLS do client.
"""
from __future__ import annotations

import asyncio
import os
from typing import Any

from django.conf import settings
from temporalio.client import Client, TLSConfig


def _build_tls_config() -> TLSConfig | None:
    cert = os.environ.get("TEMPORAL_TLS_CERT", "")
    key = os.environ.get("TEMPORAL_TLS_KEY", "")
    if not cert or not key:
        return None
    return TLSConfig(
        client_cert=cert.encode("utf-8"),
        client_private_key=key.encode("utf-8"),
    )


async def _start(workflow: str, *args: Any, workflow_id: str, task_queue: str):
    client = await Client.connect(
        settings.TEMPORAL["ADDRESS"],
        namespace=settings.TEMPORAL["NAMESPACE"],
        tls=_build_tls_config(),
    )
    handle = await client.start_workflow(
        workflow,
        args=list(args),
        id=workflow_id,
        task_queue=task_queue,
    )
    return handle.id, handle.result_run_id or ""


def start_workflow(workflow: str, *args: Any, workflow_id: str) -> tuple[str, str]:
    """Dispara um workflow e retorna (workflow_id, run_id)."""
    task_queue = settings.TEMPORAL["TASK_QUEUE"]
    return asyncio.run(
        _start(workflow, *args, workflow_id=workflow_id, task_queue=task_queue)
    )
