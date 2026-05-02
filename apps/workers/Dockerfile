# syntax=docker/dockerfile:1.7
# ─────────────────────────────────────────────────────────────
#  STAGE 1 — builder: pré-compila wheels.
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
# Build context = raiz do repo (ver docker-compose.yml: context: .)
COPY apps/workers/requirements.txt .
RUN pip wheel --wheel-dir /wheels -r requirements.txt

# ─────────────────────────────────────────────────────────────
#  STAGE 2 — runtime
# ─────────────────────────────────────────────────────────────
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONPATH=/api:/app \
    DJANGO_SETTINGS_MODULE=config.settings

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libpq5 \
        tini \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /wheels /wheels
COPY apps/workers/requirements.txt .
RUN pip install --no-index --find-links=/wheels -r requirements.txt \
    && rm -rf /wheels

# Build context = raiz do repo. Copia worker + API (worker importa Django ORM).
# Em dev o docker-compose monta volume por cima desses paths, então sobrescreve.
COPY apps/workers/ ./
COPY apps/api/ /api/

RUN chmod +x /app/entrypoint.sh \
    && adduser --disabled-password --gecos "" --uid 10001 appuser \
    && chown -R appuser:appuser /app /api

USER appuser

ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]

CMD ["python", "worker.py"]
