"""Activity que chama a Groq Cloud API para gerar flashcards.

Pedimos resposta no formato JSON estrito (response_format=json_object) e
parseamos. Em caso de payload inválido, levantamos ApplicationError
non-retryable, para o Temporal não ficar tentando para sempre.
"""
from __future__ import annotations

import json
import os
from dataclasses import dataclass
from typing import Any

import httpx
import structlog
from temporalio import activity
from temporalio.exceptions import ApplicationError

logger = structlog.get_logger(__name__)

GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
DEFAULT_MODEL = "llama-3.3-70b-versatile"
HTTP_TIMEOUT = 60.0


@dataclass
class GenerateCardsInput:
    job_id: str
    deck_id: str
    topic: str
    count: int
    language: str
    source_text: str = ""

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "GenerateCardsInput":
        return cls(
            job_id=data["job_id"],
            deck_id=data["deck_id"],
            topic=data["topic"],
            count=int(data.get("count", 10)),
            language=data.get("language", "pt-BR"),
            source_text=data.get("source_text", "") or "",
        )


def _build_prompt(inp: GenerateCardsInput) -> tuple[str, str]:
    system = (
        "Você é um gerador de flashcards educativos de altíssima qualidade. "
        "Responda SEMPRE em JSON válido, sem nenhum texto fora do JSON. "
        f"Idioma: {inp.language}. "
        "Cada flashcard deve ter 'front' (pergunta clara, curta) e 'back' "
        "(resposta objetiva, até 3 frases). Evite duplicatas."
    )
    user = (
        f"Tópico: {inp.topic}\n"
        f"Quantidade: {inp.count}\n"
    )
    if inp.source_text:
        user += f"\nTexto-fonte (use como base, não invente fora dele):\n{inp.source_text}\n"
    user += (
        "\nResponda no formato JSON:\n"
        '{"cards": [{"front": "...", "back": "..."}, ...]}'
    )
    return system, user


def _parse_cards(raw: str, expected: int) -> list[dict[str, str]]:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ApplicationError(
            f"Resposta da Groq não é JSON: {exc}",
            type="GroqInvalidJSON",
            non_retryable=True,
        )

    cards = data.get("cards") if isinstance(data, dict) else None
    if not isinstance(cards, list) or not cards:
        raise ApplicationError(
            "Resposta da Groq sem chave 'cards' válida.",
            type="GroqInvalidSchema",
            non_retryable=True,
        )

    cleaned: list[dict[str, str]] = []
    for item in cards:
        if not isinstance(item, dict):
            continue
        front = (item.get("front") or "").strip()
        back = (item.get("back") or "").strip()
        if front and back:
            cleaned.append({"front": front, "back": back})

    if not cleaned:
        raise ApplicationError(
            "Nenhum card válido retornado.",
            type="GroqEmptyResult",
            non_retryable=True,
        )

    return cleaned[:expected]


@activity.defn(name="call_groq_for_cards")
async def call_groq_for_cards(payload: dict[str, Any]) -> list[dict[str, str]]:
    inp = GenerateCardsInput.from_dict(payload)
    api_key = os.environ.get("GROQ_API_KEY", "")
    if not api_key:
        raise ApplicationError(
            "GROQ_API_KEY não configurada no worker.",
            type="GroqMissingKey",
            non_retryable=True,
        )

    model = os.environ.get("GROQ_MODEL", DEFAULT_MODEL)
    system, user = _build_prompt(inp)

    logger.info(
        "groq.request", job_id=inp.job_id, model=model, count=inp.count, topic=inp.topic[:80]
    )

    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.4,
        "max_tokens": 2048,
    }

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    async with httpx.AsyncClient(timeout=HTTP_TIMEOUT) as client:
        try:
            resp = await client.post(GROQ_URL, headers=headers, json=body)
        except httpx.HTTPError as exc:
            # Erro de rede: retryable (deixa o Temporal repetir).
            raise ApplicationError(
                f"Falha de rede ao chamar Groq: {exc}",
                type="GroqNetworkError",
            ) from exc

    if resp.status_code == 429 or resp.status_code >= 500:
        raise ApplicationError(
            f"Groq retornou {resp.status_code}: {resp.text[:200]}",
            type="GroqRetryable",
        )
    if resp.status_code >= 400:
        raise ApplicationError(
            f"Groq rejeitou a requisição ({resp.status_code}): {resp.text[:200]}",
            type="GroqClientError",
            non_retryable=True,
        )

    data = resp.json()
    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise ApplicationError(
            f"Estrutura de resposta inesperada da Groq: {exc}",
            type="GroqInvalidShape",
            non_retryable=True,
        )

    cards = _parse_cards(content, inp.count)
    logger.info("groq.response", job_id=inp.job_id, generated=len(cards))
    return cards


