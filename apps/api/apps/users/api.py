"""Endpoints de autenticação do FlashMind (PRD F1)."""
from __future__ import annotations

import structlog
from django.contrib.auth import authenticate
from django_ratelimit.core import is_ratelimited
from ninja import Router
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError

from .email_verification import (
    EmailVerificationError,
    issue_verification_pin,
    verify_pin,
)
from .schemas import (
    AuthOut,
    EmailVerificationOut,
    ErrorOut,
    LoginIn,
    RefreshIn,
    RegisterIn,
    TokenPair,
    UserOut,
    VerifyPinIn,
)
from .security import JWTAuth
from .services import (
    ValidationError,
    blacklist_all_tokens_for_user,
    create_user_with_progress,
    issue_token_pair,
    rotate_refresh_token,
)
from django.conf import settings

logger = structlog.get_logger(__name__)

router = Router(tags=["Auth"])
jwt_auth = JWTAuth()


# ─── POST /auth/register ────────────────────────────────────
@router.post(
    "/register",
    response={201: AuthOut, 400: ErrorOut},
    summary="Cria uma nova conta e já devolve os tokens JWT.",
)
def register(request, payload: RegisterIn):
    try:
        user = create_user_with_progress(
            email=payload.email,
            password=payload.password,
            name=payload.name,
        )
    except ValidationError as exc:
        return 400, {"detail": exc.detail}

    return 201, {"user": user, "tokens": issue_token_pair(user)}


# ─── POST /auth/login ───────────────────────────────────────
@router.post(
    "/login",
    response={200: AuthOut, 400: ErrorOut, 401: ErrorOut, 429: ErrorOut},
    summary="Login por email/senha. Limitado a 5 tentativas/min por IP.",
    auth=None,
)
def login(request, payload: LoginIn):
    # Rate limit: 5 tentativas por minuto por IP.
    if is_ratelimited(
        request,
        group="auth:login",
        key="ip",
        rate="5/m",
        method="POST",
        increment=True,
    ):
        logger.warning("auth.login.rate_limited", email=payload.email)
        return 429, {"detail": "Muitas tentativas de login. Aguarde 1 minuto."}

    # Django `authenticate` usa USERNAME_FIELD (email) internamente.
    user = authenticate(request, username=payload.email, password=payload.password)
    if user is None or not user.is_active:
        logger.info("auth.login.failed", email=payload.email)
        return 401, {"detail": "Credenciais inválidas."}

    logger.info("auth.login.success", user_id=str(user.id))
    return 200, {"user": user, "tokens": issue_token_pair(user)}


# ─── POST /auth/refresh ─────────────────────────────────────
@router.post(
    "/refresh",
    response={200: TokenPair, 401: ErrorOut},
    summary="Troca um refresh token válido por um novo par (com rotation).",
    auth=None,
)
def refresh(request, payload: RefreshIn):
    try:
        tokens = rotate_refresh_token(payload.refresh_token)
    except (InvalidToken, TokenError):
        return 401, {"detail": "Refresh token inválido ou expirado."}
    except Exception:  # pragma: no cover - safety net
        return 401, {"detail": "Não foi possível renovar o token."}
    return 200, tokens


# ─── POST /auth/logout ──────────────────────────────────────
@router.post(
    "/logout",
    response={204: None},
    auth=jwt_auth,
    summary="Revoga todos os refresh tokens ativos do usuário autenticado.",
)
def logout(request):
    blacklist_all_tokens_for_user(request.auth)
    return 204, None


# ─── GET /auth/me ───────────────────────────────────────────
@router.get(
    "/me",
    response=UserOut,
    auth=jwt_auth,
    summary="Retorna o perfil do usuário autenticado.",
)
def me(request):
    return request.auth


# ─── POST /auth/email/verify ────────────────────────────────
@router.post(
    "/email/verify",
    response={200: UserOut, 400: ErrorOut, 429: ErrorOut},
    auth=jwt_auth,
    summary="Confirma o email com o PIN de 6 dígitos.",
)
def verify_email(request, payload: VerifyPinIn):
    try:
        user = verify_pin(request.auth, pin=payload.pin)
    except EmailVerificationError as exc:
        return exc.status, {"detail": exc.detail}
    return 200, user


# ─── POST /auth/email/resend ────────────────────────────────
@router.post(
    "/email/resend",
    response={200: EmailVerificationOut, 400: ErrorOut, 429: ErrorOut},
    auth=jwt_auth,
    summary="Reenvia um novo PIN respeitando o cooldown.",
)
def resend_email_verification(request):
    try:
        issue_verification_pin(request.auth)
    except EmailVerificationError as exc:
        return exc.status, {"detail": exc.detail}
    cfg = settings.EMAIL_VERIFICATION
    return 200, {
        "sent": True,
        "expires_in_minutes": cfg["TTL_MINUTES"],
        "cooldown_seconds": cfg["RESEND_COOLDOWN_SECONDS"],
    }
