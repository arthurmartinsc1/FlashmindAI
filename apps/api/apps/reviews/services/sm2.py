"""Algoritmo SuperMemo 2 (SM-2) — implementação pura em Python.

Independente do Django e do ORM; recebe primitivos e devolve um `SM2Result`.
Isso facilita testes unitários e reuso do lado cliente (Flutter também
implementa o mesmo algoritmo pra calcular offline — vide TechSpecs §6.3).

Referência: https://super-memory.com/english/ol/sm2.htm
PRD §F4 e TechSpecs §3.3.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta
from typing import Optional

MIN_EASE_FACTOR = 1.3
DEFAULT_EASE_FACTOR = 2.5


@dataclass(frozen=True)
class SM2Result:
    """Novos valores de SM-2 após um review."""

    ease_factor: float
    interval: int
    repetitions: int
    next_review: date


def calculate_sm2(
    quality: int,
    ease_factor: float = DEFAULT_EASE_FACTOR,
    interval: int = 0,
    repetitions: int = 0,
    today: Optional[date] = None,
) -> SM2Result:
    """Aplica a fórmula do SM-2 e retorna os novos parâmetros do card.

    Args:
        quality: Auto-avaliação do usuário (inteiro 0–5).
            0 = Blackout total
            1 = Errou muito
            2 = Errou
            3 = Difícil mas acertou
            4 = Bom
            5 = Fácil
        ease_factor: Fator de facilidade atual (mín. 1.3).
        interval: Intervalo atual em dias.
        repetitions: Quantos acertos consecutivos o card acumulou.
        today: Data-base para calcular `next_review`. Útil para testes
            determinísticos; quando `None`, usa `date.today()`.

    Returns:
        SM2Result com `ease_factor`, `interval`, `repetitions` e `next_review`.

    Raises:
        AssertionError: se `quality` estiver fora de [0, 5].
    """
    assert 0 <= quality <= 5, "quality precisa estar entre 0 e 5"
    assert ease_factor >= MIN_EASE_FACTOR, "ease_factor não pode ficar abaixo de 1.3"
    assert interval >= 0, "interval não pode ser negativo"
    assert repetitions >= 0, "repetitions não pode ser negativo"

    # 1) Novo fator de facilidade (mínimo 1.3)
    delta = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)
    new_ef = max(MIN_EASE_FACTOR, ease_factor + delta)

    # 2) Novo intervalo e contagem de repetições
    if quality < 3:
        # Resposta incorreta → reset de progresso; card volta a ser revisto
        # no próximo dia para reforço.
        new_repetitions = 0
        new_interval = 1
    else:
        new_repetitions = repetitions + 1
        if repetitions == 0:
            new_interval = 1
        elif repetitions == 1:
            new_interval = 6
        else:
            new_interval = round(interval * new_ef)

    base = today or date.today()
    return SM2Result(
        ease_factor=round(new_ef, 4),
        interval=new_interval,
        repetitions=new_repetitions,
        next_review=base + timedelta(days=new_interval),
    )
