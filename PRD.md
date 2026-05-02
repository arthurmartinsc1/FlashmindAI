# PRD — FlashMind

## Product Requirements Document

**Versão:** 1.2  
**Data:** 2026-04-29  
**Autor:** Arthur Donato  
**Status:** Alinhado ao MVP implementado (revisão: frontend web + docs)

---

## 1. Visão Geral

### 1.1 Problema

Estudantes enfrentam dois problemas centrais no aprendizado autônomo:

1. **Esquecimento acelerado** — sem revisão espaçada, até 80% do conteúdo aprendido é esquecido em 48h (curva de Ebbinghaus). A maioria dos estudantes não sabe *quando* revisar para maximizar retenção.
2. **Falta de tempo e foco** — sessões longas de estudo são improdutivas. Estudantes perdem engajamento após 20–25 minutos, mas a maioria das plataformas oferece conteúdos monolíticos e extensos.

Ferramentas existentes (Anki, Quizlet) resolvem parcialmente o problema de repetição espaçada, mas são áridas em UX, não oferecem conteúdo estruturado por micro-lições, e não utilizam IA para acelerar a criação de material de estudo.

### 1.2 Solução

**FlashMind** é uma plataforma educacional que combina **flashcards com repetição espaçada (SM-2)** e **microlearning** — lições curtas de 5 minutos com blocos de texto, quiz e mídia — potencializada por **IA generativa** para criação automática de conteúdo.

### 1.3 Proposta de Valor

> "Aprenda qualquer coisa em 5 minutos por dia. Flashcards inteligentes que sabem exatamente o que você está prestes a esquecer."

**Diferenciais:**

- Algoritmo SM-2 que agenda revisões no momento ideal de retenção
- Micro-lições de 5 minutos que ensinam antes de testar
- IA gera flashcards automaticamente a partir de um tema ou texto
- Funciona offline no celular com sincronização transparente
- Dashboard de progresso com streaks e métricas de retenção

---

## 2. Público-Alvo

### 2.1 Personas

**Persona 1 — Lucas, 22 anos, universitário de Direito**
- Precisa memorizar grande volume de legislação e doutrina
- Estuda no ônibus e entre aulas (mobile-first)
- Frustrado com apps que exigem criar cards manualmente
- **Quer:** gerar flashcards a partir do nome de um tópico e estudar em sessões curtas

**Persona 2 — Marina, 28 anos, concurseira**
- Estuda 6h/dia para concurso público
- Usa planilhas para rastrear progresso, mas não consegue manter disciplina de revisão
- **Quer:** sistema que diga exatamente o que revisar hoje, com dashboard de evolução

**Persona 3 — Professor André, 35 anos, ensino médio**
- Quer criar material de estudo rápido para alunos
- Precisa de decks compartilháveis e relatórios de progresso
- **Quer:** gerar decks com IA e compartilhar link com a turma

### 2.2 Mercado

- **TAM:** 1.5B de estudantes globais
- **SAM:** ~200M de estudantes que usam apps de estudo
- **SOM:** foco inicial no Brasil — universitários, concurseiros, autodidatas

---

## 3. Funcionalidades

### 3.1 Mapa de Features (MVP)

| ID | Feature | Descrição | Plataforma |
|----|---------|-----------|------------|
| F1 | Autenticação | Cadastro e login com email/senha via JWT | Web + Mobile |
| F2 | Gerenciamento de Decks | CRUD de decks de flashcards com cor (hex); ícones não no MVP web | Web + Mobile |
| F3 | Gerenciamento de Cards | CRUD de cards frente/verso (texto; Markdown na web renderizado em micro-lições, não no flip de estudo) | Web + Mobile |
| F4 | Modo Estudo (SM-2) | Sessão de revisão com algoritmo de repetição espaçada | Web + Mobile |
| F5 | Dashboard de Progresso | Métricas de retenção, streak, gráficos de atividade | Web + Mobile |
| F6 | Geração de Cards com IA | Gerar flashcards e micro-lições a partir de tema/texto via Temporal workflow | Web + Mobile |
| F7 | Micro-lições | Conteúdo curto (texto, destaque e quiz) associado a decks | Web + Mobile |
| F8 | Offline-first Mobile | Leituras locais, SM-2 local e sync de operações pendentes | Mobile |

### 3.1.1 Frontend Web (Next.js) — implementado

