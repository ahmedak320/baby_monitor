# Baby Monitor - Project Conventions

## Project Structure
- `app/` — Flutter mobile app (iOS + Android + tablets)
- `worker/` — Python AI analysis worker
- `supabase/` — Database migrations and edge functions
- `scripts/` — Seed scripts and utilities
- `docs/` — Architecture documentation

## Tech Stack
- **Mobile**: Flutter 3.x + Riverpod + GoRouter + Hive + freezed
- **Backend**: Supabase (PostgreSQL, Auth, Edge Functions, Realtime)
- **AI Worker**: Python 3.12 + FastAPI + Claude Haiku + open-source ML models
- **YouTube**: Hybrid API (official v3 primary, Piped fallback)

## Flutter Conventions
- State management: Riverpod (flutter_riverpod + riverpod_annotation)
- Routing: GoRouter with typed routes
- Data classes: freezed + json_serializable
- Local storage: Hive
- File naming: snake_case
- Use `ConsumerWidget` / `ConsumerStatefulWidget` for widgets that read providers

## Python Worker Conventions
- Python 3.12+
- Type hints required
- Pydantic for data models
- async/await for I/O operations
- Logging via Python `logging` module

## Commands
- Flutter analyze: `cd app && flutter analyze`
- Flutter test: `cd app && flutter test`
- Flutter run: `cd app && flutter run`
- Python worker: `cd worker && python main.py`
- Python test: `cd worker && pytest`

## Environment Variables
- Never commit `.env` files
- Use `.env.example` as template
- Supabase URL and keys go in `.env`

## Git
- Commit after each logical step
- Descriptive commit messages
- Never commit secrets or .env files