# ─── Lesson generation ────────────────────────────────────────

def _build_lesson_prompt(inp: GenerateCardsInput) -> tuple[str, str]:
    system = (
        "Você é um criador de micro-lições educativas de alta qualidade. "
        "Crie duas lições concisas (5 minutos cada) sobre o tópico dado. "
        f"Idioma: {inp.language}. "
        "Responda SEMPRE em JSON válido, sem nenhum texto fora do JSON."
    )
    user = f"Tópico: {inp.topic}\n"
    if inp.source_text:
        user += f"\nTexto-fonte (use como base):\n{inp.source_text}\n"
    user += (
        "\nCrie exatamente 2 micro-lições complementares, cada uma com 5 blocos nesta ordem:\n"
        "1. 'text' — introdução ao tópico em Markdown (2-3 parágrafos)\n"
        "2. 'highlight' — o conceito mais importante em destaque (frase curta)\n"
        "3. 'text' — detalhes, exemplos ou contexto adicional em Markdown\n"
        "4. 'quiz' — pergunta de múltipla escolha com 4 opções\n"
        "5. 'quiz' — segunda pergunta de múltipla escolha com 4 opções\n"
        "\nFormato JSON obrigatório:\n"
        '{"lessons": ['
        '{"title": "Título curto 1", "estimated_minutes": 5, "blocks": ['
        '{"type": "text", "order": 0, "content": {"body": "..."}}, '
        '{"type": "highlight", "order": 1, "content": {"body": "...", "color": "yellow"}}, '
        '{"type": "text", "order": 2, "content": {"body": "..."}}, '
        '{"type": "quiz", "order": 3, "content": {"question": "...", "options": ["A", "B", "C", "D"], "correct": 0, "explanation": "..."}}, '
        '{"type": "quiz", "order": 4, "content": {"question": "...", "options": ["A", "B", "C", "D"], "correct": 1, "explanation": "..."}}'
        "]}, "
        '{"title": "Título curto 2", "estimated_minutes": 5, "blocks": ['
        '{"type": "text", "order": 0, "content": {"body": "..."}}, '
        '{"type": "highlight", "order": 1, "content": {"body": "...", "color": "yellow"}}, '
        '{"type": "text", "order": 2, "content": {"body": "..."}}, '
        '{"type": "quiz", "order": 3, "content": {"question": "...", "options": ["A", "B", "C", "D"], "correct": 0, "explanation": "..."}}, '
        '{"type": "quiz", "order": 4, "content": {"question": "...", "options": ["A", "B", "C", "D"], "correct": 1, "explanation": "..."}}'
        "]}]}"
    )
    return system, user


