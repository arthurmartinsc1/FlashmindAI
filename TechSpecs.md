# TechSpecs — FlashMind

## Technical Specifications Document

**Versão:** 1.2  
**Data:** 2026-04-29  
**Autor:** [Seu nome]  
**Status:** Alinhado ao MVP implementado (frontend web revisado neste doc)
**PRD Referência:** PRD.md v1.1

---

## 1. Stack Tecnológica

### 1.1 Decisões e Justificativas

| Camada | Tecnologia | Justificativa |
|--------|------------|---------------|
| Frontend Web | Next.js 14 (App Router) | SSR para landing (SEO), SPA para app, ecosystem React maduro |
| Estilização | Tailwind CSS + shadcn/ui | Prototipação rápida, design system consistente, zero CSS custom |
| Backend API | Django 4.2 + Django Ninja | ORM robusto, auth built-in, Ninja é tipo FastAPI mas no Django |
| Banco de Dados | PostgreSQL 16 | ACID, JSONField nativo, full-text search, padrão da indústria |
| Cache / Rate Limit | Redis 7 | Cache de queries, rate limiting, session store, pub/sub futuro |
| Workflows Async | Temporal (Python SDK) | Durável, retry nativo, visibilidade de execução, melhor que Celery para workflows complexos |
| Mobile | Flutter 3.x (Dart) | Cross-platform real, performance nativa, offline com Drift/SQLite |
| IA / LLM | Groq Cloud + Llama 3.3 70B | Gratuito, latência ~500ms, qualidade suficiente para flashcards, sem vendor lock-in |
| Observabilidade | Sentry + structlog | Error tracking com stack traces, logs estruturados em JSON |
| CI/CD | GitHub Actions | Integrado ao repo, free tier generoso, marketplace de actions |
| Containerização | Docker + Docker Compose | Ambiente reproduzível, deploy simplificado, isolamento de serviços |
| Deploy (produção — **provisório**) | **Vercel + Render** | Direção provável ainda não fechada: **Vercel** para Next.js; **Render** para API Django e stack satélite (Postgres/Redis/worker/Temporal conforme blueprint). Alternativas (ex.: Railway, VPS + Compose) permanecem válidas para o desafio. **Mobile:** sem publicação em loja por ora — validação no **Simulator iOS** (`flutter run`) contra API local ou URL de staging. |

### 1.2 Versões Fixadas

```
# Backend
Python==3.12
Django==4.2.*
django-ninja==1.3.*
djangorestframework-simplejwt==5.3.*
psycopg[binary]==3.2.*
redis==5.0.*
temporalio==1.7.*
structlog==24.*
sentry-sdk[django]==2.*
django-cors-headers==4.4.*
django-ratelimit==4.1.*
gunicorn==22.*
httpx==0.27.*  # para chamadas à Groq API

# Frontend
next==14.2.*
react==18.3.*
typescript==5.5.*
tailwindcss==3.4.*
@tanstack/react-query==5.*
axios==1.7.*
zustand==4.5.*  # state management leve
react-markdown==9.*
framer-motion==11.*

# Mobile (pubspec.yaml)
flutter: ">=3.22.0"
drift: ^2.20.3
drift_dev: ^2.20.3
dio: ^5.7.0
flutter_riverpod: ^2.5.0
go_router: ^14.0.0
connectivity_plus: ^6.0.0
build_runner: ^2.4.13
```

---

## 2. Arquitetura

### 2.1 Visão Geral

```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERNET                                │
└──────┬──────────────────┬────────────────────┬──────────────────┘
       │                  │                    │
┌──────▼───────┐  ┌───────▼────────┐  ┌────────▼─────────┐
│   Vercel     │  │    Render      │  │  Mobile (dev)    │
│  (Next.js)   │  │   (Backend)    │  │  Simulator iOS   │
│   provável   │  │   provável     │  │  loja: TBD       │
│              │  │                │  │                   │
│ - Landing    │  │ ┌────────────┐ │  │ ┌───────────────┐ │
│   (SSR/SSG)  │  │ │  Nginx     │ │  │ │ Flutter App   │ │
│ - Web App    │  │ │  (reverse  │ │  │ │               │ │
│   (CSR)      │  │ │   proxy)   │ │  │ │ ┌───────────┐ │ │
│              │  │ └─────┬──────┘ │  │ │ │  SQLite   │ │ │
│              │  │       │        │  │ │ │  (Drift)  │ │ │
│              │  │ ┌─────▼──────┐ │  │ │ └───────────┘ │ │
│              │  │ │  Gunicorn  │ │  │ │               │ │
│              │  │ │  + Django  │ │  │ │ ┌───────────┐ │ │
│              │  │ │  + Ninja   │ │  │ │ │SyncService│ │ │
│              │  │ └──┬────┬──┬─┘ │  │ │ └───────────┘ │ │
│              │  │    │    │  │    │  │ └───────────────┘ │
│              │  │ ┌──▼┐ ┌▼──▼──┐ │  └──────────────────┘
│              │  │ │PG │ │Redis │ │
│              │  │ │16 │ │  7   │ │
│              │  │ └───┘ └──────┘ │
│              │  │                │
│              │  │ ┌────────────┐ │
│              │  │ │  Temporal  │ │
│              │  │ │  Server    │ │
│              │  │ └─────┬──────┘ │
│              │  │       │        │
│              │  │ ┌─────▼──────┐ │
│              │  │ │  Worker    │ │
│              │  │ │  Service   │ │
│              │  │ └─────┬──────┘ │
│              │  │       │        │
│              │  │ ┌─────▼──────┐ │
│              │  │ │ Groq API   │ │
│              │  │ │ (external) │ │
│              │  │ └────────────┘ │
└──────────────┘  └────────────────┘
```

### 2.2 Estrutura do Monorepo

