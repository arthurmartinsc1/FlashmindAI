"""Endpoints HTTP para Decks e Cards (PRD F2 e F3)."""
from __future__ import annotations

import uuid
from typing import Optional

from ninja import File, Query, Router
from ninja.files import UploadedFile

from apps.jobs.schemas import AsyncJobOut, GenerateCardsIn
from apps.jobs.services import JobError, enqueue_generate_cards
from apps.users.security import JWTAuth

from .schemas import (
    CardImportOut,
    CardIn,
    CardListOut,
    CardOut,
    CardUpdateIn,
    DeckIn,
    DeckListOut,
    DeckOut,
    DeckUpdateIn,
    ErrorOut,
)
from .services import (
    ValidationError,
    archive_deck,
    create_card,
    create_deck,
    delete_card,
    get_card_for_write,
    get_deck_for_read,
    get_deck_for_write,
    import_cards_from_csv,
    list_cards,
    list_public_decks,
    list_user_decks,
    page_bounds,
    paginate,
    update_card,
    update_deck,
)

jwt_auth = JWTAuth()

# Routers separados pra manter semântica do contrato do PRD:
#   /decks/...            → operações sobre decks + cards nested em decks
#   /cards/{id}           → operações diretas sobre um card
decks_router = Router(tags=["Decks"], auth=jwt_auth)
cards_router = Router(tags=["Cards"], auth=jwt_auth)


