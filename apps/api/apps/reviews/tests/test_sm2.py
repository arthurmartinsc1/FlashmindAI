"""Testes unitários do algoritmo SM-2.

Os cenários do TechSpecs §9.2 estão todos aqui, mais alguns casos extras
para cobrir bordas (senha de fazer o produto confiável):
- quality=3 (borderline de acerto)
- sequência longa de acertos (interval cresce exponencialmente)
- erro repetido não derruba EF abaixo do mínimo
- `today` parametrizável (determinismo)
"""
from __future__ import annotations

from datetime import date, timedelta

import pytest

from apps.reviews.services.sm2 import (
    DEFAULT_EASE_FACTOR,
    MIN_EASE_FACTOR,
    SM2Result,
    calculate_sm2,
)

FIXED_TODAY = date(2026, 4, 24)


class TestSM2FromSpec:
    """Cenários explícitos do TechSpecs §9.2."""

    def test_first_correct_review(self):
        """Primeiro acerto: interval = 1, repetitions = 1, EF inalterado p/ quality=4."""
        r = calculate_sm2(quality=4, today=FIXED_TODAY)
        assert r.interval == 1
        assert r.repetitions == 1
        assert r.ease_factor == DEFAULT_EASE_FACTOR  # quality=4 não altera EF

    def test_second_correct_review(self):
        """Segundo acerto: interval = 6."""
        r = calculate_sm2(quality=4, repetitions=1, interval=1, today=FIXED_TODAY)
        assert r.interval == 6
        assert r.repetitions == 2

    def test_third_correct_review(self):
        """Terceiro acerto: interval = round(previous * EF)."""
        r = calculate_sm2(
            quality=4, repetitions=2, interval=6, ease_factor=2.5, today=FIXED_TODAY
        )
        assert r.interval == 15  # round(6 * 2.5)
        assert r.repetitions == 3

    def test_incorrect_resets_progress(self):
        """Quality < 3: zera repetitions, interval volta a 1."""
        r = calculate_sm2(
            quality=1, repetitions=5, interval=30, ease_factor=2.5, today=FIXED_TODAY
        )
        assert r.repetitions == 0
        assert r.interval == 1

    def test_ease_factor_minimum(self):
        """EF nunca desce abaixo de 1.3."""
        r = calculate_sm2(quality=0, ease_factor=MIN_EASE_FACTOR, today=FIXED_TODAY)
        assert r.ease_factor >= MIN_EASE_FACTOR

    def test_perfect_score_increases_ef(self):
        """Quality=5 aumenta o EF."""
        r = calculate_sm2(quality=5, ease_factor=2.5, today=FIXED_TODAY)
        assert r.ease_factor > 2.5

    def test_next_review_date_uses_today(self):
        r = calculate_sm2(quality=4, today=FIXED_TODAY)
        assert r.next_review == FIXED_TODAY + timedelta(days=1)

    def test_next_review_defaults_to_today(self):
        """Sem parâmetro, usa `date.today()` (hoje)."""
        r = calculate_sm2(quality=4)
        assert r.next_review == date.today() + timedelta(days=1)

    @pytest.mark.parametrize("quality", [0, 1, 2, 3, 4, 5])
    def test_all_quality_values_are_valid(self, quality: int):
        r = calculate_sm2(quality=quality, today=FIXED_TODAY)
        assert r.interval >= 1
        assert r.ease_factor >= MIN_EASE_FACTOR
        assert r.repetitions >= 0

    @pytest.mark.parametrize("invalid", [-1, 6, 10, 100])
    def test_invalid_quality_raises(self, invalid: int):
        with pytest.raises(AssertionError):
            calculate_sm2(quality=invalid)


class TestSM2Edges:
    """Casos de borda / invariantes."""

    def test_quality_3_is_the_borderline_pass(self):
        """quality=3 é um acerto difícil: conta como acerto, interval vira 1."""
        r = calculate_sm2(quality=3, repetitions=0, today=FIXED_TODAY)
        assert r.interval == 1
        assert r.repetitions == 1

    def test_quality_4_is_neutral_for_ef(self):
        """Na fórmula original SM-2, delta = 0 quando quality = 4."""
        r = calculate_sm2(quality=4, ease_factor=2.5, today=FIXED_TODAY)
        assert abs(r.ease_factor - 2.5) < 1e-6

    def test_quality_3_penalizes_ef(self):
        """quality=3 conta como acerto mas reduz EF em 0.14."""
        r = calculate_sm2(quality=3, ease_factor=2.5, today=FIXED_TODAY)
        assert r.ease_factor < 2.5
        assert r.repetitions == 1  # ainda conta como acerto

    def test_repeated_failures_keep_ef_at_floor(self):
        """5 erros seguidos → EF fica travado em 1.3, não explode negativo."""
        ef = DEFAULT_EASE_FACTOR
        for _ in range(5):
            r = calculate_sm2(quality=0, ease_factor=ef, today=FIXED_TODAY)
            ef = r.ease_factor
        assert ef == MIN_EASE_FACTOR

    def test_long_success_streak_grows_interval_exponentially(self):
        """Sequência de acertos: interval 1 → 6 → round(6*EF) → round(prev*EF) ..."""
        state = dict(ease_factor=DEFAULT_EASE_FACTOR, interval=0, repetitions=0)
        intervals: list[int] = []
        for _ in range(5):
            r = calculate_sm2(quality=5, today=FIXED_TODAY, **state)
            intervals.append(r.interval)
            state = dict(
                ease_factor=r.ease_factor,
                interval=r.interval,
                repetitions=r.repetitions,
            )
        assert intervals[0] == 1
        assert intervals[1] == 6
        assert intervals[2] > intervals[1]
        assert intervals[3] > intervals[2]
        assert intervals[4] > intervals[3]

    def test_returns_sm2result_dataclass(self):
        r = calculate_sm2(quality=4, today=FIXED_TODAY)
        assert isinstance(r, SM2Result)

    def test_ease_factor_is_rounded_to_four_decimals(self):
        r = calculate_sm2(quality=5, ease_factor=2.5, today=FIXED_TODAY)
        as_str = f"{r.ease_factor}"
        assert "." in as_str
        decimals = as_str.split(".")[1]
        assert len(decimals) <= 4

    def test_today_parameter_is_respected(self):
        custom = date(2020, 1, 1)
        r = calculate_sm2(quality=4, today=custom)
        assert r.next_review == custom + timedelta(days=1)


class TestSM2Invariants:
    """Invariantes matemáticos da fórmula (property-ish)."""

    @pytest.mark.parametrize("q", [0, 1, 2])
    def test_any_failure_resets_repetitions_and_interval(self, q: int):
        r = calculate_sm2(
            quality=q, repetitions=10, interval=365, ease_factor=2.8, today=FIXED_TODAY
        )
        assert r.repetitions == 0
        assert r.interval == 1

    @pytest.mark.parametrize("q", [3, 4, 5])
    def test_any_pass_increments_repetitions(self, q: int):
        r = calculate_sm2(
            quality=q, repetitions=3, interval=15, ease_factor=2.5, today=FIXED_TODAY
        )
        assert r.repetitions == 4