| Rota | Descrição |
|------|-----------|
| `/` | Landing: Navbar, Hero, How it works, Features, Pricing, Footer |
| `/login`, `/register`, `/verify-email` | Auth e verificação de e-mail |
| `/dashboard` | Métricas (F5), gráfico 30 dias, distribuição, decks, CTA revisão |
| `/decks`, `/decks/[id]` | Decks; detalhe com abas **Cards**, **Micro-lição**, **Estatísticas** |
| `/review` | Lista / escolha de deck; sessão com `?deck_id=` ; UX para decks bloqueados por micro-lição |
| `/ai` | Gerar com IA escolhendo deck (rota auxiliar; fluxo principal no deck via **Gerar com IA**) |

Layout autenticado: **Sidebar** (Dashboard, Meus decks, Revisar hoje), **Topbar** em viewport estreito, **AuthGuard**.

### 3.2 Detalhamento por Feature

---

#### F1 — Autenticação

**Descrição:** Sistema de autenticação baseado em JWT com refresh token rotation.

**Regras de negócio:**
- Cadastro com email (único) + senha (mínimo 8 caracteres, 1 maiúscula, 1 número)
- Login retorna access token (15 min TTL) + refresh token (7 dias TTL)
- Refresh token rotation: cada uso gera novo par e revoga o anterior
- Rate limiting: máximo 5 tentativas de login por minuto por IP
- Endpoint `/auth/me` retorna perfil do usuário autenticado
- Logout revoga todos os refresh tokens ativos

**Endpoints:**
```
POST /api/v1/auth/register   { email, password, name }       → 201 { user, tokens }
POST /api/v1/auth/login      { email, password }              → 200 { tokens }
POST /api/v1/auth/refresh    { refresh_token }                → 200 { tokens }
POST /api/v1/auth/logout     Authorization: Bearer <token>    → 204
GET  /api/v1/auth/me         Authorization: Bearer <token>    → 200 { user }
```

---

#### F2 — Gerenciamento de Decks

**Descrição:** CRUD completo de decks (coleções de flashcards).

**Regras de negócio:**
- Campos: título (obrigatório, max 100 chars), descrição (opcional, max 500), cor (hex), visibilidade (público/privado)
- Listagem retorna contagem de cards totais e cards pendentes de revisão
- Busca por título (case-insensitive, parcial)
- Soft delete: decks são arquivados, não removidos
- Decks públicos são acessíveis por qualquer usuário autenticado (somente leitura)

**Endpoints:**
```
GET    /api/v1/decks/                                          → 200 { decks[], count }
POST   /api/v1/decks/           { title, description, color }  → 201 { deck }
GET    /api/v1/decks/{id}/                                     → 200 { deck, card_count, due_count }
PUT    /api/v1/decks/{id}/       { title, description, color } → 200 { deck }
DELETE /api/v1/decks/{id}/                                     → 204 (soft delete)
GET    /api/v1/decks/public/                                   → 200 { decks[] }
```

---

#### F3 — Gerenciamento de Cards

**Descrição:** CRUD de flashcards dentro de um deck.

**Regras de negócio:**
- Campos: front (obrigatório), back (obrigatório), tags (lista de strings, opcional); o backend aceita conteúdo estilo Markdown nas strings
- **Web:** na lista/edição de cards e no **modo estudo** (`FlipCard`), frente e verso são exibidos como **texto simples** (sem parser Markdown no flip). **Micro-lições:** blocos tipo `text` usam **Markdown** na UI (`react-markdown`)
- Cards novos iniciam com ease_factor=2.5, interval=0, repetitions=0, next_review=hoje
- Importação em lote via CSV (colunas: front, back)
- Limite de 1000 cards por deck no plano free

**Endpoints:**
```
GET    /api/v1/decks/{id}/cards/                               → 200 { cards[] }
POST   /api/v1/decks/{id}/cards/   { front, back, tags }       → 201 { card }
PUT    /api/v1/cards/{id}/         { front, back, tags }        → 200 { card }
DELETE /api/v1/cards/{id}/                                     → 204
POST   /api/v1/decks/{id}/cards/import   multipart/form-data   → 201 { imported_count }
```

---

#### F4 — Modo Estudo (Algoritmo SM-2)

**Descrição:** Sessão de revisão com repetição espaçada. O coração do produto.