# ═════════════════════════════════════════════════════════════
#  DECKS
# ═════════════════════════════════════════════════════════════
@decks_router.get(
    "/",
    response=DeckListOut,
    summary="Lista decks do usuário (com card_count / due_count).",
)
def list_decks(
    request,
    search: Optional[str] = Query(None, description="Busca parcial por título."),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    qs = list_user_decks(request.auth, search=search).order_by("-updated_at")
    items, total = paginate(qs, limit, offset)
    effective_limit, effective_offset = page_bounds(limit, offset)
    return {
        "decks": items,
        "count": total,
        "limit": effective_limit,
        "offset": effective_offset,
    }


@decks_router.get(
    "/public",
    response=DeckListOut,
    summary="Lista decks públicos (qualquer usuário autenticado).",
)
def list_public(
    request,
    search: Optional[str] = Query(None),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    qs = list_public_decks(search=search).order_by("-updated_at")
    items, total = paginate(qs, limit, offset)
    effective_limit, effective_offset = page_bounds(limit, offset)
    return {
        "decks": items,
        "count": total,
        "limit": effective_limit,
        "offset": effective_offset,
    }


@decks_router.post(
    "/",
    response={201: DeckOut, 400: ErrorOut},
    summary="Cria um novo deck.",
)
def create(request, payload: DeckIn):
    try:
        deck = create_deck(request.auth, payload.dict())
    except ValidationError as exc:
        return 400, {"detail": exc.detail}
    return 201, deck


@decks_router.get(
    "/{deck_id}",
    response={200: DeckOut, 404: ErrorOut},
    summary="Detalhe do deck (próprio ou público).",
)
def retrieve(request, deck_id: uuid.UUID):
    try:
        deck = get_deck_for_read(request.auth, deck_id)
    except ValidationError as exc:
        return 404, {"detail": exc.detail}
    return 200, deck


@decks_router.put(
    "/{deck_id}",
    response={200: DeckOut, 404: ErrorOut, 400: ErrorOut},
    summary="Atualiza campos do deck (dono apenas).",
)
def update(request, deck_id: uuid.UUID, payload: DeckUpdateIn):
    try:
        deck = get_deck_for_write(request.auth, deck_id)
        deck = update_deck(deck, payload.dict(exclude_unset=True))
    except ValidationError as exc:
        return 404, {"detail": exc.detail}
    return 200, deck


@decks_router.delete(
    "/{deck_id}",
    response={204: None, 404: ErrorOut},
    summary="Soft delete: marca o deck como arquivado.",
)
def destroy(request, deck_id: uuid.UUID):
    try:
        deck = get_deck_for_write(request.auth, deck_id)
    except ValidationError as exc:
        return 404, {"detail": exc.detail}
    archive_deck(deck)
    return 204, None


# ═════════════════════════════════════════════════════════════
#  CARDS (nested em deck)
# ═════════════════════════════════════════════════════════════
@decks_router.get(
    "/{deck_id}/cards",
    response={200: CardListOut, 404: ErrorOut},
    summary="Lista os cards do deck.",
)
def list_deck_cards(
    request,
    deck_id: uuid.UUID,
    search: Optional[str] = Query(None),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    try:
        deck = get_deck_for_read(request.auth, deck_id)
    except ValidationError as exc:
        return 404, {"detail": exc.detail}

    qs = list_cards(deck, search=search).order_by("-created_at")
    items, total = paginate(qs, limit, offset)
    effective_limit, effective_offset = page_bounds(limit, offset)
    return 200, {
        "cards": items,
        "count": total,
        "limit": effective_limit,
        "offset": effective_offset,
    }


@decks_router.post(
    "/{deck_id}/cards",
    response={201: CardOut, 400: ErrorOut, 404: ErrorOut},
    summary="Cria um card no deck.",
)
def create_card_view(request, deck_id: uuid.UUID, payload: CardIn):
    try:
        deck = get_deck_for_write(request.auth, deck_id)
        card = create_card(deck, payload.dict(), user=request.auth)
    except ValidationError as exc:
        # PRD: limite excedido = erro de negócio (400). Not found = 404.
        status = 404 if "não encontrado" in exc.detail.lower() else 400
        return status, {"detail": exc.detail}
    return 201, card


@decks_router.post(
    "/{deck_id}/generate",
    response={202: AsyncJobOut, 400: ErrorOut, 404: ErrorOut, 503: ErrorOut},
    summary="Dispara geração assíncrona de cards via IA (Groq + Llama 3.3 70B).",
)
def generate_cards(request, deck_id: uuid.UUID, payload: GenerateCardsIn):
    try:
        deck = get_deck_for_write(request.auth, deck_id)
    except ValidationError as exc:
        return 404, {"detail": exc.detail}

    try:
        job = enqueue_generate_cards(
            user=request.auth,
            deck_id=deck.id,
            topic=payload.topic,
            count=payload.count,
            language=payload.language,
            source_text=payload.source_text,
        )
    except JobError as exc:
        return 503, {"detail": exc.detail}

    return 202, job


@decks_router.post(
    "/{deck_id}/cards/import",
    response={201: CardImportOut, 400: ErrorOut, 404: ErrorOut},
    summary="Importa cards em lote a partir de um CSV (colunas: front, back).",
)
def import_cards(
    request, deck_id: uuid.UUID, file: UploadedFile = File(...)
):
    try:
        deck = get_deck_for_write(request.auth, deck_id)
        imported, skipped = import_cards_from_csv(deck, file.read(), user=request.auth)
    except ValidationError as exc:
        status = 404 if "não encontrado" in exc.detail.lower() else 400
        return status, {"detail": exc.detail}
    return 201, {"imported_count": imported, "skipped_count": skipped}


# ═════════════════════════════════════════════════════════════
#  CARDS (operações diretas por ID)
# ═════════════════════════════════════════════════════════════
@cards_router.put(
    "/{card_id}",
    response={200: CardOut, 404: ErrorOut},
    summary="Atualiza front/back/tags de um card.",
)
def update_card_view(request, card_id: uuid.UUID, payload: CardUpdateIn):
    try:
        card = get_card_for_write(request.auth, card_id)
        card = update_card(card, payload.dict(exclude_unset=True))
    except ValidationError as exc:
        return 404, {"detail": exc.detail}
    return 200, card


@cards_router.delete(
    "/{card_id}",
    response={204: None, 404: ErrorOut},
    summary="Remove um card permanentemente.",
)
def delete_card_view(request, card_id: uuid.UUID):
    try:
        card = get_card_for_write(request.auth, card_id)
    except ValidationError as exc:
        return 404, {"detail": exc.detail}
    delete_card(card)
    return 204, None
