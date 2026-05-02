# FlashMind

Plataforma de flashcards com SRS (SM-2), microlearning e geração de cards via
IA. Monorepo com 4 frentes:

| Pasta | O que é | Stack |
|---|---|---|
| `apps/api` | Backend HTTP | Django 4.2 + Ninja 1.3 + Postgres + Redis |
| `apps/web` | Frontend web | Next.js 14 + React 18 + Tailwind + React Query |
| `apps/mobile` | App móvel | Flutter 3.22 + Riverpod + Drift + Dio (offline-first) |
| `apps/workers` | Worker assíncrono | Temporal + Python 3.12 (gera cards via Groq/Llama 3.3) |

> Banco único de verdade: PostgreSQL. Web e mobile **nunca** acessam o
> Postgres direto — sempre via API. O worker usa o ORM do Django pra
> escrever resultado de jobs.

## Sumário

- [Setup local (5 min)](#setup-local-5-min)
- [Como cada app conversa entre si](#como-cada-app-conversa-entre-si)
- [Rodar testes](#rodar-testes)
- [Deploy de produção](#deploy-de-produção)
  - [Backend → Railway](#backend--railway)
  - [Frontend → Vercel](#frontend--vercel)
  - [Worker → Railway](#worker--railway)
  - [Temporal Cloud](#temporal-cloud)
  - [Mobile (build de release)](#mobile-build-de-release)
- [Lista completa de tokens / segredos](#lista-completa-de-tokens--segredos)
- [CI/CD](#cicd)
- [Troubleshooting](#troubleshooting)

---

## Setup local (5 min)

Pré-requisitos: Docker Desktop, Node 20+, Python 3.12+ (opcional, só pra rodar fora do Docker), Flutter 3.22+ (se for mexer no mobile).

```bash
# 1) Clonar e configurar variáveis
git clone <este repo>
cd flashmind
cp .env.example .env

# 2) Editar .env e colar uma chave da Groq (https://console.groq.com/keys)
#    GROQ_API_KEY=gsk_sua_chave_real

# 3) Subir tudo
docker compose up -d --build

# 4) Verificar
curl http://localhost:8000/api/v1/health/   # API
open http://localhost:3000                  # Web (Next.js)
open http://localhost:8080                  # Temporal UI
```

Serviços que sobem:

| Serviço | Porta | Container |
|---|---|---|
| Postgres 16 | 5432 | `flashmind-db` |
| Redis 7 | 6379 | `flashmind-redis` |
| Django API | 8000 | `flashmind-api` |
| Next.js Web | 3000 | `flashmind-web` |
| Temporal | 7233 | `flashmind-temporal` |
| Temporal UI | 8080 | `flashmind-temporal-ui` |
| Worker | — | `flashmind-worker` |

### Mobile

```bash
cd apps/mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Android Emulator (default):
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

# iOS Simulator:
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

Para dispositivo físico, descubra o IP da máquina (`ipconfig getifaddr en0` no
Mac) e use `http://<IP>:8000/api/v1`.

---

## Como cada app conversa entre si

```
┌──────────────────┐   HTTPS    ┌─────────────────┐
│ Web (Vercel)     │──────────▶ │                 │
└──────────────────┘            │                 │
                                │  Django API     │ ─ ORM ─▶ ┌──────────────┐
┌──────────────────┐   HTTPS    │  (Railway)      │          │ PostgreSQL   │
│ Mobile (Flutter) │──────────▶ │  /api/v1/*      │          │ (Railway)    │
└──────────────────┘            │                 │ ◀─ ORM ─ └──────────────┘
                                └────────┬────────┘                 ▲
                                         │ start_workflow           │
                                         ▼                          │
                              ┌─────────────────────┐               │
                              │ Temporal Cloud      │               │
                              │ (gRPC + mTLS)       │               │
                              └────────┬────────────┘               │
                                       │ task queue                  │
                                       ▼                             │
                              ┌─────────────────────┐                │
                              │ Worker (Railway)    │ ─ ORM ─────────┘
                              │ chama Groq Llama 3  │
                              └─────────────────────┘
```

---

## Rodar testes

### Backend — via Docker (recomendado, funciona em clone limpo)

Não precisa ter o stack todo no ar. Os únicos pré-requisitos são Docker Desktop e ter rodado `cp .env.example .env`.

```bash
# Roda a suíte completa (sobe db + redis automaticamente)
docker compose --profile test run --rm test-api

# Com cobertura de código
docker compose --profile test run --rm test-api \
  pytest -v --cov=apps --cov-report=term-missing

# Só um arquivo específico
docker compose --profile test run --rm test-api \
  pytest tests/integration/test_auth_flow.py -v
```

Na primeira execução, Docker vai fazer o build da imagem da API (alguns minutos). Nas subsequentes usa o cache — é rápido.

### Backend — com stack já no ar

Se você já tem `docker compose up -d` rodando:

```bash
docker compose exec api pytest -v
docker compose exec api pytest --cov=apps --cov-report=term-missing
```

### Frontend

```bash
cd apps/web && npm ci && npm run lint && npm run type-check && npm run build
```

### Mobile

```bash
cd apps/mobile && flutter analyze && flutter test
```

---

## Deploy de produção

> **Stack escolhida:** Vercel (web) + Railway (api+worker+postgres+redis)
> + Temporal Cloud (workflows). Custo inicial: **\$0/mês** (todos têm
> free tier suficiente pro MVP), escalando conforme uso.

### Backend → Railway

#### Passo a passo

1. **Criar projeto no Railway** (https://railway.app/new) → "Deploy from GitHub repo" → selecione este repo.

2. **Adicionar Postgres**: clique em `+ New` → `Database` → `PostgreSQL`. Railway cria a var `DATABASE_URL` automática.

3. **Adicionar Redis**: clique em `+ New` → `Database` → `Redis`. Cria `REDIS_URL`.

4. **Configurar serviço API**:
   - `+ New` → `GitHub Repo` → mesmo repo
   - **Settings → Service → Source** → `Root Directory`: `apps/api`
   - Railway detecta `Dockerfile` automaticamente (graças ao `railway.toml`).
   - **Variables**: clique em `Raw Editor` e cole o conteúdo do
     [`.env.production.example`](./.env.production.example) preenchido.
     Vincule `DATABASE_URL` e `REDIS_URL` aos add-ons (botão "Reference variable").
   - **Settings → Networking** → `Generate Domain` (te dá um `*.up.railway.app`).
   - **Settings → Deploy** → `Health Check Path` → já vem `/api/v1/health/live` do `railway.toml`.

5. **Configurar serviço Worker**:
   - `+ New` → `GitHub Repo` → mesmo repo
   - **Settings → Service → Source** → `Root Directory`: deixe **vazio** (raiz do repo)
   - O `railway.toml` em `apps/workers/` aponta `dockerfilePath = "apps/workers/Dockerfile"`. Como o Railway lê o `railway.toml` do root directory, copie o conteúdo de `apps/workers/railway.toml` direto na UI ou referencie via env (mais simples: configure manualmente em Settings).

   > Alternativa mais simples: configure manualmente em **Settings → Build**:
   > - Builder: `Dockerfile`
   > - Dockerfile Path: `apps/workers/Dockerfile`
   > - Start Command: deixe em branco (usa CMD do Dockerfile)

   - **Variables**: as mesmas do API (mesmo Postgres, mesmas TLS Temporal, mesmo `GROQ_API_KEY`).

6. **Apontar domínio próprio (opcional)**:
   - Settings → Custom Domain → `api.flashmind.app`
   - No seu DNS, crie um CNAME apontando pro `*.up.railway.app` que o Railway te dá.
   - Adicione `api.flashmind.app` em `DJANGO_ALLOWED_HOSTS`.

#### Variáveis críticas no Railway (api e worker)

| Variável | De onde sai |
|---|---|
| `DJANGO_SECRET_KEY` | Você gera: `python -c "import secrets; print(secrets.token_urlsafe(50))"` |
| `DJANGO_ALLOWED_HOSTS` | `api.flashmind.app,*.up.railway.app` |
| `DATABASE_URL` | Reference do Postgres add-on |
| `REDIS_URL` | Reference do Redis add-on |
| `CORS_ALLOWED_ORIGINS` | URL do frontend (`https://flashmind.vercel.app,https://flashmind.app`) |
| `GROQ_API_KEY` | https://console.groq.com/keys |
| `TEMPORAL_ADDRESS` | `<namespace>.<account>.tmprl.cloud:7233` (Temporal Cloud) |
| `TEMPORAL_NAMESPACE` | `<namespace>.<account>` |
| `TEMPORAL_TLS_CERT` | Conteúdo PEM (multilinha) — Temporal Cloud → Settings → Certificates |
| `TEMPORAL_TLS_KEY` | Conteúdo PEM (multilinha) — mesma tela |
| `SENTRY_DSN` | Sentry → Project → Client Keys |
| `SMTP_*` | Resend (`smtp.resend.com:587`, user `resend`, password `re_xxx`) ou Gmail App Password |
| `EMAIL_FROM` | `FlashMind <noreply@flashmind.app>` |

### Frontend → Vercel

```bash
# Opção 1: pelo Dashboard (recomendado pro 1º deploy)
# https://vercel.com/new
#   Import Git Repository → este repo
#   Root Directory: apps/web
#   Framework Preset: Next.js (auto-detectado pelo vercel.json)
#   Build Command: npm run build (já no vercel.json)
#   Environment Variables: cole as NEXT_PUBLIC_* do .env.production.example
```

Vars que **precisam** estar no Vercel (Settings → Environment Variables, marca todos os 3 envs):

| Variável | Valor |
|---|---|
| `NEXT_PUBLIC_API_URL` | `https://api.flashmind.app/api/v1` (URL do Railway) |
| `NEXT_PUBLIC_APP_URL` | `https://flashmind.app` |
| `NEXT_PUBLIC_SENTRY_DSN` | DSN frontend do Sentry |
| `NEXT_PUBLIC_SENTRY_ENV` | `production` |
| `SENTRY_AUTH_TOKEN` | Pra subir source maps (opcional) |
| `SENTRY_ORG` | Slug da org no Sentry |
| `SENTRY_PROJECT` | `flashmind-web` |

```bash
# Opção 2: via CLI
npm i -g vercel
cd apps/web
vercel --prod   # primeira vez pede login + linka projeto
```

Após o deploy, **adicione a URL do Vercel no `CORS_ALLOWED_ORIGINS` do
Railway** — senão o browser bloqueia.

### Worker → Railway

Já coberto na seção da API. O worker:
- Não escuta porta nenhuma (não precisa de `Generate Domain`)
- Compartilha as variáveis `DATABASE_URL`, `GROQ_API_KEY`, `TEMPORAL_*`, `SENTRY_DSN`
- Restart automático em falha (`restartPolicyType = "ON_FAILURE"`)

### Temporal Cloud

A Temporal Cloud tem **free tier** (\$0/mês até 250 actions). Setup:

1. Criar conta em https://cloud.temporal.io
2. **Create Namespace**: nome `flashmind` (ficará tipo `flashmind.acct123`).
3. **Settings → Certificates → Create Certificate**:
   - Baixa um par `client.pem` + `client.key`.
   - Copie o **conteúdo inteiro** dos dois (incluindo `-----BEGIN/END-----`).
4. Cole no Railway como variáveis:
   - `TEMPORAL_TLS_CERT` = conteúdo de `client.pem`
   - `TEMPORAL_TLS_KEY` = conteúdo de `client.key`
   - `TEMPORAL_ADDRESS` = `flashmind.acct123.tmprl.cloud:7233`
   - `TEMPORAL_NAMESPACE` = `flashmind.acct123`
5. Restart os serviços `api` e `worker` no Railway.

> Alternativa: rodar Temporal self-hosted no Railway (mais setup).
> Se quiser ir nesse caminho, abra um issue ou peça uma versão.

### Mobile (build de release)

```bash
cd apps/mobile

# Android APK
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.flashmind.app/api/v1

# Android App Bundle (pra publicar na Play Store)
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.flashmind.app/api/v1

# iOS (precisa de Mac + Apple Developer account)
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://api.flashmind.app/api/v1
```

Pra publicar:
- **Play Store**: Google Play Console (\$25 vitalício) → upload do `.aab`.
- **App Store**: Apple Developer (\$99/ano) → upload via Xcode/Transporter.

---

## Lista completa de tokens / segredos

Tudo que você vai precisar criar / gerar pra ter o projeto no ar:

### Obrigatório (sem isso não roda)

| Item | Onde criar | Pra quê | Onde colar |
|---|---|---|---|
| **`DJANGO_SECRET_KEY`** | `python -c "import secrets; print(secrets.token_urlsafe(50))"` | Sign de JWT, sessions | Railway (api + worker) |
| **`GROQ_API_KEY`** | https://console.groq.com/keys (login Google, **gratuito**) | Geração de cards via IA | Railway (api + worker) |
| **`DATABASE_URL`** | Railway Postgres add-on (1 clique) | Banco de dados | Auto-provisionado |
| **`REDIS_URL`** | Railway Redis add-on (1 clique) | Cache + rate-limit | Auto-provisionado |

### Recomendado (deploy completo)

| Item | Onde criar | Pra quê | Onde colar |
|---|---|---|---|
| **Conta Vercel** | https://vercel.com/signup (free) | Hosting do frontend | Login uma vez |
| **Conta Railway** | https://railway.app/login (\$5 grátis/mês) | Hosting do backend | Login uma vez |
| **Temporal Cloud Cert + Key** | https://cloud.temporal.io → Certificates | Conexão mTLS pro worker | Railway (`TEMPORAL_TLS_*`) |
| **Sentry DSN backend** | https://sentry.io → Create Project (Django) → DSN | Erros do backend | Railway (`SENTRY_DSN`) |
| **Sentry DSN frontend** | https://sentry.io → Create Project (Next.js) → DSN | Erros do frontend | Vercel (`NEXT_PUBLIC_SENTRY_DSN`) |
| **Resend API key** | https://resend.com (free 100 emails/dia) | Email de verificação | Railway (`SMTP_PASSWORD`) |

### Opcional (qualidade de vida)

| Item | Onde criar | Pra quê | Onde colar |
|---|---|---|---|
| **Sentry Auth Token** | Sentry → Settings → Auth Tokens → scope `project:releases` | Upload de source maps no build | Vercel (`SENTRY_AUTH_TOKEN`) |
| **Vercel Token** | Vercel → Settings → Tokens | Deploy via CI sem reautenticar | GitHub Secret |
| **Railway Token** | Railway → Account Settings → Tokens | Deploy via CI sem reautenticar | GitHub Secret |
| **Domínio próprio** | Registro.br / Cloudflare | URLs bonitas (`flashmind.app`) | Vercel + Railway DNS |
| **Apple Developer** (\$99/ano) | https://developer.apple.com | Publicar app iOS | Distribuição mobile |
| **Google Play Console** (\$25 1x) | https://play.google.com/console | Publicar app Android | Distribuição mobile |

### Resumão dos preços (MVP)

```
Vercel        → R$ 0     (Hobby plan)
Railway       → R$ 0–25  ($5 free credit; depois pay-as-you-go)
Temporal Cloud→ R$ 0     (250 actions/dia free)
Sentry        → R$ 0     (5k events/mês free)
Resend        → R$ 0     (3k emails/mês free)
Groq          → R$ 0     (free tier generoso)
Domínio       → R$ 40/ano (.com.br via Registro.br)
─────────────────────────
Total mensal  → ~ R$ 0–25 enquanto for MVP
```

---

## CI/CD

Já tem um workflow em [`.github/workflows/ci.yml`](./.github/workflows/ci.yml) que roda em todo PR/push:

- **api**: ruff lint + pytest com cobertura, com Postgres + Redis em services.
- **web**: lint + type-check + build do Next.
- **mobile**: format check + flutter analyze + build_runner.
- **worker**: py_compile sanity.

### Auto-deploy (continuous delivery)

- **Vercel**: já é automático. Toda push em `main` faz deploy de produção; PRs viram preview deploys.
- **Railway**: também já é automático se você conectar o GitHub no setup. Cada push em `main` faz redeploy da api + worker.

### Pra adicionar deploy via GitHub Actions (opcional)

Se preferir controlar deploys pelo CI (recomendado pra times maiores):

```yaml
# .github/workflows/deploy.yml
deploy-railway:
  needs: [api, worker]
  runs-on: ubuntu-latest
  if: github.ref == 'refs/heads/main'
  steps:
    - uses: actions/checkout@v4
    - run: npm i -g @railway/cli
    - run: railway up --service api
      env:
        RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
```

---

## Troubleshooting

| Problema | Causa | Solução |
|---|---|---|
| `DisallowedHost` no Railway | Falta o domínio em `DJANGO_ALLOWED_HOSTS` | Adicionar `*.up.railway.app` ou seu domínio custom |
| CORS bloqueando o Vercel | Falta a URL em `CORS_ALLOWED_ORIGINS` | Colar `https://<seu-app>.vercel.app` |
| Worker reinicia em loop | TLS do Temporal mal-formatado | Conferir se `TEMPORAL_TLS_CERT/KEY` têm `-----BEGIN`/`END-----` e quebras de linha intactas |
| `connection refused` na API | Postgres/Redis ainda subindo | `entrypoint.sh` espera 60s; depois disso, ver logs do add-on |
| Build do Vercel falha em `output: standalone` | `NEXT_OUTPUT` setado por engano | Não definir essa var no Vercel — ela é só pro Docker |
| Sentry não recebe eventos | DSN no env errado / DSN do projeto errado | `console.log(process.env.NEXT_PUBLIC_SENTRY_DSN)` no client e checar |
| Mobile dá `network error` | URL aponta pra `localhost` (não funciona em device físico) | Usar IP da máquina ou domínio público |

Logs em produção:

```bash
# Railway CLI
npm i -g @railway/cli
railway login
railway logs --service api
railway logs --service worker

# Vercel CLI
vercel logs <deployment-url>
```

---

## Estrutura do repo

```
flashmind/
├── apps/
│   ├── api/              # Django backend
│   │   ├── apps/         # apps Django (users, decks, reviews, jobs, microlearning, core)
│   │   ├── config/       # settings, urls, wsgi/asgi
│   │   ├── tests/        # pytest (unit + integration)
│   │   ├── Dockerfile    # multi-stage prod
│   │   ├── Procfile      # fallback Heroku-style
│   │   └── railway.toml
│   ├── web/              # Next.js frontend
│   │   ├── src/          # app router, components, hooks, lib
│   │   ├── sentry.*.ts   # configs de runtime do Sentry
│   │   ├── Dockerfile    # multi-stage prod (output standalone)
│   │   └── vercel.json
│   ├── mobile/           # Flutter app (offline-first)
│   │   └── lib/
│   └── workers/          # Temporal worker (Groq + ORM)
│       ├── activities/
│       ├── workflows/
│       ├── Dockerfile    # multi-stage; copia código da API
│       └── railway.toml
├── infra/                # Postgres init scripts
├── .github/workflows/    # CI
├── docker-compose.yml    # dev local
├── .env.example          # vars de DEV
├── .env.production.example  # vars de PROD (checklist)
├── PRD.md / TechSpecs.md # documentação de produto
└── README.md             # você está aqui
```

---

Dúvidas? Issues e PRs bem-vindos.