```
flashmind/
├── apps/
│   ├── web/                          # Next.js 14 (App Router)
│   │   ├── src/
│   │   │   ├── app/
│   │   │   │   ├── layout.tsx        # Metadata SEO global, Providers
│   │   │   │   ├── globals.css
│   │   │   │   ├── robots.ts
│   │   │   │   ├── sitemap.ts
│   │   │   │   ├── (marketing)/      # Landing pública
│   │   │   │   │   └── page.tsx      # Hero, Features, Pricing…
│   │   │   │   ├── (auth)/           # Login, Register, verify-email
│   │   │   │   └── (app)/            # Área autenticada (AuthGuard + sidebar)
│   │   │   │       ├── layout.tsx
│   │   │   │       ├── dashboard/
│   │   │   │       ├── decks/
│   │   │   │       │   ├── page.tsx
│   │   │   │       │   └── [id]/page.tsx   # Tabs: Cards, Micro-lição, Stats
│   │   │   │       ├── review/page.tsx     # Lista/sessão; ?deck_id=
│   │   │   │       └── ai/page.tsx          # IA opcional por seleção de deck
│   │   │   ├── components/
│   │   │   │   ├── ui/               # shadcn
│   │   │   │   ├── app/              # Sidebar, Topbar, AuthGuard, UserMenu
│   │   │   │   ├── landing/
│   │   │   │   ├── dashboard/
│   │   │   │   ├── decks/            # CardList, AIGenerate, stats…
│   │   │   │   ├── microlearning/
│   │   │   │   └── study/            # FlipCard, RatingButtons, StudySummary…
│   │   │   ├── lib/
│   │   │   │   ├── api.ts            # Axios + refresh queue
│   │   │   │   └── auth-api.ts       # Chamadas REST tipadas
│   │   │   ├── hooks/                # use-dashboard, use-deck, use-study…
│   │   │   └── stores/auth-store.ts  # Zustand (JWT)
│   │   ├── next.config.mjs           # Headers/CSP (prod)
│   │   └── package.json
│   │
│   ├── api/                          # Django + Ninja
│   │   ├── config/
│   │   │   ├── settings/
│   │   │   │   ├── base.py
│   │   │   │   ├── dev.py
│   │   │   │   └── prod.py
│   │   │   ├── urls.py
│   │   │   └── wsgi.py
│   │   ├── apps/
│   │   │   ├── users/
│   │   │   │   ├── models.py
│   │   │   │   ├── schemas.py        # Ninja schemas (request/response)
│   │   │   │   ├── api.py            # Ninja router
│   │   │   │   ├── services.py
│   │   │   │   └── tests/
│   │   │   ├── decks/
│   │   │   │   ├── models.py
│   │   │   │   ├── schemas.py
│   │   │   │   ├── api.py
│   │   │   │   ├── services.py
│   │   │   │   └── tests/
│   │   │   ├── reviews/
│   │   │   │   ├── models.py
│   │   │   │   ├── schemas.py
│   │   │   │   ├── api.py
│   │   │   │   ├── services/
│   │   │   │   │   └── sm2.py        # Algoritmo SM-2 puro
│   │   │   │   └── tests/
│   │   │   │       └── test_sm2.py   # Testes unitários do SM-2
│   │   │   ├── microlearning/
│   │   │   │   ├── models.py
│   │   │   │   ├── schemas.py
│   │   │   │   ├── api.py
│   │   │   │   └── tests/
│   │   │   └── jobs/
│   │   │       ├── models.py         # AsyncJob
│   │   │       ├── schemas.py
│   │   │       └── api.py
│   │   ├── core/
│   │   │   ├── middleware/
│   │   │   │   ├── logging.py        # Request/response logging
│   │   │   │   └── timing.py         # Latência por endpoint
│   │   │   ├── cache.py              # Redis helpers
│   │   │   └── health.py             # Health check endpoint
│   │   ├── manage.py
│   │   ├── requirements/
│   │   │   ├── base.txt
│   │   │   ├── dev.txt
│   │   │   └── prod.txt
│   │   ├── Dockerfile
│   │   └── pytest.ini
│   │
│   ├── mobile/                       # Flutter
│   │   ├── lib/
│   │   │   ├── app.dart              # go_router + bottom tabs
│   │   │   ├── core/
│   │   │   │   ├── connectivity_service.dart
│   │   │   │   ├── secure_storage.dart
│   │   │   │   └── sync_pull_reminder.dart
│   │   │   ├── data/
│   │   │   │   ├── api/              # Dio client + endpoints
│   │   │   │   ├── db/               # Drift database.dart + database.g.dart
│   │   │   │   └── repositories.dart # Auth/Deck/Card/Lesson/Review/Sync repos
│   │   │   ├── domain/
│   │   │   │   └── models.dart       # DTOs da API
│   │   │   ├── services/
│   │   │   │   └── sync_service.dart # push/pull + pending operations
│   │   │   ├── features/
│   │   │   │   ├── auth/             # login, cadastro, verificação de email
│   │   │   │   ├── dashboard/        # home + métricas locais/remotas
│   │   │   │   ├── decks/            # lista, detalhe, cards, micro-lições
│   │   │   │   ├── review/           # aba de revisões
│   │   │   │   └── study/            # sessão SM-2 + resumo final
│   │   │   └── main.dart
│   │   ├── test/
│   │   │   ├── sm2_test.dart
│   │   │   ├── repositories_sync_test.dart
│   │   │   └── widget_test.dart
│   │   ├── pubspec.yaml
│   │   └── analysis_options.yaml
│   │
│   └── workers/                      # Temporal workers
│       ├── workflows/
│       │   └── generate_cards.py     # cards + micro-lições via IA
│       ├── activities/
│       │   ├── groq.py               # cards + micro-lições via Groq
│       │   └── db.py                 # persiste cards, lições e jobs
│       ├── worker.py                 # Entry point do worker
│       ├── requirements.txt
│       └── Dockerfile
│
├── infra/
│   ├── docker-compose.yml            # Dev environment
│   ├── docker-compose.prod.yml       # Production overrides
│   └── nginx/
│       └── nginx.conf                # Reverse proxy config
│
├── .github/
│   └── workflows/
│       ├── ci.yml                    # Lint + test on PR
│       └── deploy.yml                # Deploy on merge to main
│
├── .env.example
├── .gitignore
├── README.md
├── PRD.md
└── TechSpecs.md
```

---

## 3. Backend — Detalhamento

### 3.1 Django Settings (base.py)

```python
# Configurações críticas

INSTALLED_APPS = [
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "corsheaders",
    "apps.users",
    "apps.decks",
    "apps.reviews",
    "apps.microlearning",
    "apps.jobs",
]

# Ninja API
NINJA_DOCS_URL = "/api/docs"

# JWT
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=15),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
}

# Cache
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": os.environ["REDIS_URL"],
    }
}

# CORS
CORS_ALLOWED_ORIGINS = os.environ.get("CORS_ORIGINS", "").split(",")

# Security Headers
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"
CSRF_COOKIE_HTTPONLY = True

# Sentry
import sentry_sdk
sentry_sdk.init(
    dsn=os.environ.get("SENTRY_DSN"),
    traces_sample_rate=0.1,
    profiles_sample_rate=0.1,
)

# Logging
LOGGING = {
    "version": 1,
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "json",
        },
    },
    "formatters": {
        "json": {
            "()": "structlog.stdlib.ProcessorFormatter",
            "processor": structlog.dev.ConsoleRenderer(),
        },
    },
    "root": {"handlers": ["console"], "level": "INFO"},
}
```

