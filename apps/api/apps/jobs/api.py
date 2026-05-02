"""Endpoints do app `jobs` (polling de status)."""
from __future__ import annotations

import uuid

from ninja import Router

from apps.decks.schemas import ErrorOut
from apps.users.security import JWTAuth

from .schemas import AsyncJobOut
from .services import JobError, get_job_for_user

jwt_auth = JWTAuth()

jobs_router = Router(tags=["Jobs"], auth=jwt_auth)


@jobs_router.get(
    "/{job_id}",
    response={200: AsyncJobOut, 404: ErrorOut},
    summary="Status de um job assíncrono (geração de cards, etc).",
)
def get_job(request, job_id: uuid.UUID):
    try:
        job = get_job_for_user(request.auth, job_id)
    except JobError as exc:
        return 404, {"detail": exc.detail}
    return 200, job