**Fluxo do usuário:**
1. Usuário acessa **Revisar hoje** (`/review`) ou abre um deck e vai em **Revisar**
2. Sistema busca cards com `next_review <= hoje` (e aplica regra de negócio de **bloqueio por micro-lição** para cards novos quando aplicável), ordena por `ease_factor` ASC
3. Exibe a frente do card
4. Usuário tenta lembrar, clica no card para revelar
5. Card faz flip com animação 3D, exibe o verso
6. Usuário auto-avalia: 0 (Blackout) → 5 (Perfeito) via botões dedicados
7. Sistema recalcula SM-2 e agenda próxima revisão
8. Próximo card é exibido automaticamente
9. Ao final da sessão: resumo (`StudySummary`) com métricas e ações **Nova sessão** / **Outros decks**


**Algoritmo SM-2 — Parâmetros:**

| Parâmetro | Default | Descrição |
|-----------|---------|-----------|
| ease_factor | 2.5 | Fator de facilidade (mínimo 1.3) |
| interval | 0 | Dias até próxima revisão |
| repetitions | 0 | Acertos consecutivos |
| quality | — | Avaliação do usuário (0–5) |

**Lógica de cálculo:**
- Se quality < 3: repetitions = 0, interval = 1 (card volta para o início)
- Se quality >= 3:
  - repetitions == 0 → interval = 1
  - repetitions == 1 → interval = 6
  - repetitions >= 2 → interval = round(interval × ease_factor)
- ease_factor = max(1.3, EF + 0.1 - (5 - quality) × (0.08 + (5 - quality) × 0.02))

**Labels de avaliação:**

| Score | Label | Cor | Significado |
|-------|-------|-----|-------------|
| 0 | Blackout | vermelho | Não lembrei de nada |
| 1 | Errei muito | laranja | Resposta totalmente errada |
| 2 | Errei | amarelo | Errei mas algo veio à mente |
| 3 | Difícil | azul claro | Acertei com muito esforço |
| 4 | Bom | verde claro | Acertei com algum esforço |
| 5 | Fácil | verde | Acertei sem hesitar |

**Endpoints:**
```
GET  /api/v1/review/due/                  → 200 { cards[], total_due }
GET  /api/v1/review/due/?deck_id={id}     → 200 { cards[], total_due }
POST /api/v1/review/{card_id}/  { quality, time_spent_ms }  → 200 { next_review, interval, ease_factor }
GET  /api/v1/review/summary/    ?date=YYYY-MM-DD            → 200 { reviewed, correct, time_total }
```

---

#### F5 — Dashboard de Progresso

**Descrição:** Painel com métricas de aprendizado e engajamento.

**Métricas exibidas:**

- **Cards para hoje:** contagem de cards com next_review <= hoje
- **Revisados hoje / semana / mês:** contagem de reviews no período
- **Taxa de retenção:** % de reviews com quality >= 3 (últimos 30 dias)
- **Streak atual:** dias consecutivos com pelo menos 1 revisão
- **Maior streak:** recorde pessoal
- **Gráfico de atividade:** heatmap ou barras dos últimos 30 dias (reviews/dia)
- **Distribuição de cards:** novos (nunca revisados) / aprendendo (interval < 21) / maduros (interval >= 21)

**Endpoint:**
```
GET /api/v1/progress/dashboard/  → 200 {
  due_today, reviewed_today, reviewed_week, reviewed_month,
  retention_rate, current_streak, longest_streak,
  activity_last_30_days: [{ date, count }],
  card_distribution: { new, learning, mature }
}
```

---

#### F6 — Geração de Cards com IA

**Descrição:** Workflow assíncrono via Temporal que chama LLM para gerar flashcards e, em seguida, uma micro-lição (best-effort) para o deck.

**Fluxo:**
1. Usuário clica **Gerar com IA** no deck (ou usa `/ai` escolhendo um deck)
2. Informa tópico; opcionalmente quantidade, idioma e texto-fonte (conforme API/UI)
3. Frontend mostra progresso e faz **polling** em `GET /api/v1/jobs/{job_id}` até `completed` ou `failed`
4. Backend dispara `GenerateCardsWorkflow` no Temporal (cards persistidos → geração/persistência da lição → job completo)
5. UI invalida caches (decks, cards, lições)
6. Usuário conclui pelo menos uma micro-lição quando aplicável para liberar cards novos na revisão

**Regras (alinhadas ao backend/worker atual):**
- Cards gerados com `source: "ai"`; revisão bloqueada até micro-lição quando as regras de gate aplicam
- Lição: até **uma** por execução bem-sucedida se não atingido o limite de lições por deck (ex.: 3); activity de lição pode falhar sem impedir conclusão do job de cards
- Geração por IA requer conexão no mobile
- Limites adicionais (taxa, timeout, retries) conforme configuração dos jobs/worker