### 3.2 Modelos Django

```python
# apps/users/models.py
import uuid
from django.contrib.auth.models import AbstractUser
from django.db import models

class User(AbstractUser):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True)
    name = models.CharField(max_length=150)
    
    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["name"]

class UserProgress(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="progress")
    current_streak = models.IntegerField(default=0)
    longest_streak = models.IntegerField(default=0)
    last_review_date = models.DateField(null=True, blank=True)
    total_reviews = models.IntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)
```

```python
# apps/decks/models.py
class Deck(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey("users.User", on_delete=models.CASCADE, related_name="decks")
    title = models.CharField(max_length=100)
    description = models.TextField(max_length=500, blank=True, default="")
    color = models.CharField(max_length=7, default="#6366F1")
    is_public = models.BooleanField(default=False)
    is_archived = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]
        indexes = [
            models.Index(fields=["user", "is_archived"]),
        ]

class Card(models.Model):
    class Source(models.TextChoices):
        MANUAL = "manual"
        AI = "ai"
        IMPORT = "import"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    deck = models.ForeignKey(Deck, on_delete=models.CASCADE, related_name="cards")
    front = models.TextField()
    back = models.TextField()
    tags = models.JSONField(default=list, blank=True)
    source = models.CharField(max_length=10, choices=Source.choices, default=Source.MANUAL)
    
    # SM-2 fields
    ease_factor = models.FloatField(default=2.5)
    interval = models.IntegerField(default=0)
    repetitions = models.IntegerField(default=0)
    next_review = models.DateField(auto_now_add=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["deck", "next_review"]),
        ]
```

```python
# apps/reviews/models.py
class Review(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    card = models.ForeignKey("decks.Card", on_delete=models.CASCADE, related_name="reviews")
    user = models.ForeignKey("users.User", on_delete=models.CASCADE, related_name="reviews")
    quality = models.IntegerField()  # 0-5
    time_spent_ms = models.IntegerField(default=0)
    reviewed_at = models.DateTimeField(auto_now_add=True)
    synced = models.BooleanField(default=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "reviewed_at"]),
            models.Index(fields=["card", "reviewed_at"]),
        ]
```

### 3.3 Algoritmo SM-2

```python
# apps/reviews/services/sm2.py
from dataclasses import dataclass
from datetime import date, timedelta

@dataclass
class SM2Result:
    ease_factor: float
    interval: int
    repetitions: int
    next_review: date

def calculate_sm2(
    quality: int,
    ease_factor: float = 2.5,
    interval: int = 0,
    repetitions: int = 0,
) -> SM2Result:
    """
    Implementação do algoritmo SM-2 (SuperMemo 2).
    
    Args:
        quality: Auto-avaliação do usuário (0-5)
            0 = Blackout total
            1 = Errou muito
            2 = Errou
            3 = Difícil mas acertou
            4 = Bom
            5 = Fácil
        ease_factor: Fator de facilidade atual (mín 1.3)
        interval: Intervalo atual em dias
        repetitions: Número de acertos consecutivos
    
    Returns:
        SM2Result com novos valores calculados
    """
    assert 0 <= quality <= 5, "Quality must be between 0 and 5"
    
    # Recalcula ease factor
    new_ef = ease_factor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
    new_ef = max(1.3, new_ef)
    
    if quality < 3:
        # Resposta incorreta: reseta progresso
        new_repetitions = 0
        new_interval = 1
    else:
        # Resposta correta
        new_repetitions = repetitions + 1
        if repetitions == 0:
            new_interval = 1
        elif repetitions == 1:
            new_interval = 6
        else:
            new_interval = round(interval * new_ef)
    
    return SM2Result(
        ease_factor=round(new_ef, 4),
        interval=new_interval,
        repetitions=new_repetitions,
        next_review=date.today() + timedelta(days=new_interval),
    )
```

### 3.4 API Endpoints (Django Ninja)

```python
# apps/decks/api.py
from ninja import Router, Schema
from ninja.security import HttpBearer

router = Router(tags=["Decks"])

class DeckIn(Schema):
    title: str
    description: str = ""
    color: str = "#6366F1"
    is_public: bool = False

class DeckOut(Schema):
    id: uuid.UUID
    title: str
    description: str
    color: str
    is_public: bool
    card_count: int = 0
    due_count: int = 0
    created_at: datetime
    updated_at: datetime

@router.get("/", response=list[DeckOut])
def list_decks(request):
    decks = Deck.objects.filter(
        user=request.auth, is_archived=False
    ).annotate(
        card_count=Count("cards"),
        due_count=Count("cards", filter=Q(cards__next_review__lte=date.today()))
    )
    return decks

@router.post("/", response={201: DeckOut})
def create_deck(request, payload: DeckIn):
    deck = Deck.objects.create(user=request.auth, **payload.dict())
    return 201, deck

@router.post("/{deck_id}/generate", response={202: JobOut})
def generate_ai_cards(request, deck_id: uuid.UUID, payload: GenerateIn):
    """Dispara workflow Temporal para gerar cards com IA."""
    deck = get_object_or_404(Deck, id=deck_id, user=request.auth)
    
    job = AsyncJob.objects.create(
        user=request.auth,
        type="ai_generation",
        input_data={"deck_id": str(deck_id), "topic": payload.topic, "count": payload.count}
    )
    
    # Dispara workflow Temporal (fire-and-forget)
    trigger_generate_workflow.delay(str(job.id))
    
    return 202, job
```

### 3.5 Cache Strategy

```python
# apps/core/cache.py
from django.core.cache import cache
from functools import wraps

CACHE_KEYS = {
    "due_cards": "due:{user_id}:{date}",        # TTL: 5min
    "dashboard": "dashboard:{user_id}",          # TTL: 10min
    "deck_stats": "deck_stats:{deck_id}",        # TTL: 5min
}

def invalidate_review_cache(user_id: str):
    """Invalida caches ao submeter review."""
    today = date.today().isoformat()
    cache.delete(CACHE_KEYS["due_cards"].format(user_id=user_id, date=today))
    cache.delete(CACHE_KEYS["dashboard"].format(user_id=user_id))

def cached_due_cards(user_id: str):
    """Cards para revisar hoje, cacheados por 5 minutos."""
    key = CACHE_KEYS["due_cards"].format(user_id=user_id, date=date.today())
    result = cache.get(key)
    if result is not None:
        return result
    
    cards = Card.objects.filter(
        deck__user_id=user_id,
        deck__is_archived=False,
        next_review__lte=date.today()
    ).select_related("deck").order_by("ease_factor")
    
    result = list(cards)
    cache.set(key, result, timeout=300)
    return result
```

