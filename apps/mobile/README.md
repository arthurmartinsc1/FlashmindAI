# FlashMind — Mobile (Flutter)

App offline-first em Flutter. Estuda decks salvos localmente (SQLite via Drift),
salva reviews em uma fila, e sincroniza com a API quando volta a ter conexão.

## Stack

- **Flutter 3.22+ / Dart 3.4+**
- **flutter_riverpod** — state management
- **go_router** — navegação
- **Dio** — HTTP client (com interceptor de refresh token)
- **Drift + sqlite3_flutter_libs** — SQLite local
- **flutter_secure_storage** — tokens JWT
- **connectivity_plus** — detecção de rede

## Setup

```bash
# 1) Instalar dependências
cd apps/mobile
flutter pub get

# 2) Gerar código do Drift (cria database.g.dart)
dart run build_runner build --delete-conflicting-outputs

# 3) Apontar pra API local. Em dispositivo físico use o IP da sua máquina;
#    em emulador Android use 10.0.2.2; em iOS Simulator usa localhost.
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

## Estrutura

```
lib/
├── main.dart                # bootstrap (ProviderScope, Drift init)
├── app.dart                 # MaterialApp + GoRouter
├── core/                    # config, secure storage, connectivity
├── data/
│   ├── api/                 # Dio + endpoints
│   ├── db/                  # Drift database
│   └── repositories.dart    # repositórios offline-first
├── domain/models.dart       # DTOs do backend
├── features/
│   ├── auth/                # login + auth controller
│   ├── decks/               # lista de decks
│   └── study/               # modo estudo (flip card)
└── services/sync_service.dart
```

## Fluxo offline-first

1. **Login** salva tokens no `flutter_secure_storage`.
2. **SyncService.pull()** baixa decks + cards e popula o Drift.
3. **Modo estudo** lê _sempre_ do Drift, nunca direto da API.
4. Ao avaliar um card, o app:
   - aplica SM-2 localmente e atualiza a row em `cards`;
   - insere uma linha em `pending_reviews` (fila de sync).
5. **SyncService.push()** roda quando o app volta online (ou após cada review
   se já estiver online), faz `POST /review/{card_id}` para cada item da fila
   e remove os enviados.

Resultado: o usuário pode estudar no metrô e tudo sobe quando o sinal voltar.
