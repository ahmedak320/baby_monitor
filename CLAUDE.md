# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Flutter (app/)
- **Analyze**: `cd app && flutter analyze --no-fatal-infos`
- **Format check**: `cd app && dart format --set-exit-if-changed lib/ test/`
- **Run all tests**: `cd app && flutter test`
- **Run single test**: `cd app && flutter test test/path/to_test.dart`
- **Run app (mobile)**: `cd app && flutter run --flavor mobile`
- **Run app (TV)**: `cd app && flutter run --flavor tv` (use Android TV emulator)
- **Build mobile APK**: `cd app && flutter build apk --debug --flavor mobile`
- **Build TV APK**: `cd app && flutter build apk --debug --flavor tv`
- **Code generation** (freezed/json_serializable/riverpod): `cd app && dart run build_runner build --delete-conflicting-outputs`
- **Bump version**: `./scripts/bump_version.sh [major|minor|patch]`

### Python worker (worker/)
- **Run worker**: `cd worker && python main.py` (starts queue consumer, auto-discovery, and FastAPI server concurrently)
- **Syntax check**: `cd worker && python -m py_compile main.py`
- **Run tests**: `cd worker && python -m pytest tests/ -v`
- **Install deps**: `cd worker && pip install -r requirements.txt`
- **Docker build**: `cd worker && docker build -t baby-monitor-worker .`
- **Seed database**: `cd scripts && python seed_videos.py` (populates channels/videos via Piped API to avoid YouTube quota)

### CI/CD
- **CI** runs on PRs and pushes to `main`: analyze, format check, tests, build both APK flavors, worker pytest, security audit
- **Release** triggered by pushing a `v*` tag: runs tests, builds signed release APKs (mobile + TV), creates GitHub Release with artifacts
- Toolchain: Flutter 3.41.x, Java 17, Python 3.12

### Supabase
- Migrations in `supabase/migrations/` (12 SQL files: 001 initial schema through 012 remote config)
- Edge functions in `supabase/functions/` (e.g., `aggregate-ratings` for community consensus + auto-blacklisting)

## Architecture

### Three-component system
1. **Flutter app** (`app/`) — parent-facing dashboard + kid-safe YouTube viewer
2. **Python AI worker** (`worker/`) — polls Supabase `analysis_queue`, runs videos through a tiered analysis pipeline, writes results back. Also runs FastAPI endpoints and periodic auto-discovery. Containerized via Dockerfile.
3. **Supabase** — PostgreSQL database, auth, edge functions, realtime. All RLS-enabled.

### Flutter app layers (`app/lib/`)
The app follows clean architecture with clear layer boundaries:

- **`config/`** — App config (env vars via `flutter_dotenv`), theme (separate `kid_theme.dart` and `parent_theme.dart`), constants
- **`data/`** — Datasources (remote: Supabase, YouTube v3, Piped fallback with multi-instance pool, analysis API, circuit breaker; local: Hive caches), repositories, models
- **`domain/services/`** — Business logic: content filtering, age recommendations, feed curation, screen time, subscriptions, content scheduling
- **`presentation/`** — UI organized by feature: `auth/`, `onboarding/`, `parent_dashboard/`, `kid_mode/`, `community/`, `common/`. Each feature has `screens/`, `providers/`, and optionally `widgets/`
- **`providers/`** — App-wide Riverpod providers (current user, current child, subscription, connectivity, device ID, supabase client)
- **`routing/`** — GoRouter config with auth guard redirect. Routes: `/login`, `/signup`, `/onboarding/*`, `/dashboard/**` (parent), `/kid/*` (child)

### Key cross-cutting patterns

**Supabase client access**: Singleton wrapper `SupabaseClientWrapper` in `data/datasources/remote/supabase_client.dart` — use `SupabaseClientWrapper.client`, `.auth`, `.currentUser`, `.isAuthenticated`.

**Data models**: Currently plain Dart classes with manual `toSupabaseRow()` / `fromSupabaseRow()` serialization. Freezed + json_serializable dependencies are declared in pubspec.yaml but not yet actively used — run `build_runner` only when freezed annotations are added.

**Biometric auth**: `BiometricHelper` in `utils/biometric_helper.dart` gates sensitive transitions — `authenticateForChildSwitch()` and `authenticateForExitKidMode()` are the two main entry points. Web always returns false.

**Kid/parent mode switching**: Child select screen requires biometric auth, sets `currentChildProvider`, navigates to `/kid/*`. Exiting kid mode requires biometric auth and returns to `/dashboard`. Each mode applies its own theme (`KidTheme` / `ParentTheme`).

**Responsive layout**: Parent dashboard supports phone and tablet layouts (split-view on tablet via `TabletDashboardScreen`).