### 3.6 Rate Limiting

```python
# apps/users/api.py
from django_ratelimit.decorators import ratelimit

@router.post("/auth/login")
@ratelimit(key="ip", rate="5/m", method="POST", block=True)
def login(request, payload: LoginIn):
    ...

@router.post("/auth/register")
@ratelimit(key="ip", rate="3/m", method="POST", block=True)
def register(request, payload: RegisterIn):
    ...

@router.post("/{deck_id}/generate")
@ratelimit(key="user", rate="10/h", method="POST", block=True)
def generate_ai_cards(request, deck_id: uuid.UUID, payload: GenerateIn):
    ...
```

### 3.7 Health Check

```python
# apps/core/health.py
from ninja import Router
from django.db import connection
from django.core.cache import cache

router = Router(tags=["Health"])

@router.get("/health/")
def health_check(request):
    status = {"status": "ok", "checks": {}}
    
    # Database
    try:
        connection.ensure_connection()
        status["checks"]["database"] = "ok"
    except Exception as e:
        status["checks"]["database"] = f"error: {e}"
        status["status"] = "degraded"
    
    # Redis
    try:
        cache.set("health_check", "ok", timeout=5)
        assert cache.get("health_check") == "ok"
        status["checks"]["redis"] = "ok"
    except Exception as e:
        status["checks"]["redis"] = f"error: {e}"
        status["status"] = "degraded"
    
    return status
```

---

## 4. Temporal — Workflows Assíncronos

### 4.1 Decisão: Por que Temporal e não Celery?

| Critério | Celery | Temporal |
|----------|--------|----------|
| Retry com backoff | Config manual | Nativo por activity |
| Visibilidade de execução | Flower (limitado) | UI completa built-in |
| Workflows compostos | Chains/Chords (frágil) | Workflow classes (robusto) |
| Durabilidade | Broker-dependent | Persiste estado automaticamente |
| Agendamento | Celery Beat | Cron schedules nativos |
| Complexidade de setup | Menor | Maior (compensa em produção) |

**Conclusão:** Temporal é mais robusto para workflows multi-step com retry e monitoramento. O custo de setup adicional é compensado pela confiabilidade.

### 4.2 Workflow: Geração de Cards e Micro-lições com IA

```python
# apps/workers/workflows/generate_cards.py
from temporalio import workflow, activity
from dataclasses import dataclass
from datetime import timedelta

@dataclass
class GenerateCardsInput:
    job_id: str
    deck_id: str
    topic: str
    count: int
    user_id: str

@workflow.defn
class GenerateCardsWorkflow:
    @workflow.run
    async def run(self, input: GenerateCardsInput) -> dict:
        # Step 1: Atualiza status para "running"
        await workflow.execute_activity(
            update_job_status,
            args=[input.job_id, "running"],
            start_to_close_timeout=timedelta(seconds=10),
        )
        
        # Step 2: Gera cards via Groq/Llama
        cards_json = await workflow.execute_activity(
            generate_cards_with_ai,
            args=[input.topic, input.count],
            start_to_close_timeout=timedelta(minutes=2),
            retry_policy=RetryPolicy(
                initial_interval=timedelta(seconds=5),
                maximum_attempts=3,
                backoff_coefficient=2.0,
            ),
        )
        
        # Step 3: Salva cards no banco
        saved_count = await workflow.execute_activity(
            save_cards_to_deck,
            args=[input.deck_id, cards_json],
            start_to_close_timeout=timedelta(seconds=30),
        )
        
        # Step 4: Gera 2 micro-lições complementares (best-effort)
        try:
            lesson_data = await workflow.execute_activity(
                generate_lesson_content,
                args=[input],
                start_to_close_timeout=timedelta(minutes=2),
            )
            await workflow.execute_activity(
                persist_generated_lesson,
                args=[input.deck_id, lesson_data],
                start_to_close_timeout=timedelta(seconds=30),
            )
        except Exception:
            pass

        # Step 5: Atualiza job como concluído
        await workflow.execute_activity(
            update_job_status,
            args=[input.job_id, "completed", {"cards_created": saved_count}],
            start_to_close_timeout=timedelta(seconds=10),
        )

        return {"cards_created": saved_count}
```

### 4.3 Activity: Chamada à Groq API

```python
# apps/workers/activities/ai_generate.py
import httpx
import json
from temporalio import activity

GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"

@activity.defn
async def generate_cards_with_ai(topic: str, count: int) -> list[dict]:
    """Chama Groq Cloud (Llama 3.3 70B) para gerar flashcards."""
    
    prompt = f"""Gere exatamente {count} flashcards sobre o tema: "{topic}".

Cada flashcard deve ter:
- "front": uma pergunta clara, direta e objetiva
- "back": uma resposta concisa mas completa (máx 2-3 frases)

Regras:
- Cubra diferentes aspectos do tema
- Varie entre perguntas conceituais, práticas e de comparação
- Use linguagem acessível para estudantes universitários
- Retorne APENAS um JSON array válido, sem explicações

Exemplo de formato:
[
  {{"front": "O que é fotossíntese?", "back": "Processo pelo qual organismos convertem luz solar em energia química, usando CO2 e H2O para produzir glicose e O2."}},
  {{"front": "Onde ocorre a fase clara da fotossíntese?", "back": "Nos tilacoides dos cloroplastos, onde a luz é absorvida pela clorofila."}}
]"""

    async with httpx.AsyncClient(timeout=60.0) as client:
        response = await client.post(
            GROQ_API_URL,
            headers={
                "Authorization": f"Bearer {os.environ['GROQ_API_KEY']}",
                "Content-Type": "application/json",
            },
            json={
                "model": "llama-3.3-70b-versatile",
                "messages": [
                    {"role": "system", "content": "Você é um especialista em educação. Gere flashcards de alta qualidade. Responda APENAS com JSON válido."},
                    {"role": "user", "content": prompt},
                ],
                "temperature": 0.7,
                "max_tokens": 4096,
                "response_format": {"type": "json_object"},
            },
        )
        response.raise_for_status()
    
    content = response.json()["choices"][0]["message"]["content"]
    cards = json.loads(content)
    
    # Normaliza: aceita tanto array direto quanto {cards: [...]}
    if isinstance(cards, dict) and "cards" in cards:
        cards = cards["cards"]
    
    # Validação básica
    validated = []
    for card in cards[:count]:
        if "front" in card and "back" in card:
            validated.append({
                "front": card["front"].strip(),
                "back": card["back"].strip(),
            })
    
    if len(validated) < 1:
        raise ValueError(f"IA retornou 0 cards válidos para o tema: {topic}")
    
    return validated
```

