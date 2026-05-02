"""
Configuração Django do FlashMind.

Um único arquivo, parametrizado por variáveis de ambiente, atende dev e prod.
Se precisar de divergência maior (ex: backends distintos), é trivial extrair
em `config/settings/{base,dev,prod}.py` depois.
"""

from __future__ import annotations

from datetime import timedelta
from pathlib import Path

import environ
import structlog

BASE_DIR = Path(__file__).resolve().parent.parent

# ──────────────────────────────────────────────────────────────
# Env
# ──────────────────────────────────────────────────────────────
env = environ.Env(
    DJANGO_DEBUG=(bool, False),
    JWT_ACCESS_TOKEN_LIFETIME_MINUTES=(int, 15),
    JWT_REFRESH_TOKEN_LIFETIME_DAYS=(int, 7),
    SENTRY_TRACES_SAMPLE_RATE=(float, 0.1),
)

# Carrega .env da raiz do monorepo se existir (útil fora de Docker).
_root_env = BASE_DIR.parent.parent / ".env"
if _root_env.exists():
    environ.Env.read_env(str(_root_env))

SECRET_KEY = env("DJANGO_SECRET_KEY", default="dev-insecure-change-me")
APPEND_SLASH = False
DEBUG = env("DJANGO_DEBUG")
ALLOWED_HOSTS = [
    h.strip()
    for h in env("DJANGO_ALLOWED_HOSTS", default="localhost,127.0.0.1").split(",")
    if h.strip()
]

# Em desenvolvimento, libera qualquer Host. Isso é necessário para que o app
# mobile (Android emulator usa 10.0.2.2; dispositivo físico usa o IP da LAN
# da sua máquina) consiga falar com a API sem dar `DisallowedHost`. Em prod
# (`DJANGO_DEBUG=false`) o controle volta a ser estrito via env.
if DEBUG:
    ALLOWED_HOSTS = ["*"]

# ──────────────────────────────────────────────────────────────
# Applications
# ──────────────────────────────────────────────────────────────
INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Third-party
    "corsheaders",
    "rest_framework_simplejwt.token_blacklist",
    # Local
    "apps.core",
    "apps.users",
    "apps.decks",
    "apps.reviews",
    "apps.microlearning",
    "apps.jobs",
]

MIDDLEWARE = [
    "apps.core.middleware.TimingMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

# ──────────────────────────────────────────────────────────────
# Database (PostgreSQL 16 via psycopg v3)
# ──────────────────────────────────────────────────────────────
# Preferimos DATABASE_URL (12-factor), com fallback para POSTGRES_* individuais.
_default_db_url = "postgres://{user}:{pwd}@{host}:{port}/{db}".format(
    user=env("POSTGRES_USER", default="flash"),
    pwd=env("POSTGRES_PASSWORD", default="secret"),
    host=env("POSTGRES_HOST", default="db"),
    port=env("POSTGRES_PORT", default="5432"),
    db=env("POSTGRES_DB", default="flashmind"),
)
DATABASES = {
    "default": env.db_url("DATABASE_URL", default=_default_db_url),
}
DATABASES["default"].setdefault("CONN_MAX_AGE", 60)

# ──────────────────────────────────────────────────────────────
# Cache / Rate limit (Redis 7)
# ──────────────────────────────────────────────────────────────
REDIS_URL = env("REDIS_URL", default="redis://redis:6379/0")
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": REDIS_URL,
    }
}

# django-ratelimit usa o cache default por padrão.

# ──────────────────────────────────────────────────────────────
# Auth / User model
# ──────────────────────────────────────────────────────────────
AUTH_USER_MODEL = "users.User"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
        "OPTIONS": {"min_length": 8},
    },
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# ──────────────────────────────────────────────────────────────
# JWT (simplejwt) — usado pelo endpoint /api/v1/auth/*
# ──────────────────────────────────────────────────────────────
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=env("JWT_ACCESS_TOKEN_LIFETIME_MINUTES")),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=env("JWT_REFRESH_TOKEN_LIFETIME_DAYS")),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "ALGORITHM": "HS256",
    "SIGNING_KEY": SECRET_KEY,
    "AUTH_HEADER_TYPES": ("Bearer",),
    "USER_ID_FIELD": "id",
    "USER_ID_CLAIM": "user_id",
}

# ──────────────────────────────────────────────────────────────
# Django Ninja
# ──────────────────────────────────────────────────────────────
NINJA_DOCS_URL = "/api/docs"

# ──────────────────────────────────────────────────────────────
# CORS
# ──────────────────────────────────────────────────────────────
CORS_ALLOWED_ORIGINS = [
    o.strip()
    for o in env("CORS_ALLOWED_ORIGINS", default="http://localhost:3000").split(",")
    if o.strip()
]
CORS_ALLOW_CREDENTIALS = True

# Em DEBUG, permite qualquer origem para facilitar testes do front em LAN
# (ex.: abrir de outro device na rede). O mobile não usa CORS — é nativo.
if DEBUG:
    CORS_ALLOW_ALL_ORIGINS = True

# ──────────────────────────────────────────────────────────────
# Segurança (defaults sensatos; em DEBUG relaxamos um pouco)
# ──────────────────────────────────────────────────────────────
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"
CSRF_COOKIE_HTTPONLY = True
SESSION_COOKIE_HTTPONLY = True

if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = 63072000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