**Endpoints:**
```
POST /api/v1/decks/{id}/generate   { topic, count?, language?, source_text? } → 202 AsyncJob
GET  /api/v1/jobs/{job_id}/                                   → 200 AsyncJob
```
---

#### F7 — Micro-lições

**Descrição:** Conteúdo educativo curto e estruturado, vinculado a um deck.

**Estrutura de uma micro-lição:**
- Pertence a exatamente 1 deck
- Composta por blocos ordenados (ContentBlock)
- Tipos de bloco:
  - `text`: parágrafo explicativo em Markdown
  - `quiz`: pergunta de múltipla escolha com 4 alternativas + feedback por alternativa
  - `highlight`: informação-chave em destaque visual (caixa colorida)
- Duração estimada: 5 minutos (metadado)
- Por execução bem-sucedida do workflow de IA: até **uma** nova micro-lição (se o limite por deck não foi atingido e a activity não falhar)
- Ao concluir pelo menos uma lição no deck, cards novos bloqueados por essa regra passam a poder entrar na revisão
- No mobile, lista, detalhe e blocos são persistidos no Drift para leitura offline

**Fluxo do usuário:**
1. Usuário abre um deck e vê abas **Cards**, **Micro-lição** e **Estatísticas**
2. Conteúdo é exibido bloco a bloco com scroll suave
3. Blocos quiz exigem seleção antes de prosseguir
4. Feedback imediato (certo/errado + explicação)
5. Ao final: "Lição concluída! Agora revise os flashcards deste deck."

**Endpoints:**
```
GET  /api/v1/decks/{id}/lessons/                          → 200 { lessons[] }
GET  /api/v1/lessons/{id}/                                → 200 { lesson, blocks[] }
POST /api/v1/lessons/{id}/complete                        → 200 { unlocked_cards_count }
```

---

#### F8 — Offline-first (Mobile)

**Descrição:** O app Flutter funciona completamente offline para estudo.

**Estratégia técnica:**
- SQLite local via Drift espelha dados do servidor
- Toda leitura consulta o banco local
- Toda escrita grava localmente e enfileira para sync
- SyncService roda em background quando conexão está disponível
- Conflitos resolvidos por last-write-wins (timestamp do servidor)

**O que funciona offline:**
- Listar decks e cards
- Ver micro-lições já sincronizadas
- Sessão completa de revisão (com SM-2 calculado localmente)
- Visualizar progresso e revisão do dia com dados locais
- Adicionar card manualmente
- Editar/excluir cards e decks
- Concluir micro-lições já armazenadas
- Enfileirar reviews e mutações locais para sincronização posterior

**O que requer conexão:**
- Cadastro / login
- Geração de cards com IA
- Primeiro download de dados ainda não sincronizados
- Envio efetivo das operações pendentes para o servidor

**Indicadores visuais:**
- Status online/offline no header
- Ícone de sincronização manual
- Lembrete visual para sincronizar puxando a tela para baixo
- Badge/contador de pendências considera reviews e operações locais

---

## 4. Requisitos Não-Funcionais

### 4.1 Performance

| Métrica | Target |
|---------|--------|
| Landing page LCP | < 2s |
| API response time (p95) | < 200ms |
| Tempo para exibir próximo card | < 100ms |
| Tempo de sync mobile (100 cards) | < 5s |

**Estratégias:** Cache Redis para cards do dia e dashboard, select_related/prefetch_related no ORM, paginação em listagens (20 items default).

### 4.2 Segurança

- Senhas com hash bcrypt (padrão Django)
- JWT com access token curto (15min) + refresh rotation
- Rate limiting em endpoints de autenticação (5/min)
- CORS restrito aos domínios da aplicação
- Security headers: X-Frame-Options, CSP, HSTS, X-Content-Type-Options
- Variáveis de ambiente para todos os secrets (nunca hardcoded)
- Input sanitization contra XSS no Markdown renderizado
- SQL injection prevenido pelo ORM do Django

### 4.3 Observabilidade

- Logs estruturados em JSON via structlog
- Sentry para error tracking (backend + frontend + mobile)
- Eventos de negócio logados: review.submitted, deck.created, ai.generation.started/completed/failed
- Health check endpoint: `GET /api/v1/health/` → 200 { status, db, redis, temporal }
- Métricas de latência por endpoint (via middleware Django)

### 4.4 Escalabilidade

