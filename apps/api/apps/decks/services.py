"""Regras de negócio de decks e cards.

As funções neste módulo não dependem de `request` — recebem o `user` já
resolvido. Isso facilita testes unitários e reuso fora do HTTP (ex:
workers do Temporal que criam cards a partir da IA).
"""
from __future__ import annotations

import csv
import io
import uuid
from datetime import timedelta
from typing import Iterable

import structlog
from django.db import transaction
from django.db.models import BooleanField, Case, Count, Exists, OuterRef, Q, QuerySet, Value, When
from django.utils import timezone

from apps.microlearning.models import MicroLesson, UserLessonCompletion
from apps.microlearning.services import deck_requires_microlesson_gate

from .models import Card, Deck

logger = structlog.get_logger(__name__)

MAX_CARDS_PER_DECK = 1000  # Limite do plano free (PRD F3)


class ValidationError(Exception):
    def __init__(self, detail: str):
        self.detail = detail
        super().__init__(detail)


# ─── Querysets com annotations ───────────────────────────────
def _with_counts(queryset: QuerySet, user=None) -> QuerySet:
    today = timezone.now().date()
    qs = queryset.annotate(
        card_count=Count("cards", distinct=True),
        due_count=Count(
            "cards",
            filter=Q(cards__next_review__lte=today),
            distinct=True,
        ),
        lesson_locked_cards_count=Count(
            "cards",
            filter=Q(cards__repetitions=0, cards__next_review__gt=today),
            distinct=True,
        ),
    )
    if user is not None:
        qs = qs.annotate(
            _has_lesson=Exists(MicroLesson.objects.filter(deck=OuterRef("pk"))),
            _has_completion=Exists(
                UserLessonCompletion.objects.filter(user=user, lesson__deck=OuterRef("pk"))
            ),
        ).annotate(
            has_pending_lesson_gate=Case(
                When(_has_lesson=True, _has_completion=False, then=Value(True)),
                default=Value(False),
                output_field=BooleanField(),
            )
        )
    return qs


def list_user_decks(
    user, *, search: str | None = None, include_archived: bool = False
) -> QuerySet:
    qs = Deck.objects.filter(user=user)
    if not include_archived:
        qs = qs.filter(is_archived=False)
    if search:
        qs = qs.filter(title__icontains=search)
    return _with_counts(qs, user=user)


def list_public_decks(*, search: str | None = None) -> QuerySet:
    qs = Deck.objects.filter(is_public=True, is_archived=False).select_related("user")
    if search:
        qs = qs.filter(title__icontains=search)
    return _with_counts(qs)


# ─── Ownership / access ──────────────────────────────────────
def get_deck_for_read(user, deck_id: uuid.UUID) -> Deck:
    """Deck visível para o usuário (próprio ou público)."""
    deck = (
        _with_counts(Deck.objects.filter(is_archived=False), user=user)
        .filter(pk=deck_id)
        .first()
    )
    if deck is None:
        raise ValidationError("Deck não encontrado.")
    if deck.user_id != user.id and not deck.is_public:
        raise ValidationError("Deck não encontrado.")
    return deck


def get_deck_for_write(user, deck_id: uuid.UUID) -> Deck:
    """Deck editável: precisa ser o dono."""
    deck = Deck.objects.filter(pk=deck_id, user=user, is_archived=False).first()
    if deck is None:
        raise ValidationError("Deck não encontrado.")
    return deck


# ─── Deck CRUD ───────────────────────────────────────────────
def create_deck(user, data: dict) -> Deck:
    deck = Deck.objects.create(user=user, **data)
    logger.info("deck.created", deck_id=str(deck.id), user_id=str(user.id))
    return _with_counts(Deck.objects.filter(pk=deck.pk)).get()


def update_deck(deck: Deck, data: dict) -> Deck:
    for field, value in data.items():
        if value is not None:
            setattr(deck, field, value)
    deck.save()
    return _with_counts(Deck.objects.filter(pk=deck.pk)).get()


def archive_deck(deck: Deck) -> None:
    """Soft delete."""
    deck.is_archived = True
    deck.save(update_fields=["is_archived", "updated_at"])
    logger.info("deck.archived", deck_id=str(deck.id))


