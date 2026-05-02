"""Integração do simplejwt com o Django Ninja (`HttpBearer`)."""
from __future__ import annotations

from typing import Optional

from ninja.security import HttpBearer
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError

from .models import User


class JWTAuth(HttpBearer):
    """
    Valida um Bearer <access_token>. Se válido, `request.auth` vira a
    instância `User` correspondente; caso contrário, o Ninja devolve 401.
    """

    openapi_scheme = "bearer"
    header = "Authorization"

    def __init__(self) -> None:
        super().__init__()
        self._authenticator = JWTAuthentication()

    def authenticate(self, request, token: str) -> Optional[User]:
        try:
            validated = self._authenticator.get_validated_token(token)
            user = self._authenticator.get_user(validated)
        except (InvalidToken, TokenError):
            return None
        except Exception:
            return None
        request.user = user
        return user