def _clean_lesson(data: dict[str, Any]) -> dict[str, Any]:
    title = (data.get("title") or "").strip()
    if not title:
        raise ApplicationError(
            "Lição sem título.",
            type="GroqInvalidSchema",
            non_retryable=True,
        )

    raw_blocks = data.get("blocks")
    if not isinstance(raw_blocks, list) or not raw_blocks:
        raise ApplicationError(
            "Lição sem blocos.",
            type="GroqInvalidSchema",
            non_retryable=True,
        )

    cleaned: list[dict[str, Any]] = []
    for i, block in enumerate(raw_blocks):
        if not isinstance(block, dict):
            continue
        btype = block.get("type")
        content = block.get("content")
        if btype not in ("text", "highlight", "quiz") or not isinstance(content, dict):
            continue

        order = block.get("order", i)

        if btype == "text":
            body = (content.get("body") or "").strip()
            if body:
                cleaned.append(
                    {"type": "text", "order": order, "content": {"body": body}}
                )

        elif btype == "highlight":
            body = (content.get("body") or "").strip()
            color = content.get("color", "yellow")
            if color not in ("yellow", "blue", "green"):
                color = "yellow"
            if body:
                cleaned.append({
                    "type": "highlight",
                    "order": order,
                    "content": {"body": body, "color": color},
                })

        elif btype == "quiz":
            question = (content.get("question") or "").strip()
            options = content.get("options")
            if not question or not isinstance(options, list) or len(options) < 2:
                continue
            correct = content.get("correct", 0)
            if not isinstance(correct, int) or correct < 0 or correct >= len(options):
                correct = 0
            explanation = (content.get("explanation") or "").strip()
            cleaned.append({
                "type": "quiz",
                "order": order,
                "content": {
                    "question": question,
                    "options": [str(o) for o in options[:6]],
                    "correct": correct,
                    "explanation": explanation,
                },
            })

    if not cleaned:
        raise ApplicationError(
            "Nenhum bloco válido na lição gerada.",
            type="GroqEmptyResult",
            non_retryable=True,
        )

    estimated_minutes = max(1, min(120, int(data.get("estimated_minutes") or 5)))
    return {"title": title, "estimated_minutes": estimated_minutes, "blocks": cleaned}


def _parse_lesson(raw: str) -> dict[str, Any]:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ApplicationError(
            f"Resposta da Groq não é JSON: {exc}",
            type="GroqInvalidJSON",
            non_retryable=True,
        )

    if not isinstance(data, dict):
        raise ApplicationError(
            "Resposta da Groq não é um objeto JSON.",
            type="GroqInvalidSchema",
            non_retryable=True,
        )

    raw_lessons = data.get("lessons")
    if isinstance(raw_lessons, list):
        lessons = [_clean_lesson(item) for item in raw_lessons[:2] if isinstance(item, dict)]
        if len(lessons) >= 2:
            return {"lessons": lessons}
        raise ApplicationError(
            "Resposta da Groq não trouxe duas lições válidas.",
            type="GroqInvalidSchema",
            non_retryable=True,
        )

    return {"lessons": [_clean_lesson(data)]}


@activity.defn(name="generate_lesson_content")
async def generate_lesson_content(payload: dict[str, Any]) -> dict[str, Any]:
    inp = GenerateCardsInput.from_dict(payload)
    api_key = os.environ.get("GROQ_API_KEY", "")
    if not api_key:
        raise ApplicationError(
            "GROQ_API_KEY não configurada no worker.",
            type="GroqMissingKey",
            non_retryable=True,
        )

    model = os.environ.get("GROQ_MODEL", DEFAULT_MODEL)
    system, user = _build_lesson_prompt(inp)

    logger.info("groq.lesson_request", job_id=inp.job_id, topic=inp.topic[:80])

    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.5,
        "max_tokens": 5500,
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    async with httpx.AsyncClient(timeout=HTTP_TIMEOUT) as client:
        try:
            resp = await client.post(GROQ_URL, headers=headers, json=body)
        except httpx.HTTPError as exc:
            raise ApplicationError(
                f"Falha de rede ao chamar Groq: {exc}",
                type="GroqNetworkError",
            ) from exc

    if resp.status_code == 429 or resp.status_code >= 500:
        raise ApplicationError(
            f"Groq retornou {resp.status_code}: {resp.text[:200]}",
            type="GroqRetryable",
        )
    if resp.status_code >= 400:
        raise ApplicationError(
            f"Groq rejeitou a requisição ({resp.status_code}): {resp.text[:200]}",
            type="GroqClientError",
            non_retryable=True,
        )

    data = resp.json()
    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise ApplicationError(
            f"Estrutura inesperada da Groq: {exc}",
            type="GroqInvalidShape",
            non_retryable=True,
        )

    lesson_data = _parse_lesson(content)
    logger.info(
        "groq.lesson_response",
        job_id=inp.job_id,
        lessons=len(lesson_data["lessons"]),
        blocks=sum(len(lesson["blocks"]) for lesson in lesson_data["lessons"]),
    )
    return lesson_data