# ─── Card CRUD ───────────────────────────────────────────────
def list_cards(deck: Deck, *, search: str | None = None) -> QuerySet:
    qs = Card.objects.filter(deck=deck)
    if search:
        qs = qs.filter(Q(front__icontains=search) | Q(back__icontains=search))
    return qs


def _ensure_deck_under_limit(deck: Deck, incoming: int = 1) -> None:
    current = Card.objects.filter(deck=deck).count()
    if current + incoming > MAX_CARDS_PER_DECK:
        raise ValidationError(
            f"Limite de {MAX_CARDS_PER_DECK} cards por deck atingido."
        )


def create_card(
    deck: Deck,
    data: dict,
    *,
    source: Card.Source = Card.Source.MANUAL,
    user=None,
) -> Card:
    _ensure_deck_under_limit(deck, incoming=1)
    today = timezone.now().date()
    next_review = (
        today + timedelta(days=1)
        if user is not None and deck_requires_microlesson_gate(user, deck)
        else today
    )
    card = Card.objects.create(
        deck=deck,
        front=data["front"],
        back=data["back"],
        tags=data.get("tags", []) or [],
        source=source,
        next_review=next_review,
    )
    logger.info(
        "card.created", card_id=str(card.id), deck_id=str(deck.id), source=card.source
    )
    return card


def update_card(card: Card, data: dict) -> Card:
    for field, value in data.items():
        if value is not None:
            setattr(card, field, value)
    card.save()
    return card


def delete_card(card: Card) -> None:
    logger.info("card.deleted", card_id=str(card.id))
    card.delete()


def get_card_for_write(user, card_id: uuid.UUID) -> Card:
    card = (
        Card.objects.select_related("deck")
        .filter(pk=card_id, deck__user=user, deck__is_archived=False)
        .first()
    )
    if card is None:
        raise ValidationError("Card não encontrado.")
    return card


# ─── CSV import ──────────────────────────────────────────────
@transaction.atomic
def import_cards_from_csv(deck: Deck, file_bytes: bytes, *, user=None) -> tuple[int, int]:
    """
    Importa cards de um CSV com colunas `front` e `back` (header obrigatório).
    Retorna (imported, skipped).
    """
    try:
        text = file_bytes.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise ValidationError("Arquivo CSV precisa estar em UTF-8.") from exc

    reader = csv.DictReader(io.StringIO(text))
    if not reader.fieldnames or "front" not in reader.fieldnames or "back" not in reader.fieldnames:
        raise ValidationError("CSV precisa ter as colunas 'front' e 'back' no header.")

    rows: list[dict] = []
    skipped = 0
    for raw in reader:
        front = (raw.get("front") or "").strip()
        back = (raw.get("back") or "").strip()
        if not front or not back:
            skipped += 1
            continue
        rows.append({"front": front, "back": back})

    if not rows:
        return 0, skipped

    _ensure_deck_under_limit(deck, incoming=len(rows))

    today = timezone.now().date()
    next_review = (
        today + timedelta(days=1)
        if user is not None and deck_requires_microlesson_gate(user, deck)
        else today
    )

    Card.objects.bulk_create(
        [
            Card(
                deck=deck,
                front=row["front"],
                back=row["back"],
                tags=[],
                source=Card.Source.IMPORT,
                next_review=next_review,
            )
            for row in rows
        ]
    )
    logger.info(
        "cards.imported",
        deck_id=str(deck.id),
        imported=len(rows),
        skipped=skipped,
    )
    return len(rows), skipped


# ─── Pagination helper ───────────────────────────────────────
def paginate(qs: QuerySet, limit: int, offset: int) -> tuple[list, int]:
    limit = max(1, min(int(limit), 100))
    offset = max(0, int(offset))
    total = qs.count()
    items = list(qs[offset : offset + limit])
    return items, total


def page_bounds(limit: int, offset: int) -> tuple[int, int]:
    return max(1, min(int(limit), 100)), max(0, int(offset))


def __all__() -> Iterable[str]:  # pragma: no cover
    return (
        "ValidationError",
        "list_user_decks",
        "list_public_decks",
        "get_deck_for_read",
        "get_deck_for_write",
        "create_deck",
        "update_deck",
        "archive_deck",
        "list_cards",
        "create_card",
        "update_card",
        "delete_card",
        "get_card_for_write",
        "import_cards_from_csv",
        "paginate",
    )
