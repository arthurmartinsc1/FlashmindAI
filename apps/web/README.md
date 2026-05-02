# FlashMind Web

Next.js 14 (App Router) + Tailwind CSS + shadcn/ui. Landing page, autenticação e
app de estudo.

## Desenvolvimento

O modo recomendado é via `docker compose` na raiz do monorepo:

```bash
docker compose up web
```

Fica em <http://localhost:3000>.

Localmente (sem Docker):

```bash
npm install
npm run dev
```

Variáveis de ambiente usadas em build/runtime:

| Var | Default | Descrição |
|-----|---------|-----------|
| `NEXT_PUBLIC_API_URL` | `http://localhost:8000/api/v1` | URL base da API |
| `NEXT_PUBLIC_APP_URL` | `http://localhost:3000` | URL pública pra OG/canonical |