### YouTube API strategy
Hybrid approach with resilience layers:
- **Primary**: YouTube Data API v3 with 10,000 daily quota tracker per key
- **Key rotation**: `YOUTUBE_API_KEYS` supports multiple GCP project keys (comma-separated) for combined quota
- **Fallback**: Piped API via `PipedApiClient` with multi-instance pool (`PIPED_INSTANCES`) and circuit breaker for failover
- All clients in `data/datasources/remote/`

### AI analysis pipeline (worker/)
5-tier funnel with early stopping when confidence is high enough:
- **Tier 0**: Community cache lookup (free) — skip already-analyzed videos
- **Tier 0.5**: Semantic embedding analysis — vector similarity for borderline cases
- **Tier 1**: Metadata + transcript text analysis (~$0.003) — threshold: 0.85 confidence
- **Tier 2**: Visual frame analysis (~$0.015) — only if Tier 1 can't decide, threshold: 0.90
- **Tier 3**: Audio analysis via Whisper + classifiers (~$0.005) — only if flagged for audio review

**Multi-provider support**: Configurable via `AI_PROVIDER` env var. Supports `claude` (Anthropic), `gemini` (Google), `openai`, and `local` (Ollama at `LOCAL_MODEL_URL`). Provider selection in `worker/config.py`.

Worker analyzers in `worker/analyzers/`: `haiku_text_analyzer`, `haiku_vision_analyzer`, `whisper_transcriber`, `toxicity_analyzer`, `violence_classifier`, `nsfw_classifier`, `audio_classifier`, `kids_content_classifier`

### Worker API (FastAPI)
`worker/api/routes.py` exposes 3 endpoints on port 8000 (protected by `WORKER_API_KEY`):
- `GET /api/health` — status check
- `POST /api/analyze` — trigger direct video analysis
- `GET /api/analysis/{video_id}` — fetch cached analysis result

### Worker auto-discovery
`worker/discovery/auto_discovery.py` runs every 6 hours, searching Piped API for popular content across age-group categories and queuing new videos for analysis.

### Database schema (Supabase)
Key tables: `parent_profiles`, `child_profiles`, `subscriptions` (free/premium tiers), `yt_videos`, `yt_channels`, `video_analyses` (community-shared scores), `analysis_queue`, `parent_channel_prefs`, `parent_video_overrides`, `content_preferences`, `screen_time_rules`, `screen_time_sessions`, `watch_history`, `filtered_log`, `content_schedules`, `offline_playlists`, `community_ratings`, `devices`

`handle_new_user()` trigger auto-creates `parent_profiles` + `subscriptions` rows on auth signup.

SQL functions (migration 002): `update_channel_trust_scores()`, `increment_analysis_usage()`, `reset_monthly_analysis_counters()`, `get_community_consensus()`.

### Freemium model
- Free: 50 analyses/month
- Premium: unlimited analyses, content scheduling, offline playlists
- Tracked in `subscriptions` table (`tier`, `monthly_analyses_used`, `monthly_analyses_limit`)
- Payments via RevenueCat (`purchases_flutter`)

## Conventions

### Flutter
- State management: Riverpod (`flutter_riverpod` + `riverpod_annotation`)
- Routing: GoRouter with named routes (see `route_names.dart`)
- Local storage: Hive
- Widgets reading providers: use `ConsumerWidget` / `ConsumerStatefulWidget`
- File naming: snake_case
- Android flavors: `mobile` (phones/tablets) and `tv` (Android TV/Fire TV)
- Min SDK: 23 (Android 6.0)

### Python worker
- Python 3.12+, type hints required
- Pydantic for data models, async/await for I/O
- Config via `dataclass` in `config.py` (loaded from .env)
- Logging via Python `logging` module
- Cost tracking per video via `utils/cost_tracker.py`
- Gemini free tier rate limits: 10 RPM, 1,400 RPD

## Environment Variables
- Store in `.env` (never commit). Use `.env.example` as template.
- **Required (app)**: `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- **Required (worker)**: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `YOUTUBE_API_KEY`
- **AI providers** (worker, at least one): `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY`
- **AI config**: `AI_PROVIDER` (default: `claude`; options: `claude`, `gemini`, `openai`, `local`), `LOCAL_MODEL_URL` (default: `http://localhost:11434`)
- **YouTube resilience**: `YOUTUBE_API_KEYS` (comma-separated multi-key rotation), `PIPED_INSTANCES` (comma-separated failover URLs)
- **Optional**: `PIPED_API_URL` (single instance, legacy), `WORKER_API_KEY` (protects FastAPI endpoints), `REVENUECAT_API_KEY`