### 4.4 Activity: Geração de Micro-lições

O worker usa a mesma integração Groq para gerar conteúdo estruturado de microlearning.
Cada execução de IA tenta criar **2 micro-lições complementares**, cada uma com 5 blocos:

1. `text`
2. `highlight`
3. `text`
4. `quiz`
5. `quiz`

Formato esperado:

```json
{
  "lessons": [
    {
      "title": "Título curto 1",
      "estimated_minutes": 5,
      "blocks": [
        { "type": "text", "order": 0, "content": { "body": "..." } },
        { "type": "highlight", "order": 1, "content": { "body": "...", "color": "yellow" } },
        { "type": "text", "order": 2, "content": { "body": "..." } },
        { "type": "quiz", "order": 3, "content": { "question": "...", "options": ["A", "B", "C", "D"], "correct": 0, "explanation": "..." } },
        { "type": "quiz", "order": 4, "content": { "question": "...", "options": ["A", "B", "C", "D"], "correct": 1, "explanation": "..." } }
      ]
    }
  ]
}
```

Persistência:

- `MicroLesson` recebe `deck`, `title`, `order`, `estimated_minutes`
- `ContentBlock` recebe `lesson`, `type`, `order`, `content`
- limite atual: até 3 micro-lições por deck
- títulos duplicados no mesmo deck são ignorados
- falha na geração/persistência das lições não cancela os cards gerados
### 4.5 Workflow: Lembrete Diário

```python
# apps/workers/workflows/daily_reminder.py
@workflow.defn
class DailyReminderWorkflow:
    """Roda continuamente. A cada 24h verifica cards pendentes e envia lembrete."""
    
    @workflow.run
    async def run(self, user_id: str):
        while True:
            due_count = await workflow.execute_activity(
                get_due_cards_count,
                args=[user_id],
                start_to_close_timeout=timedelta(seconds=15),
            )
            
            if due_count > 0:
                await workflow.execute_activity(
                    send_reminder_email,
                    args=[user_id, due_count],
                    start_to_close_timeout=timedelta(seconds=30),
                )
            
            # Dorme 24h
            await workflow.sleep(timedelta(hours=24))
```

---

## 5. Frontend Web — Detalhamento

### 5.1 Rotas e páginas (App Router)

Implementação atual (grupos de rotas):

| Caminho | Conteúdo |
|---------|-----------|
| `/` | Landing `(marketing)/page.tsx` |
| `/login`, `/register`, `/verify-email` | `(auth)/*` |
| `/dashboard`, `/decks`, `/decks/[id]`, `/review`, `/ai` | `(app)/*` protegido por `AuthGuard` |

**Modo estudo:** `/review` sem query lista decks com due ou bloqueados; com `?deck_id=` abre sessão usando `useStudy` + `FlipCard` + `RatingButtons` + `StudySummary`.

### 5.2 State Management

```
Zustand (stores/auth-store.ts)  → tokens, user, persistência de sessão
TanStack Query                  → dashboard, decks, cards, due-cards, jobs, lessons
```

**Por que Zustand + TanStack Query (não Redux)?**
- Zustand: ~1KB, zero boilerplate, perfeito para auth state
- TanStack Query: cache automático, revalidação, loading/error states, dedupe de requests
- Separação clara: client state (Zustand) vs server state (TanStack Query)

### 5.3 API Client (`src/lib/api.ts`)

- `axios.create` com `baseURL: NEXT_PUBLIC_API_URL`, timeout ~15s.
- Request interceptor: lê `accessToken` de `@/stores/auth-store` e define `Authorization`.
- Response interceptor: em **401**, fila anti-stampede para **refresh** (`POST .../auth/refresh` com `refresh_token`), atualiza tokens via store e repete request; falha → logout e redirect `/login`.
- Endpoints tipados em `auth-api.ts` (TanStack Query chama essas funções).

### 5.4 Modo estudo — componentes reais

| Arquivo | Papel |
|---------|--------|
| `components/study/flip-card.tsx` | Flip 3D (`framer-motion`); frente/verso como **texto** (`<p>`), sem Markdown |
| `components/study/rating-buttons.tsx` | Notas 0–5 após revelar |
| `components/study/study-summary.tsx` | Resumo pós-sessão; **Nova sessão** + link **Outros decks** → `/review` |
| `hooks/use-study.ts` | `fetchDueCards` + `submitReview` + estado da sessão |

**Markdown (`react-markdown`):** usado em micro-lições (`components/microlearning/block-text.tsx`), não no flip de revisão.

### 5.5 SEO

- **Metadata** principal em `src/app/layout.tsx` (`metadata`, `metadataBase` com `NEXT_PUBLIC_APP_URL`).
- **`robots.ts`** e **`sitemap.ts`** na raiz de `app/` para crawling.

### 5.6 Security headers (`next.config.mjs`)

- Headers base: `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`.
- Em **produção**: `Strict-Transport-Security` + **CSP** dinâmico com `connect-src` incluindo a origem da API (`NEXT_PUBLIC_API_URL`), para não bloquear o Axios.
- Em **dev**, CSP/HSTS omitidos para não quebrar HMR/devtools.

---

## 6. Mobile Flutter — Detalhamento

### 6.1 Drift Database Schema

```dart
// apps/mobile/lib/data/db/database.dart
import 'package:drift/drift.dart';

class Decks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get color => text().withDefault(const Constant('#6366F1'))();
  IntColumn get cardCount => integer().withDefault(const Constant(0))();
  IntColumn get dueCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Cards extends Table {
  TextColumn get id => text()();
  TextColumn get deckId => text().references(Decks, #id)();
  TextColumn get front => text()();
  TextColumn get back => text()();
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextReview => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class PendingReviews extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get cardId => text()();
  IntColumn get quality => integer()();
  IntColumn get timeSpentMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

class Lessons extends Table {
  TextColumn get id => text()();
  TextColumn get deckId => text().references(Decks, #id)();
  TextColumn get title => text()();
  IntColumn get order => integer().withDefault(const Constant(0))();
  IntColumn get estimatedMinutes => integer().withDefault(const Constant(5))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class ContentBlocks extends Table {
  TextColumn get id => text()();
  TextColumn get lessonId => text().references(Lessons, #id)();
  TextColumn get type => text()();
  IntColumn get order => integer().withDefault(const Constant(0))();
  TextColumn get contentJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class PendingOperations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
}
```

Schema version atual: `4`.

