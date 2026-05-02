-- Cria os bancos usados pelo Temporal Server (auto-setup).
-- Rodado uma única vez, na primeira inicialização do volume pgdata.
-- Se os DBs já existirem (pgdata persistente), nada acontece.

SELECT 'CREATE DATABASE temporal'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'temporal')\gexec

SELECT 'CREATE DATABASE temporal_visibility'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'temporal_visibility')\gexec
