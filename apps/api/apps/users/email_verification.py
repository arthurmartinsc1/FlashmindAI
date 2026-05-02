"""Lógica de verificação de email por PIN de 6 dígitos.

Este módulo é intencionalmente desacoplado de `services.py` (que cuida de
auth) para deixar claro o domínio: emissão e validação de PINs, com regra
de expiração, limite de tentativas e cooldown de reenvio.
"""
from __future__ import annotations

import hashlib
import secrets

import structlog
from django.conf import settings
from django.core.mail import send_mail
from django.db import transaction
from django.template.loader import render_to_string
from django.utils import timezone
from datetime import timedelta

from .models import EmailVerification, User

logger = structlog.get_logger(__name__)


class EmailVerificationError(Exception):
    def __init__(self, detail: str, *, status: int = 400):
        self.detail = detail
        self.status = status
        super().__init__(detail)


# ─── Hash determinístico do PIN ──────────────────────────────
# bcrypt seria overkill (PIN tem só 1M combinações e dura 15min);
# sha256 + segredo do app é suficiente — o segredo evita rainbow tables.
def _hash_pin(pin: str) -> str:
    secret = settings.SECRET_KEY
    return hashlib.sha256(f"{secret}:{pin}".encode("utf-8")).hexdigest()


def _generate_pin() -> str:
    length = settings.EMAIL_VERIFICATION["PIN_LENGTH"]
    # secrets.below(...) gera int crypto-random; zfill mantém zeros à esquerda.
    upper = 10**length
    return str(secrets.randbelow(upper)).zfill(length)


def _send_email_with_pin(user: User, pin: str) -> None:
    ttl_min = settings.EMAIL_VERIFICATION["TTL_MINUTES"]
    context = {
        # Primeira palavra do nome (ex: "Lucas Tutu" → "Lucas") fica mais
        # íntimo do que o nome completo no header do email.
        "name": (user.name or user.email).split()[0],
        "pin": pin,
        "ttl_minutes": ttl_min,
    }
    text_body = render_to_string("emails/verify_email.txt", context)
    html_body = render_to_string("emails/verify_email.html", context)

    # Subject com o PIN no início aparece bonito no preview do Gmail/Outlook
    # ("123456 é seu código FlashMind"), economizando 1 abertura pro user.
    send_mail(
        subject=f"{pin} é seu código FlashMind",
        message=text_body,
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[user.email],
        html_message=html_body,
        fail_silently=False,
    )


# ─── API pública ─────────────────────────────────────────────
@transaction.atomic
def issue_verification_pin(user: User, *, force: bool = False) -> EmailVerification:
    """
    Cria um PIN novo, invalida os anteriores não-consumidos e envia o email.

    `force=True` ignora o cooldown de reenvio (usado no register inicial,
    por exemplo, onde sempre queremos enviar).
    """
    if user.is_email_verified:
        raise EmailVerificationError("Email já está verificado.", status=400)

    cooldown = settings.EMAIL_VERIFICATION["RESEND_COOLDOWN_SECONDS"]
    last = (
        EmailVerification.objects.filter(user=user, consumed_at__isnull=True)
        .order_by("-sent_at")
        .first()
    )
    if not force and last and (timezone.now() - last.sent_at).total_seconds() < cooldown:
        wait = int(cooldown - (timezone.now() - last.sent_at).total_seconds())
        raise EmailVerificationError(
            f"Aguarde {wait}s antes de pedir um novo código.",
            status=429,
        )

    # Invalida os anteriores ainda em aberto.
    EmailVerification.objects.filter(
        user=user, consumed_at__isnull=True
    ).update(consumed_at=timezone.now())

    pin = _generate_pin()
    ttl = timedelta(minutes=settings.EMAIL_VERIFICATION["TTL_MINUTES"])
    record = EmailVerification.objects.create(
        user=user,
        code_hash=_hash_pin(pin),
        expires_at=timezone.now() + ttl,
    )

    _send_email_with_pin(user, pin)
    logger.info(
        "email.verification.sent",
        user_id=str(user.id),
        verification_id=str(record.id),
        expires_at=str(record.expires_at),
    )
    return record


@transaction.atomic
def verify_pin(user: User, *, pin: str) -> User:
    """Valida o PIN. Em caso de sucesso, marca o usuário como verificado."""
    if user.is_email_verified:
        return user

    pin = (pin or "").strip()
    if not pin.isdigit() or len(pin) != settings.EMAIL_VERIFICATION["PIN_LENGTH"]:
        raise EmailVerificationError("Código inválido.", status=400)

    record = (
        EmailVerification.objects.select_for_update()
        .filter(user=user, consumed_at__isnull=True)
        .order_by("-sent_at")
        .first()
    )
    if record is None:
        raise EmailVerificationError(
            "Nenhum código pendente. Solicite um novo.", status=400
        )

    if record.expires_at <= timezone.now():
        record.consumed_at = timezone.now()
        record.save(update_fields=["consumed_at"])
        raise EmailVerificationError("Código expirado. Solicite um novo.", status=400)

    if record.attempts >= settings.EMAIL_VERIFICATION["MAX_ATTEMPTS"]:
        record.consumed_at = timezone.now()
        record.save(update_fields=["consumed_at"])
        raise EmailVerificationError(
            "Limite de tentativas atingido. Solicite um novo código.",
            status=429,
        )

    if _hash_pin(pin) != record.code_hash:
        record.attempts += 1
        record.save(update_fields=["attempts"])
        remaining = settings.EMAIL_VERIFICATION["MAX_ATTEMPTS"] - record.attempts
        raise EmailVerificationError(
            f"Código incorreto. Restam {max(remaining, 0)} tentativa(s).",
            status=400,
        )

    record.consumed_at = timezone.now()
    record.save(update_fields=["consumed_at"])

    user.is_email_verified = True
    user.email_verified_at = timezone.now()
    user.save(update_fields=["is_email_verified", "email_verified_at", "updated_at"])

    logger.info("email.verification.confirmed", user_id=str(user.id))
    return user
