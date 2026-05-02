"""Regras de negócio do microlearning."""
from __future__ import annotations

import uuid

import structlog
from django.db import transaction
from django.db.models import QuerySet
from django.utils import timezone

from apps.decks.models import Card, Deck

from .models import ContentBlock, MicroLesson, UserLessonCompletion

logger = structlog.get_logger(__name__)


class LessonError(Exception):
    def __init__(self, detail: str):
        self.detail = detail
        super().__init__(detail)


# ─── Access helpers ──────────────────────────────────────────
def _deck_is_readable_by(user, deck: Deck) -> bool:
    return (not deck.is_archived) and (deck.user_id == user.id or deck.is_public)


def get_deck_for_read(user, deck_id: uuid.UUID) -> Deck:
    deck = Deck.objects.filter(pk=deck_id).first()
    if deck is None or not _deck_is_readable_by(user, deck):
        raise LessonError("Deck não encontrado.")
    return deck


def get_deck_for_write(user, deck_id: uuid.UUID) -> Deck:
    deck = Deck.objects.filter(pk=deck_id, user=user, is_archived=False).first()
    if deck is None:
        raise LessonError("Deck não encontrado.")
    return deck


def get_lesson_for_read(user, lesson_id: uuid.UUID) -> MicroLesson:
    lesson = (
        MicroLesson.objects.select_related("deck").filter(pk=lesson_id).first()
    )
    if lesson is None or not _deck_is_readable_by(user, lesson.deck):
        raise LessonError("Lição não encontrada.")
    return lesson


def get_lesson_for_write(user, lesson_id: uuid.UUID) -> MicroLesson:
    lesson = (
        MicroLesson.objects.select_related("deck")
        .filter(pk=lesson_id, deck__user=user, deck__is_archived=False)
        .first()
    )
    if lesson is None:
        raise LessonError("Lição não encontrada.")
    return lesson


# ─── Queries ─────────────────────────────────────────────────
def list_lessons(deck: Deck) -> QuerySet[MicroLesson]:
    return MicroLesson.objects.filter(deck=deck).order_by("order", "created_at")


def list_blocks(lesson: MicroLesson) -> QuerySet[ContentBlock]:
    return ContentBlock.objects.filter(lesson=lesson).order_by("order", "created_at")


def deck_requires_microlesson_gate(user, deck: Deck) -> bool:
    """
    True quando o deck tem micro-lição e o usuário ainda não concluiu nenhuma
    neste deck — novos cards ficam com revisão “amanhã” até a primeira conclusão,
    alinhado ao desbloqueio em `complete_lesson`.
    """
    if not MicroLesson.objects.filter(deck=deck).exists():
        return False
    return not UserLessonCompletion.objects.filter(user=user, lesson__deck=deck).exists()


def lesson_is_completed_by(user, lesson: MicroLesson) -> bool:
    return UserLessonCompletion.objects.filter(user=user, lesson=lesson).exists()


def completed_lesson_ids(user, deck: Deck) -> set[uuid.UUID]:
    return set(
        UserLessonCompletion.objects.filter(user=user, lesson__deck=deck).values_list(
            "lesson_id", flat=True
        )
    )


# ─── Mutações (dono do deck) ─────────────────────────────────
def create_lesson(deck: Deck, data: dict) -> MicroLesson:
    lesson = MicroLesson.objects.create(deck=deck, **data)
    logger.info("lesson.created", lesson_id=str(lesson.id), deck_id=str(deck.id))
    return lesson


def create_block(lesson: MicroLesson, data: dict) -> ContentBlock:
    block = ContentBlock.objects.create(
        lesson=lesson,
        type=data["type"],
        order=data.get("order", 0),
        content=data["content"],
    )
    logger.info("block.created", block_id=str(block.id), lesson_id=str(lesson.id), type=block.type)
    return block


# ─── Conclusão / unlock ──────────────────────────────────────
@transaction.atomic
def complete_lesson(user, lesson: MicroLesson) -> tuple[bool, int]:
    """
    Registra a conclusão de uma lição e "desbloqueia" os cards novos
    (repetitions == 0) do deck, trazendo `next_review` para hoje.

    Cards já em progresso (pelo menos uma revisão feita) NÃO são
    afetados — respeitando a agenda do SM-2.

    Retorna (already_completed, unlocked_cards_count).
    """
    already = lesson_is_completed_by(user, lesson)
    today = timezone.now().date()

    # Só dispara o unlock na primeira conclusão; chamadas subsequentes
    # são idempotentes e retornam 0 cards desbloqueados.
    if already:
        return True, 0

    UserLessonCompletion.objects.create(user=user, lesson=lesson)

    unlocked = (
        Card.objects.filter(
            deck=lesson.deck,
            deck__is_archived=False,
            repetitions=0,
            next_review__gt=today,
        ).update(next_review=today, updated_at=timezone.now())
    )

    logger.info(
        "lesson.completed",
        user_id=str(user.id),
        lesson_id=str(lesson.id),
        deck_id=str(lesson.deck_id),
        unlocked_cards=unlocked,
    )
    return False, unlocked


def annotate_completion_flags(
    lessons: list[MicroLesson], user
) -> list[MicroLesson]:
    """Marca `completed=True` em cada lesson sem fazer N+1 no DB."""
    if not lessons:
        return lessons
    done = set(
        UserLessonCompletion.objects.filter(
            user=user, lesson_id__in=[les.id for les in lessons]
        ).values_list("lesson_id", flat=True)
    )
    for lesson in lessons:
        setattr(lesson, "completed", lesson.id in done)
    return lessons
