"""Cache helpers centralizados (Redis via Django cache framework).

Estratégia de invalidação por versão de usuário:
- Cada usuário tem um contador `vc:{user_id}` no Redis.
- Todas as chaves de cache do usuário incluem esse contador.
- Para invalidar todo o cache de um usuário basta incrementar o contador —
  as entradas antigas ficam órfãs e expiram pelo TTL naturalmente.

Decks públicos usam TTL curto (5 min) sem versão — evita complexidade de
invalidação cross-user quando qualquer usuário publica/despublica um deck.
"""
from __future__ import annotations

from typing import Any

from django.core.cache import cache

# ─── TTLs ────────────────────────────────────────────────
TTL_DASHBOARD = 2 * 3600   # 2 h  — agrega reviews + streak
TTL_DUE       = 30 * 60    # 30 min — muda quando user revisa
TTL_DECKS     = 15 * 60    # 15 min — muda quando cria/edita deck/card
TTL_DECK      = 60 * 60    # 1 h  — detalhe de um deck
TTL_CARDS     = 15 * 60    # 15 min — lista de cards de um deck
TTL_PUBLIC    =  5 * 60    # 5 min  — decks públicos (sem versão de usuário)
TTL_SUMMARY   = 30 * 60    # 30 min — resumo diário (invalidado via versão)
TTL_VERSION   = 7 * 86400  # 7 dias — vida do contador de versão


# ─── Versão por usuário ───────────────────────────────────────

def _version_key(user_id: Any) -> str:
    return f"vc:{user_id}"


def _user_version(user_id: Any) -> int:
    key = _version_key(user_id)
    v = cache.get(key)
    if v is None:
        cache.add(key, 1, timeout=TTL_VERSION)
        return 1
    return v


def invalidate_user(user_id: Any) -> None:
    """Invalida todo o cache do usuário incrementando a versão."""
    key = _version_key(user_id)
    try:
        cache.incr(key)
    except ValueError:
        cache.set(key, 1, timeout=TTL_VERSION)


# ─── Builders de chave ───────────────────────────────────────

def _key(prefix: str, user_id: Any, *parts: Any) -> str:
    v = _user_version(user_id)
    tail = ":".join(str(p) for p in parts)
    return f"{prefix}:{user_id}:{v}:{tail}" if tail else f"{prefix}:{user_id}:{v}"


def dashboard_key(user_id: Any) -> str:
    return _key("dash", user_id)


def due_cards_key(user_id: Any, deck_id: Any = None) -> str:
    return _key("due", user_id, deck_id or "all")


def decks_key(user_id: Any, search: str | None, limit: int, offset: int) -> str:
    return _key("decks", user_id, search or "", limit, offset)


def deck_key(user_id: Any, deck_id: Any) -> str:
    return _key("deck", user_id, deck_id)


def cards_key(user_id: Any, deck_id: Any, search: str | None, limit: int, offset: int) -> str:
    return _key("cards", user_id, deck_id, search or "", limit, offset)


def summary_key(user_id: Any, day: Any) -> str:
    return _key("summary", user_id, str(day))


def public_decks_key(search: str | None, limit: int, offset: int) -> str:
    """Chave global para decks públicos — sem versão de usuário."""
    return f"pub:{search or ''}:{limit}:{offset}"


# ─── Helpers get/set ─────────────────────────────────────────

def get_or_set(key: str, fn, ttl: int) -> Any:
    """Retorna valor cacheado ou executa `fn()` e armazena o resultado."""
    value = cache.get(key)
    if value is None:
        value = fn()
        cache.set(key, value, timeout=ttl)
    return value