Tabelas locais:

- `users`: sessão/perfil básico do usuário autenticado
- `decks`: snapshot local dos decks e contadores
- `cards`: cards com campos SM-2 usados offline
- `pending_reviews`: fila de reviews feitas localmente
- `lessons`: micro-lições persistidas para leitura offline
- `content_blocks`: blocos das micro-lições em JSON
- `pending_operations`: fila genérica de mutações locais

Tipos de `pending_operations`:

| Tipo | Uso |
|------|-----|
| `deck.create` | deck criado offline |
| `deck.update` | deck editado offline |
| `deck.archive` | deck arquivado offline |
| `card.create` | card manual criado offline |
| `card.update` | card editado offline |
| `card.delete` | card excluído offline |
| `lesson.complete` | micro-lição concluída offline |

### 6.2 Sync Service e Offline-first

O mobile segue o padrão **local-first para leitura** e **optimistic write para mutações syncáveis**.

Fluxo principal:

1. UI observa streams do Drift (`watchDecks`, `watchCardsForDeck`, `watchLessonsForDeck`)
2. Repositórios disparam pulls em background quando há rede
3. Mutação tenta backend primeiro
4. Se falhar por rede/timeout/5xx, o app atualiza o Drift local e cria `pending_operations`
5. `SyncService.syncAll()` envia `pending_operations`, depois `pending_reviews`, e então faz pull do backend

```dart
class SyncService {
  Future<void> syncAll() async {
    if (_running) return;
    _running = true;
    try {
      await push();
      await pull();
    } finally {
      _running = false;
    }
  }

  Future<int> push() async {
    final ops = await operationSyncRepo.flushPending();
    final reviews = await reviewRepo.flushPending();
    return ops + reviews;
  }

  Future<void> pull() async {
    await deckRepo.pullDecks();
    final decks = await deckRepo.allDecks();
    for (final deck in decks) {
      await cardRepo.pullCardsForDeck(deck.id);
      await lessonRepo.list(deck.id);
    }
  }
}
```

Operações offline validadas:

- listar decks/cards já sincronizados
- abrir micro-lições já sincronizadas
- revisar cards com SM-2 local
- adicionar card manualmente
- editar/excluir cards
- editar/arquivar decks
- concluir micro-lições
- sincronizar pendências ao voltar a rede

Observação de consistência:

- Para a home mobile, `dueToday` vem do Drift local, não do backend, para evitar que uma resposta remota atrasada volte a mostrar cards já revisados no aparelho.
- Ao sincronizar `card.create`, IDs locais (`local-card-*`) são substituídos pelo ID remoto e referências pendentes em reviews/operações são reescritas.

### 6.3 Providers/Repositórios Mobile

```dart
final deckRepoProvider = Provider<DeckRepository>((ref) {
  return DeckRepository(deckApi, jobApi, database);
});

final cardRepoProvider = Provider<CardRepository>((ref) {
  return CardRepository(deckApi, database);
});

final lessonRepoProvider = Provider<LessonRepository>((ref) {
  return LessonRepository(lessonApi, database);
});

final reviewRepoProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(reviewApi, database);
});

final operationSyncRepoProvider = Provider<OperationSyncRepository>((ref) {
  return OperationSyncRepository(deckApi, lessonApi, database);
});
```

Responsabilidades:

- `DeckRepository`: pull/lista/criação/edição/arquivamento de decks
- `CardRepository`: leitura local, pull, CRUD de cards e fila offline
- `LessonRepository`: lista/detalhe/conclusão de micro-lições com cache Drift
- `ReviewRepository`: aplica SM-2 local e enfileira `pending_reviews`
- `OperationSyncRepository`: envia mutações locais pendentes

### 6.4 SM-2 Local (Dart)

```dart
// apps/mobile/lib/data/repositories.dart
class Sm2Result {
  Sm2Result(
    this.easeFactor,
    this.intervalDays,
    this.repetitions,
    this.nextReview,
  );

  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime nextReview;
}
```

Mapeamento da UI mobile:

| Botão | Quality |
|-------|---------|
| De novo | 0 |
| Difícil | 3 |
| Bom | 4 |
| Fácil | 5 |

Ao finalizar uma sessão, o mobile exibe:

- total revisado
- acertos
- erros
- precisão
- tempo total
- tempo médio por card

```dart
Future<CardRow> gradeOffline({
  required CardRow card,
  required int quality,
  required int timeSpentMs,
}) async {
  final next = applySm2(...);
  await db.updateCardSm2(...);
  await db.refreshDueCountForDeck(card.deckId);
  await db.enqueueReview(...);
  return updatedCard;
}
```

### 6.5 SM-2 Local (Dart) — Fórmula

```dart
// Implementação simplificada da fórmula usada no app
Sm2Result applySm2({
  required double easeFactor,
  required int intervalDays,
  required int repetitions,
  required int quality,
}) {
  int reps = repetitions;
  int interval = intervalDays;
  double ef = easeFactor;

  if (quality < 3) {
    reps = 0;
    interval = 1;
  } else {
    if (reps == 0) {
      interval = 1;
    } else if (reps == 1) {
      interval = 6;
    } else {
      interval = (interval * ef).round();
    }
    reps = reps + 1;
  }

  ef = ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  if (ef < 1.3) ef = 1.3;

  return Sm2Result(ef, interval, reps, nextReview);
}
```

---

## 7. Infraestrutura

### 7.1 Docker Compose (Desenvolvimento)

```yaml
# docker-compose.yml
version: "3.9"

services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: flashmind
      POSTGRES_USER: flash
      POSTGRES_PASSWORD: secret
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U flash -d flashmind"]
      interval: 5s
      timeout: 3s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s

  api:
    build:
      context: ./apps/api
      dockerfile: Dockerfile
    command: python manage.py runserver 0.0.0.0:8000
    volumes:
      - ./apps/api:/app
    ports:
      - "8000:8000"
    env_file: .env
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy

  web:
    build:
      context: ./apps/web
      dockerfile: Dockerfile
    command: npm run dev
    volumes:
      - ./apps/web:/app
      - /app/node_modules
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1

  temporal:
    image: temporalio/auto-setup:latest
    ports:
      - "7233:7233"
    environment:
      - DB=postgresql
      - DB_PORT=5432
      - POSTGRES_USER=flash
      - POSTGRES_PWD=secret
      - POSTGRES_SEEDS=db
    depends_on:
      db:
        condition: service_healthy

  temporal-ui:
    image: temporalio/ui:latest
    ports:
      - "8080:8080"
    environment:
      - TEMPORAL_ADDRESS=temporal:7233

  worker:
    build:
      context: ./apps/workers
      dockerfile: Dockerfile
    command: python worker.py
    volumes:
      - ./apps/workers:/app
    env_file: .env
    depends_on:
      - temporal
      - api

volumes:
  pgdata:
```

