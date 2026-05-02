"""Boota o Django dentro do worker para que as activities possam usar o ORM.

O código da API é montado em `/api` no container — `PYTHONPATH` já inclui
esse caminho (definido no Dockerfile/compose), então `config.settings`
resolve normalmente.
"""
from __future__ import annotations

import os


def configure_django() -> None:
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
    import django  # import tardio: depende de DJANGO_SETTINGS_MODULE

    django.setup()
