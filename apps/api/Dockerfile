# syntax=docker/dockerfile:1.7
# ─────────────────────────────────────────────────────────────
#  STAGE 1 — builder: compila wheels (psycopg, etc) num ambiente
#  com toolchain. Saída final não carrega gcc/headers.
# ─────────────────────────────────────────────────────────────
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY requirements.txt .
RUN pip wheel --wheel-dir /wheels -r requirements.txt

# ─────────────────────────────────────────────────────────────
#  STAGE 2 — runtime: imagem enxuta com só o necessário pra rodar.
# ─────────────────────────────────────────────────────────────
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DJANGO_SETTINGS_MODULE=config.settings \
    PORT=8000

# Dependências de runtime:
# - libpq5: cliente PostgreSQL (psycopg precisa)
# - curl: usado por healthchecks
# - tini: init mínimo, encaminha sinais corretamente (importante em PaaS)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libpq5 \
        curl \
        tini \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Instala as wheels pré-compiladas — bem mais rápido + sem toolchain.
COPY --from=builder /wheels /wheels
COPY requirements.txt .
RUN pip install --no-index --find-links=/wheels -r requirements.txt \
    && rm -rf /wheels

COPY . .

RUN chmod +x /app/entrypoint.sh \
    && adduser --disabled-password --gecos "" --uid 10001 appuser \
    && chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]

# Em PaaS (Railway/Heroku/Fly), $PORT é injetado dinamicamente.
# `gunicorn` honra a env var; para Docker local, default é 8000.
CMD ["sh", "-c", "gunicorn config.wsgi:application \
    --bind 0.0.0.0:${PORT:-8000} \
    --workers ${GUNICORN_WORKERS:-3} \
    --threads ${GUNICORN_THREADS:-2} \
    --timeout ${GUNICORN_TIMEOUT:-60} \
    --access-logfile - \
    --error-logfile -"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -fsS "http://localhost:${PORT:-8000}/api/v1/health/live" || exit 1