### 7.2 Dockerfile Backend

```dockerfile
# apps/api/Dockerfile
FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libpq-dev && rm -rf /var/lib/apt/lists/*

COPY requirements/base.txt requirements/prod.txt ./requirements/
RUN pip install --no-cache-dir -r requirements/prod.txt

COPY . .

RUN python manage.py collectstatic --noinput 2>/dev/null || true

EXPOSE 8000

CMD ["gunicorn", "config.wsgi:application", \
     "--bind", "0.0.0.0:8000", \
     "--workers", "4", \
     "--timeout", "120"]
```

### 7.3 CI/CD — GitHub Actions

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test-api:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: flashmind_test
          POSTGRES_USER: flash
          POSTGRES_PASSWORD: secret
        ports: ["5432:5432"]
        options: --health-cmd pg_isready --health-interval 10s
      redis:
        image: redis:7-alpine
        ports: ["6379:6379"]
    
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
      
      - name: Install dependencies
        run: |
          cd apps/api
          pip install -r requirements/dev.txt
      
      - name: Lint
        run: |
          cd apps/api
          ruff check .
      
      - name: Run tests
        env:
          DATABASE_URL: postgres://flash:secret@localhost:5432/flashmind_test
          REDIS_URL: redis://localhost:6379/0
          DJANGO_SETTINGS_MODULE: config.settings.test
        run: |
          cd apps/api
          pytest --cov=apps --cov-report=xml -v
      
      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          file: apps/api/coverage.xml

  test-web:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
          cache-dependency-path: apps/web/package-lock.json
      
      - name: Install & Test
        run: |
          cd apps/web
          npm ci
          npm run lint
          npm run type-check
          npm test -- --passWithNoTests
      
      - name: Build
        run: |
          cd apps/web
          npm run build

  # CD opcional — exemplos; alinhar secrets ao provedor final (Render vs Railway, etc.).
  deploy:
    needs: [test-api, test-web]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # Provável: deploy da API via Render (deploy hook, CLI ou imagem no GHCR) — blueprint TBD.
      # Alternativa histórica no doc: Railway com railway-deploy action.
      - name: Deploy API (placeholder — configurar Render ou outro host)
        run: echo "Definir action/service de deploy da API (ex. Render)."
      
      - name: Deploy Web to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          working-directory: apps/web
```

---

## 8. Observabilidade

### 8.1 Logging Estruturado

```python
# Configuração structlog
import structlog

structlog.configure(
    processors=[
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.JSONRenderer(),  # JSON em produção
    ],
)

logger = structlog.get_logger()

# Uso nos services:
logger.info("review.submitted", 
    user_id=str(user.id), 
    card_id=str(card.id), 
    quality=quality,
    ease_factor=result.ease_factor,
    next_review=str(result.next_review),
)

logger.info("ai.generation.started",
    job_id=str(job.id),
    topic=topic,
    count=count,
)
```

### 8.2 Middleware de Latência

```python
# apps/core/middleware/timing.py
import time
import structlog

logger = structlog.get_logger()

class RequestTimingMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        start = time.perf_counter()
        response = self.get_response(request)
        duration_ms = (time.perf_counter() - start) * 1000
        
        logger.info("http.request",
            method=request.method,
            path=request.path,
            status=response.status_code,
            duration_ms=round(duration_ms, 2),
            user_id=str(getattr(request, 'auth', {}).get('id', 'anonymous')),
        )
        
        response["X-Response-Time"] = f"{duration_ms:.2f}ms"
        return response
```

### 8.3 Sentry — Frontend

```typescript
// src/lib/sentry.ts (Next.js)
import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  tracesSampleRate: 0.1,
  environment: process.env.NODE_ENV,
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration({ maskAllText: false }),
  ],
  replaysSessionSampleRate: 0.05,
  replaysOnErrorSampleRate: 1.0,
});
```

---

## 9. Testes

### 9.1 Estratégia

| Tipo | Ferramenta | Escopo | Cobertura alvo |
|------|------------|--------|----------------|
| Unitário (Backend) | pytest | SM-2, services, utils | 90%+ no SM-2 |
| Integração (Backend) | pytest-django | Endpoints, DB queries | Todos os endpoints |
| Unitário (Frontend) | Vitest | Hooks, utils | Hooks críticos |
| E2E (Frontend) | Playwright (futuro) | Fluxos principais | Login → Review |
| Unitário (Mobile) | flutter_test | SM-2, repositories, sync, smoke widget | SM-2 + Sync |

### 9.2 Testes do SM-2

```python
# apps/reviews/tests/test_sm2.py
import pytest
from datetime import date, timedelta
from apps.reviews.services.sm2 import calculate_sm2

class TestSM2Algorithm:
    def test_first_correct_review(self):
        """Primeiro acerto: interval deve ser 1 dia."""
        result = calculate_sm2(quality=4)
        assert result.interval == 1
        assert result.repetitions == 1
        assert result.ease_factor == 2.5

    def test_second_correct_review(self):
        """Segundo acerto: interval deve ser 6 dias."""
        result = calculate_sm2(quality=4, repetitions=1, interval=1)
        assert result.interval == 6
        assert result.repetitions == 2

    def test_third_correct_review(self):
        """Terceiro acerto: interval = round(6 * EF)."""
        result = calculate_sm2(quality=4, repetitions=2, interval=6, ease_factor=2.5)
        assert result.interval == 15  # round(6 * 2.5)
        assert result.repetitions == 3

    def test_incorrect_resets_progress(self):
        """Resposta errada (quality < 3): reseta tudo."""
        result = calculate_sm2(quality=1, repetitions=5, interval=30, ease_factor=2.5)
        assert result.repetitions == 0
        assert result.interval == 1

    def test_ease_factor_minimum(self):
        """EF nunca fica abaixo de 1.3."""
        result = calculate_sm2(quality=0, ease_factor=1.3)
        assert result.ease_factor >= 1.3

    def test_perfect_score_increases_ef(self):
        """Quality 5 aumenta ease factor."""
        result = calculate_sm2(quality=5, ease_factor=2.5)
        assert result.ease_factor > 2.5

    def test_next_review_date(self):
        """next_review é hoje + interval dias."""
        result = calculate_sm2(quality=4)
        assert result.next_review == date.today() + timedelta(days=1)

    @pytest.mark.parametrize("quality", [0, 1, 2, 3, 4, 5])
    def test_all_quality_values(self, quality):
        """Todas as quality values produzem resultado válido."""
        result = calculate_sm2(quality=quality)
        assert result.interval >= 1
        assert result.ease_factor >= 1.3
        assert result.repetitions >= 0

    def test_invalid_quality_raises(self):
        """Quality fora de 0-5 lança exceção."""
        with pytest.raises(AssertionError):
            calculate_sm2(quality=6)
        with pytest.raises(AssertionError):
            calculate_sm2(quality=-1)
