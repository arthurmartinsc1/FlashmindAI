"""Endpoints de microlearning (PRD F7)."""
from __future__ import annotations

import uuid

from ninja import Router

from apps.users.security import JWTAuth

from .schemas import (
    CompleteLessonOut,
    ContentBlockIn,
    ContentBlockOut,
    ErrorOut,
    LessonDetailOut,
    LessonIn,
    LessonListOut,
    LessonSummaryOut,
)
from .services import (
    LessonError,
    annotate_completion_flags,
    complete_lesson,
    create_block,
    create_lesson,
    get_deck_for_read,
    get_deck_for_write,
    get_lesson_for_read,
    get_lesson_for_write,
    list_blocks,
    list_lessons,
    lesson_is_completed_by,
)

jwt_auth = JWTAuth()

# Montados sob:
#   /api/v1/decks/{deck_id}/lessons/...
#   /api/v1/lessons/{lesson_id}/...
decks_lessons_router = Router(tags=["Lessons"], auth=jwt_auth)
lessons_router = Router(tags=["Lessons"], auth=jwt_auth)


# ═════════════════════════════════════════════════════════════
#  Nested em deck
# ═════════════════════════════════════════════════════════════
@decks_lessons_router.get(
    "/{deck_id}/lessons",
    response={200: LessonListOut, 404: ErrorOut},
    summary="Lista as lições de um deck (próprio ou público).",
)
def list_deck_lessons(request, deck_id: uuid.UUID):
    try:
        deck = get_deck_for_read(request.auth, deck_id)
    except LessonError as exc:
        return 404, {"detail": exc.detail}

    lessons = list(list_lessons(deck))
    annotate_completion_flags(lessons, request.auth)
    return 200, {"lessons": lessons, "count": len(lessons)}


@decks_lessons_router.post(
    "/{deck_id}/lessons",
    response={201: LessonSummaryOut, 404: ErrorOut},
    summary="Cria uma lição num deck (somente dono).",
)
def create_deck_lesson(request, deck_id: uuid.UUID, payload: LessonIn):
    try:
        deck = get_deck_for_write(request.auth, deck_id)
    except LessonError as exc:
        return 404, {"detail": exc.detail}
    lesson = create_lesson(deck, payload.dict())
    setattr(lesson, "completed", False)
    return 201, lesson


# ═════════════════════════════════════════════════════════════
#  Lesson
# ═════════════════════════════════════════════════════════════
@lessons_router.get(
    "/{lesson_id}",
    response={200: LessonDetailOut, 404: ErrorOut},
    summary="Detalhe de uma lição com todos os seus blocos ordenados.",
)
def retrieve_lesson(request, lesson_id: uuid.UUID):
    try:
        lesson = get_lesson_for_read(request.auth, lesson_id)
    except LessonError as exc:
        return 404, {"detail": exc.detail}

    blocks = list(list_blocks(lesson))
    return 200, {
        "id": lesson.id,
        "deck_id": lesson.deck_id,
        "title": lesson.title,
        "order": lesson.order,
        "estimated_minutes": lesson.estimated_minutes,
        "created_at": lesson.created_at,
        "updated_at": lesson.updated_at,
        "completed": lesson_is_completed_by(request.auth, lesson),
        "blocks": [
            {"id": b.id, "type": b.type, "order": b.order, "content": b.content}
            for b in blocks
        ],
    }


@lessons_router.post(
    "/{lesson_id}/blocks",
    response={201: ContentBlockOut, 404: ErrorOut},
    summary="Adiciona um bloco a uma lição (somente dono do deck).",
)
def create_lesson_block(request, lesson_id: uuid.UUID, payload: ContentBlockIn):
    try:
        lesson = get_lesson_for_write(request.auth, lesson_id)
    except LessonError as exc:
        return 404, {"detail": exc.detail}
    block = create_block(lesson, payload.dict())
    return 201, block


@lessons_router.post(
    "/{lesson_id}/complete",
    response={200: CompleteLessonOut, 404: ErrorOut},
    summary="Marca a lição como concluída e libera os cards novos do deck.",
)
def complete(request, lesson_id: uuid.UUID):
    try:
        lesson = get_lesson_for_read(request.auth, lesson_id)
    except LessonError as exc:
        return 404, {"detail": exc.detail}

    already, unlocked = complete_lesson(request.auth, lesson)
    return 200, {
        "lesson_id": lesson.id,
        "already_completed": already,
        "unlocked_cards_count": unlocked,
    }