- API stateless (escalável horizontalmente)
- Jobs assíncronos via Temporal (desacoplados da API)
- Cache Redis como camada intermediária
- PostgreSQL connection pooling
- Separação de read/write models preparada para CQRS futuro

---

## 5. Arquitetura de Alto Nível

```
┌─────────────────────────────────────────────────────────────┐
│                        CLIENTES                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ Landing Page │  │   Web App    │  │   Mobile App     │   │
│  │  (Next.js)   │  │  (Next.js)   │  │   (Flutter)      │   │
│  │  SSR + SEO   │  │  SPA + Auth  │  │  Offline + Sync  │   │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘   │
│         └─────────────────┼────────────────────┘             │
└───────────────────────────┼─────────────────────────────────┘
                            │ HTTPS / REST
┌───────────────────────────┼─────────────────────────────────┐
│                     BACKEND LAYER                           │
│                 ┌─────────▼──────────┐                      │
│                 │    Django Ninja    │                       │
│                 │    REST API        │                       │
│                 │  (Auth, Decks,     │                       │
│                 │   Cards, Reviews)  │                       │
│                 └──┬──────┬───────┬──┘                      │
│                    │      │       │                          │
│         ┌──────────▼┐  ┌──▼───┐  ┌▼───────────┐            │
│         │PostgreSQL │  │Redis │  │  Temporal   │            │
│         │   (data)  │  │(cache│  │  (workflows)│            │
│         └───────────┘  │ rate)│  └──────┬──────┘            │
│                        └──────┘        │                    │
│                              ┌─────────▼──────────┐         │
│                              │   Worker Service   │         │
│                              │ - AI card gen      │         │
│                              │ - Email sending    │         │
│                              │ - Daily reminders  │         │
│                              └─────────┬──────────┘         │
│                                        │                    │
│                              ┌─────────▼──────────┐         │
│                              │  Groq API / SMTP   │         │
│                              │  (external)        │         │
│                              └────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. Modelo de Dados

```
User
├── id: UUID (PK)
├── email: string (unique, indexed)
├── password_hash: string
├── name: string
├── created_at: datetime
└── updated_at: datetime

Deck
├── id: UUID (PK)
├── user_id: UUID (FK → User, indexed)
├── title: string (max 100)
├── description: string (max 500, nullable)
├── color: string (hex, default "#6366F1")
├── is_public: bool (default false)
├── is_archived: bool (default false)
├── created_at: datetime
└── updated_at: datetime

Card
├── id: UUID (PK)
├── deck_id: UUID (FK → Deck, indexed)
├── front: text (Markdown)
├── back: text (Markdown)
├── tags: JSON (string[], default [])
├── source: string (enum: "manual", "ai", "import")
├── ease_factor: float (default 2.5)
├── interval: int (default 0, dias)
├── repetitions: int (default 0)
├── next_review: date (default today)
├── created_at: datetime
└── updated_at: datetime

Review
├── id: UUID (PK)
├── card_id: UUID (FK → Card, indexed)
├── user_id: UUID (FK → User, indexed)
├── quality: int (0–5)
├── time_spent_ms: int
├── reviewed_at: datetime (indexed)
└── synced: bool (default true)

PendingOperation (mobile local / Drift)
├── id: int (PK local)
├── type: string (ex.: "card.create", "deck.update", "lesson.complete")
├── payload_json: text
└── created_at: datetime

MicroLesson
├── id: UUID (PK)
├── deck_id: UUID (FK → Deck, indexed)
├── title: string (max 200)
├── order: int
├── estimated_minutes: int (default 5)
├── created_at: datetime
└── updated_at: datetime

ContentBlock
├── id: UUID (PK)
├── lesson_id: UUID (FK → MicroLesson, indexed)
├── type: string (enum: "text", "quiz", "highlight")
├── content: JSON
│   ├── (text):      { body: "markdown string" }
│   ├── (quiz):      { question, options: string[], correct: int, explanation }
│   └── (highlight): { body: "markdown string", color: "yellow|blue|green" }
├── order: int
└── created_at: datetime

UserProgress
├── id: UUID (PK)
├── user_id: UUID (FK → User, unique, indexed)
├── current_streak: int (default 0)
├── longest_streak: int (default 0)
├── last_review_date: date (nullable)
├── total_reviews: int (default 0)
└── updated_at: datetime