```

### 9.3 Testes Mobile Implementados

Arquivos:

- `apps/mobile/test/sm2_test.dart`
- `apps/mobile/test/repositories_sync_test.dart`
- `apps/mobile/test/widget_test.dart`

Cobertura atual:

- fórmula SM-2 local (`applySm2`)
- reset de repetição quando `quality < 3`
- agendamento de 1 dia para card novo correto
- agendamento de 6 dias na segunda repetição correta
- `ReviewRepository.gradeOffline`
- `ReviewRepository.flushPending`
- dashboard local-first mantendo `dueToday` do Drift quando backend está stale
- `CardRepository.createCard` com fallback offline e `pending_operations`
- `OperationSyncRepository` enviando `card.create`, substituindo ID local por remoto e reescrevendo referências em `pending_reviews`
- smoke test do shell Flutter

---

## 10. Variáveis de Ambiente

```bash
# .env.example

# Django
DJANGO_SETTINGS_MODULE=config.settings.dev
SECRET_KEY=change-me-in-production
DEBUG=true
ALLOWED_HOSTS=localhost,127.0.0.1

# Database
DATABASE_URL=postgres://flash:secret@localhost:5432/flashmind

# Redis
REDIS_URL=redis://localhost:6379/0

# JWT
JWT_ACCESS_TOKEN_LIFETIME_MINUTES=15
JWT_REFRESH_TOKEN_LIFETIME_DAYS=7

# CORS
CORS_ORIGINS=http://localhost:3000

# Groq (LLM)
GROQ_API_KEY=gsk_your_key_here

# Temporal
TEMPORAL_ADDRESS=localhost:7233
TEMPORAL_NAMESPACE=default
TEMPORAL_TASK_QUEUE=flashmind-queue

# Sentry
SENTRY_DSN=https://your-sentry-dsn

# Email (optional)
SMTP_HOST=smtp.resend.com
SMTP_PORT=587
SMTP_USER=resend
SMTP_PASSWORD=re_your_key
EMAIL_FROM=noreply@flashmind.app

# Frontend
NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1
NEXT_PUBLIC_SENTRY_DSN=https://your-frontend-sentry-dsn
```

---

## 11. Deploy — Plano de Produção

### 11.0 Direção provável (decisão ainda não finalizada)

**Tendência atual do projeto:**

| Alvo | Provável escolha | Observação |
|------|------------------|------------|
| Frontend web | **Vercel** | Next.js; env `NEXT_PUBLIC_API_URL` apontando para URL pública da API. |
| Backend (API + satélites) | **Render** | Serviço web Docker ou native runtime para Django; Postgres/Redis/worker/Temporal como serviços Render ou externos — **detalhar no blueprint antes do cutover**. |
| Mobile | **Simulator iOS / build local** | Sem pipeline para TestFlight/App Store neste momento; `flutter run` + `--dart-define=API_BASE_URL=…` contra localhost ou URL da API no Render. |

Railway, VPS única com Compose ou Temporal Cloud continuam alternativas documentadas em versões anteriores deste texto e no Docker local.

### 11.1 Infraestrutura (referência — ajustar após fechar provedor)

| Serviço | Plataforma (provável) | Tier | Custo estimado |
|---------|------------------------|------|----------------|
| Web (Next.js) | Vercel | Free / Pro conforme uso | $0– |
| API (Django) | Render | Free tier limitado ou pago | variável |
| PostgreSQL | Render (managed) ou Neon etc. | conforme plano | variável |
| Redis | Render ou Upstash | conforme plano | variável |
| Temporal + Worker | Render (Docker) ou Temporal Cloud + worker Render | conforme plano | variável |
| Sentry | Sentry.io | Free (limite eventos) | $0 |
| Groq | Groq Cloud | Free tier | $0 |
| **Total** | | | **depende do blueprint Render** |

### 11.2 Domínios (exemplo)

```
seudominio.app           → Vercel (landing + app web)
flashmind-api.onrender.com → Render (API Django), ou subdomínio próprio `api.seudominio.app` com CNAME
```

Temporal UI / filas: subdomínio ou host interno — definir quando o stack Render estiver fechado.

---

## 12. Decisões Técnicas Documentadas

### D1: Django Ninja vs Django REST Framework

**Escolha:** Django Ninja

**Motivo:** Sintaxe tipo FastAPI (type hints, Pydantic/Schema), auto-docs Swagger, performance superior ao DRF, curva de aprendizado mínima para quem conhece FastAPI. DRF tem mais plugins mas é over-engineering para este escopo.

### D2: Groq + Llama 3.3 vs OpenAI / Claude API

**Escolha:** Groq Cloud com Llama 3.3 70B

**Motivo:** Custo zero (tier gratuito), latência extremamente baixa (~500ms vs ~2-3s), qualidade suficiente para geração de flashcards em JSON, API compatível com formato OpenAI (troca de provider trivial), sem vendor lock-in.

### D3: Zustand + TanStack Query vs Redux Toolkit

**Escolha:** Zustand + TanStack Query

**Motivo:** Redux é overkill para este escopo. Zustand para client state (auth, UI) é ~1KB com zero boilerplate. TanStack Query para server state (decks, cards) fornece cache, revalidação, e loading states automaticamente. Separação clara de responsabilidades.

### D4: Temporal vs Celery

**Escolha:** Temporal

**Motivo:** O desafio pede explicitamente Temporal como bônus. Além disso, Temporal oferece durabilidade de workflows, UI de monitoramento built-in, retry nativo com backoff por activity, e é mais robusto para workflows multi-step do que Celery Chains/Chords.

### D5: Drift (Flutter) vs sqflite

**Escolha:** Drift

**Motivo:** Type-safe, reactive queries (streams), migrations automáticas, DAOs, menos boilerplate que sqflite puro. Excelente para offline-first onde queries complexas são necessárias (ex: cards com next_review <= hoje JOIN deck).

---

*Documento alinhado ao repositório (§5 frontend web = App Router real: rotas, `FlipCard`, API client, SEO em `layout.tsx`, `next.config.mjs`). Deploy: §11 (Vercel + Render provável).*
