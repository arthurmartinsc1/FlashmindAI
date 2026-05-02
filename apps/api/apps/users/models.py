"""Models do domínio `users`.

- `User`: usuário customizado com `email` como USERNAME_FIELD e PK UUID.
- `UserProgress`: agregados de progresso exibidos no dashboard (streaks etc.).
"""
from __future__ import annotations

import uuid

from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models


class UserManager(BaseUserManager):
    """Manager que usa `email` como identificador ao invés de `username`."""

    use_in_migrations = True

    def _create_user(self, email: str, password: str | None, **extra_fields):
        if not email:
            raise ValueError("O email é obrigatório.")
        email = self.normalize_email(email)
        extra_fields.setdefault("username", email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email: str, password: str | None = None, **extra_fields):
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        return self._create_user(email, password, **extra_fields)

    def create_superuser(self, email: str, password: str | None = None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser precisa ter is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser precisa ter is_superuser=True.")
        return self._create_user(email, password, **extra_fields)


class User(AbstractUser):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField("email", unique=True)
    name = models.CharField("nome", max_length=150, blank=True, default="")
    is_email_verified = models.BooleanField(default=False)
    email_verified_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["name"]

    objects = UserManager()

    class Meta:
        verbose_name = "user"
        verbose_name_plural = "users"
        indexes = [models.Index(fields=["email"])]

    def __str__(self) -> str:  # pragma: no cover
        return self.email


class EmailVerification(models.Model):
    """
    PIN de 6 dígitos enviado por email para confirmar a conta.

    Decisões de segurança:
    - Guardamos apenas o **hash** do PIN (sha256), nunca em plaintext.
    - `expires_at` força janela curta (15min default).
    - `attempts` limita força bruta no endpoint de verify.
    - `consumed_at` marca uso único: depois de validado, o registro fica
      como auditoria mas não pode ser reutilizado.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        "users.User",
        on_delete=models.CASCADE,
        related_name="email_verifications",
    )
    code_hash = models.CharField(max_length=128)
    expires_at = models.DateTimeField()
    attempts = models.IntegerField(default=0)
    consumed_at = models.DateTimeField(null=True, blank=True)
    sent_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-sent_at"]
        indexes = [
            models.Index(fields=["user", "consumed_at"]),
            models.Index(fields=["expires_at"]),
        ]

    def __str__(self) -> str:  # pragma: no cover
        return f"EmailVerification({self.user_id}, sent={self.sent_at:%Y-%m-%d %H:%M})"

    @property
    def is_valid(self) -> bool:
        from django.utils import timezone

        return self.consumed_at is None and self.expires_at > timezone.now()


class UserProgress(models.Model):
    """Snapshot de progresso consumido pelo dashboard e atualizado a cada review."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="progress",
    )
    current_streak = models.IntegerField(default=0)
    longest_streak = models.IntegerField(default=0)
    last_review_date = models.DateField(null=True, blank=True)
    total_reviews = models.IntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "user progress"
        verbose_name_plural = "user progress"

    def __str__(self) -> str:  # pragma: no cover
        return f"Progress({self.user_id})"
