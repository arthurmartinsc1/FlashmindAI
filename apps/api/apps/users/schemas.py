"""Schemas Ninja (Pydantic) para o módulo de autenticação."""
from __future__ import annotations

import uuid
from datetime import datetime

from ninja import Schema
from pydantic import EmailStr, Field


# ─── Input ───────────────────────────────────────────────────
class RegisterIn(Schema):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    name: str = Field(min_length=1, max_length=150)


class LoginIn(Schema):
    email: EmailStr
    password: str


class RefreshIn(Schema):
    refresh_token: str


# ─── Output ──────────────────────────────────────────────────
class UserOut(Schema):
    id: uuid.UUID
    email: EmailStr
    name: str
    is_email_verified: bool
    created_at: datetime


class VerifyPinIn(Schema):
    pin: str = Field(min_length=4, max_length=10)


class EmailVerificationOut(Schema):
    """Resposta dos endpoints de envio/reenvio de PIN."""

    sent: bool = True
    expires_in_minutes: int
    cooldown_seconds: int


class TokenPair(Schema):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"


class AuthOut(Schema):
    """Resposta de register/login: usuário + par de tokens."""

    user: UserOut
    tokens: TokenPair


class ErrorOut(Schema):
    detail: str