AsyncJob
├── id: UUID (PK)
├── user_id: UUID (FK → User, indexed)
├── type: string (enum: "ai_generation", "csv_import")
├── status: string (enum: "pending", "running", "completed", "failed")
├── input_data: JSON
├── result_data: JSON (nullable)
├── error_message: text (nullable)
├── created_at: datetime
└── updated_at: datetime
```

---

## 7. User Flows

### 7.1 Primeiro Acesso

```
Landing Page → CTA "Começar grátis" / cadastro → `/register`
→ Login → `/dashboard` (sem fluxo de onboarding guiado por área de estudo no MVP web)
→ "Meus decks" / criar deck / gerar com IA a partir do deck
```

### 7.2 Sessão de Estudo Diária

**Web:** Dashboard pode mostrar CTA **Revisar agora** quando há cards no dia; alternativa **Revisar hoje** na sidebar → lista ou deck específico → sessão.

```
Card (frente) → clique para revelar → verso → avalia (0–5) → próximo card
→ ... → Sessão concluída → resumo (métricas) → Nova sessão / Outros decks
→ Streak refletido no dashboard após sync com API
```

### 7.3 Geração com IA

```
Dashboard ou Deck → "Gerar com IA" → tópico (+ opções) → polling do job
→ Cards + micro-lição quando gerados → aba "Micro-lição" → concluir lição
→ Cards disponíveis em `/review` (respeitando datas / gate)
```

---

## 8. Métricas de Sucesso

| Métrica | Target (3 meses) | Como medir |
|---------|-------------------|------------|
| DAU (Daily Active Users) | 500 | Users com pelo menos 1 review/dia |
| Retenção D7 | 40% | % de usuários ativos 7 dias após cadastro |
| Retenção D30 | 20% | % de usuários ativos 30 dias após cadastro |
| Cards revisados/sessão | >= 15 | Média de reviews por sessão de estudo |
| Streak médio | >= 5 dias | Média de streak entre usuários ativos |
| NPS | >= 50 | Survey in-app mensal |
| Cards gerados por IA / mês | 10.000 | Total de cards criados via workflow de IA |

---

## 9. Roadmap

### Fase 1 — MVP (este desafio, 7 dias)
- Auth, Decks, Cards, SM-2, Dashboard, IA Generation, Micro-lições
- Landing page com SEO
- App Flutter offline-first
- Temporal workflows
- Docker + CI/CD + Observabilidade

### Fase 2 — Growth (mês 2-3)
- Decks públicos com ranking (mais usados, melhor avaliados)
- Social: seguir outros usuários, compartilhar decks
- Gamificação: badges, XP, levels
- Push notifications de lembrete de revisão
- Importação de decks do Anki (.apkg)

### Fase 3 — Monetização (mês 4-6)
- Plano Pro: geração ilimitada de IA, analytics avançado, sem ads
- Plano Professor: turmas, relatórios de progresso dos alunos
- Marketplace de decks premium

---

## 10. Fora de Escopo (MVP)

- Login com Google/Apple (será adicionado na Fase 2)
- Sistema de pagamento/assinatura
- Gamificação além de streaks
- Áudio/TTS nos flashcards
- Editor WYSIWYG (Markdown é suficiente para MVP)
- Modo colaborativo em tempo real
- App desktop nativo
- Suporte a imagens nos cards (Fase 2)

---

## 11. Riscos e Mitigações

| Risco | Impacto | Probabilidade | Mitigação |
|-------|---------|---------------|-----------|
| Latência da IA na geração de cards | Médio | Alta | Workflow assíncrono + feedback visual de progresso |
| Conflitos de sync offline | Alto | Média | Last-write-wins + log de conflitos para auditoria |
| Custo/limite da API Groq | Médio | Média | Limite de gerações por usuário/dia + cache de temas populares |
| Scope creep no prazo de 7 dias | Alto | Alta | PRD com escopo claro, features priorizadas, bônus isolados |
| Complexidade do Temporal | Médio | Média | Começar com 1 workflow simples, expandir incrementalmente |

---

## 12. Dependências Externas

| Serviço | Uso | Alternativa |
|---------|-----|-------------|
| Groq API | Geração de flashcards e micro-lições com IA | OpenAI / Anthropic |
| Sentry | Error tracking | Self-hosted Sentry / GlitchTip |
| SMTP (SendGrid/Resend) | Emails transacionais | Mailgun |
| Redis | Cache + rate limiting | Memcached |
| Temporal Cloud | Workflow orchestration | Self-hosted Temporal |

---

*Documento atualizado para refletir o MVP implementado em web, backend e mobile.*
