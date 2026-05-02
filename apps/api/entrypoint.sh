#!/usr/bin/env bash
# Entrypoint do container da API: aguarda dependências, roda migrations e inicia o processo alvo.
set -euo pipefail

: "${POSTGRES_HOST:=db}"
: "${POSTGRES_PORT:=5432}"
: "${REDIS_HOST:=redis}"
: "${REDIS_PORT:=6379}"

wait_for() {
    local host="$1" port="$2" name="$3" retries=60
    echo "[entrypoint] aguardando ${name} em ${host}:${port}..."
    until python - <<PY 2>/dev/null
import socket, sys
s = socket.socket()
s.settimeout(2)
try:
    s.connect(("${host}", ${port}))
    sys.exit(0)
except Exception:
    sys.exit(1)
PY
    do
        retries=$((retries - 1))
        if [ "${retries}" -le 0 ]; then
            echo "[entrypoint] timeout esperando ${name}" >&2
            exit 1
        fi
        sleep 1
    done
    echo "[entrypoint] ${name} pronto."
}

wait_for "${POSTGRES_HOST}" "${POSTGRES_PORT}" "PostgreSQL"
wait_for "${REDIS_HOST}" "${REDIS_PORT}" "Redis"

echo "[entrypoint] aplicando migrations..."
python manage.py migrate --noinput

if [ "${DJANGO_COLLECTSTATIC:-0}" = "1" ]; then
    echo "[entrypoint] coletando arquivos estáticos..."
    python manage.py collectstatic --noinput
fi

echo "[entrypoint] iniciando processo: $*"
exec "$@"
