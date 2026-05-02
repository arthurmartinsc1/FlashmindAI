"""Regras de negócio do domínio `users`: criação de usuário, tokens, blacklist."""
from __future__ import annotations

import re

import structlog
from django.db import transaction
from rest_framework_simplejwt.token_blacklist.models import (
    BlacklistedToken,
    OutstandingToken,
)
from rest_framework_simplejwt.tokens import RefreshToken

from .models import User, UserProgress

logger = structlog.get_logger(__name__)


class ValidationError(Exception):
    """Erro de validação de entrada exibido para o cliente."""

    def __init__(self, detail: str):
        self.detail = detail
        super().__init__(detail)


# ─── Password policy (PRD F1) ────────────────────────────────
# Mínimo 8 chars, ao menos 1 maiúscula e 1 número.
_PASSWORD_UPPER = re.compile(r"[A-Z]")
_PASSWORD_DIGIT = re.compile(r"\d")


def validate_password_strength(password: str) -> None:
    if len(password) < 8:
        raise ValidationError("A senha precisa ter pelo menos 8 caracteres.")
    if not _PASSWORD_UPPER.search(password):
        raise ValidationError("A senha precisa ter ao menos 1 letra maiúscula.")
    if not _PASSWORD_DIGIT.search(password):
        raise ValidationError("A senha precisa ter ao menos 1 número.")


# ─── User creation ───────────────────────────────────────────
@transaction.atomic
def create_user_with_progress(*, email: str, password: str, name: str) -> User:
    """Cria o usuário e o registro de progresso associado numa transação."""
    validate_password_strength(password)

    if User.objects.filter(email__iexact=email).exists():
        raise ValidationError("Já existe uma conta com esse email.")

    user = User.objects.create_user(email=email, password=password, name=name)
    UserProgress.objects.create(user=user)
    logger.info("user.registered", user_id=str(user.id), email=user.email)

    # Dispara verificação de email. Falha no envio NÃO impede o cadastro —
    # o usuário pode pedir reenvio via /auth/email/resend.
    try:
        from .email_verification import issue_verification_pin

        issue_verification_pin(user, force=True)
    except Exception as exc:  # pragma: no cover - log only
        logger.warning(
            "email.verification.send_failed",
            user_id=str(user.id),
            error=str(exc),
        )

    return user


# ─── JWT helpers ─────────────────────────────────────────────
def issue_token_pair(user: User) -> dict:
    """Emite um novo par access/refresh para o usuário."""
    refresh = RefreshToken.for_user(user)
    return {
        "access_token": str(refresh.access_token),
        "refresh_token": str(refresh),
        "token_type": "Bearer",
    }


def rotate_refresh_token(raw_refresh: str) -> dict:
    """
    Recebe um refresh token, valida, blacklista o antigo (rotation) e
    devolve um par novo.
    """
    refresh = RefreshToken(raw_refresh)  # valida assinatura + expiração
    # Blacklist o refresh atual (precisa do app token_blacklist instalado).
    try:
        refresh.blacklist()
    except AttributeError:  # pragma: no cover - safety net
        pass

    # Emite um par novo preservando o user embutido no token.
    user_id = refresh["user_id"]
    user = User.objects.get(id=user_id)
    return issue_token_pair(user)


def blacklist_all_tokens_for_user(user: User) -> int:
    """Revoga todos os refresh tokens ativos do usuário. Retorna quantos foram revogados."""
    outstanding = OutstandingToken.objects.filter(user=user)
    revoked = 0
    for token in outstanding:
        _, created = BlacklistedToken.objects.get_or_create(token=token)
        if created:
            revoked += 1
    logger.info("user.logout", user_id=str(user.id), tokens_revoked=revoked)
    return revoked