# ──────────────────────────────────────────────────────────────
# Temporal
# ──────────────────────────────────────────────────────────────
TEMPORAL = {
    "ADDRESS": env("TEMPORAL_ADDRESS", default="temporal:7233"),
    "NAMESPACE": env("TEMPORAL_NAMESPACE", default="default"),
    "TASK_QUEUE": env("TEMPORAL_TASK_QUEUE", default="flashmind-queue"),
}

# ──────────────────────────────────────────────────────────────
# Groq (LLM) — lido pelos workers/activities
# ──────────────────────────────────────────────────────────────
GROQ_API_KEY = env("GROQ_API_KEY", default="")
GROQ_MODEL = env("GROQ_MODEL", default="llama-3.3-70b-versatile")

# ──────────────────────────────────────────────────────────────
# Email
# ──────────────────────────────────────────────────────────────
# Estratégia: se SMTP_HOST estiver definido, usa SMTP de verdade
# (Resend, SendGrid, Gmail, etc). Caso contrário, cai pra console
# (mostra o email no log da API) — assim o cadastro nunca quebra
# em dev por falta de configuração.
EMAIL_HOST = env("SMTP_HOST", default="")
EMAIL_PORT = env.int("SMTP_PORT", default=587)
EMAIL_HOST_USER = env("SMTP_USER", default="")
EMAIL_HOST_PASSWORD = env("SMTP_PASSWORD", default="")
EMAIL_USE_TLS = env.bool("SMTP_USE_TLS", default=True)
DEFAULT_FROM_EMAIL = env("EMAIL_FROM", default="FlashMind <noreply@flashmind.app>")
EMAIL_TIMEOUT = env.int("SMTP_TIMEOUT", default=15)

EMAIL_BACKEND = env(
    "EMAIL_BACKEND",
    default=(
        "django.core.mail.backends.smtp.EmailBackend"
        if EMAIL_HOST
        else "django.core.mail.backends.console.EmailBackend"
    ),
)

EMAIL_VERIFICATION = {
    "PIN_LENGTH": 6,
    "TTL_MINUTES": env.int("EMAIL_VERIFICATION_TTL_MINUTES", default=15),
    "MAX_ATTEMPTS": env.int("EMAIL_VERIFICATION_MAX_ATTEMPTS", default=5),
    "RESEND_COOLDOWN_SECONDS": env.int("EMAIL_VERIFICATION_RESEND_COOLDOWN", default=60),
}

# ──────────────────────────────────────────────────────────────
# Logging (structlog + stdlib)
# ──────────────────────────────────────────────────────────────
LOG_LEVEL = env("LOG_LEVEL", default="INFO")

_timestamper = structlog.processors.TimeStamper(fmt="iso")

_shared_processors = [
    structlog.contextvars.merge_contextvars,
    structlog.stdlib.add_log_level,
    structlog.stdlib.add_logger_name,
    _timestamper,
    structlog.processors.StackInfoRenderer(),
    structlog.processors.format_exc_info,
]

structlog.configure(
    processors=[
        *_shared_processors,
        structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
    ],
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

_renderer = (
    structlog.dev.ConsoleRenderer(colors=True)
    if DEBUG
    else structlog.processors.JSONRenderer()
)

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "structlog": {
            "()": "structlog.stdlib.ProcessorFormatter",
            "processors": [
                structlog.stdlib.ProcessorFormatter.remove_processors_meta,
                _renderer,
            ],
            "foreign_pre_chain": _shared_processors,
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "structlog",
        },
    },
    "root": {"handlers": ["console"], "level": LOG_LEVEL},
    "loggers": {
        "django": {"handlers": ["console"], "level": LOG_LEVEL, "propagate": False},
        "django.server": {"handlers": ["console"], "level": "INFO", "propagate": False},
        "django.db.backends": {"handlers": ["console"], "level": "WARNING", "propagate": False},
    },
}

# ──────────────────────────────────────────────────────────────
# Sentry (opcional — só inicializa se DSN presente)
# ──────────────────────────────────────────────────────────────
_sentry_dsn = env("SENTRY_DSN", default="")
if _sentry_dsn:
    import sentry_sdk
    from sentry_sdk.integrations.django import DjangoIntegration
    from sentry_sdk.integrations.logging import LoggingIntegration
    from sentry_sdk.integrations.redis import RedisIntegration

    sentry_sdk.init(
        dsn=_sentry_dsn,
        integrations=[
            DjangoIntegration(),
            RedisIntegration(),
            # Captura WARNING+ como breadcrumb e ERROR+ como evento.
            LoggingIntegration(level=None, event_level="ERROR"),
        ],
        traces_sample_rate=env("SENTRY_TRACES_SAMPLE_RATE"),
        profiles_sample_rate=env.float("SENTRY_PROFILES_SAMPLE_RATE", default=0.0),
        send_default_pii=False,
        environment=env("SENTRY_ENVIRONMENT", default="development" if DEBUG else "production"),
        release=env("SENTRY_RELEASE", default=None),
        attach_stacktrace=True,
        max_breadcrumbs=50,
    )
    sentry_sdk.set_tag("service", "api")

# ──────────────────────────────────────────────────────────────
# i18n / tz
# ──────────────────────────────────────────────────────────────
LANGUAGE_CODE = "pt-br"
TIME_ZONE = "America/Sao_Paulo"
USE_I18N = True
USE_TZ = True

# ──────────────────────────────────────────────────────────────
# Static / default PK
# ──────────────────────────────────────────────────────────────
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
