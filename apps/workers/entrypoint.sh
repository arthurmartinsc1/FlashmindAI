#!/usr/bin/env bash
# Aguarda Postgres e Temporal antes de iniciar o worker.
set -euo pipefail

: "${POSTGRES_HOST:=db}"
: "${POSTGRES_PORT:=5432}"
: "${TEMPORAL_HOST:=temporal}"
: "${TEMPORAL_PORT:=7233}"

wait_for() {
    local host="$1" port="$2" name="$3" retries=120
    echo "[worker] aguardando ${name} em ${host}:${port}..."
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
            echo "[worker] timeout esperando ${name}" >&2
            exit 1
        fi
        sleep 1
    done
    echo "[worker] ${name} pronto."
}

wait_for "${POSTGRES_HOST}" "${POSTGRES_PORT}" "PostgreSQL"
wait_for "${TEMPORAL_HOST}" "${TEMPORAL_PORT}" "Temporal"

echo "[worker] iniciando: $*"
exec "$@"
