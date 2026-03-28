# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Flutter (app/)
- **Analyze**: `cd app && flutter analyze`
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
- **Run tests**: `cd worker && pytest`
- **Install deps**: `cd worker && pip install -r requirements.txt`
- **Seed database**: `cd scripts && python seed_videos.py` (populates channels/videos via Piped API to avoid YouTube quota)

### Supabase
- Migrations live in `supabase/migrations/` (4 numbered SQL files: initial schema, community functions, analytics events, video discovery)
- Edge functions in `supabase/functions/` (e.g., `aggregate-ratings` for community consensus + auto-blacklisting)

## Architecture

### Three-component system
1. **Flutter app** (`app/`) — parent-facing dashboard + kid-safe YouTube viewer
2. **Python AI worker** (`worker/`) — polls Supabase `analysis_queue`, runs videos through a tiered analysis pipeline, writes results back. Also runs FastAPI endpoints and periodic auto-discovery.
3. **Supabase** — PostgreSQL database, auth, edge functions, realtime. All RLS-enabled.

### Flutter app layers (`app/lib/`)
The app follows clean architecture with clear layer boundaries:

- **`config/`** — App config (env vars via `flutter_dotenv`), theme (separate `kid_theme.dart` and `parent_theme.dart`), constants
- **`data/`** — Datasources (remote: Supabase, YouTube v3, Piped fallback, analysis API; local: Hive caches), repositories, models
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
Hybrid approach: official YouTube Data API v3 is primary with a 10,000 daily quota tracker. When quota is exhausted, falls back to Piped API (`PipedApiClient`). Both in `data/datasources/remote/`.

### AI analysis pipeline (worker/)
4-tier funnel with early stopping when confidence is high enough:
- **Tier 0**: Community cache lookup (free) — skip already-analyzed videos
- **Tier 1**: Metadata + transcript text analysis via Claude Haiku (~$0.003) — threshold: 0.85 confidence
- **Tier 2**: Visual frame analysis (~$0.015) — only if Tier 1 can't decide, threshold: 0.90
- **Tier 3**: Audio analysis via Whisper + classifiers (~$0.005) — only if flagged for audio review

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

### Python worker
- Python 3.12+, type hints required
- Pydantic for data models, async/await for I/O
- Config via `dataclass` in `config.py` (loaded from .env)
- Logging via Python `logging` module
- Cost tracking per video via `utils/cost_tracker.py`

## Environment Variables
- Store in `.env` (never commit). Use `.env.example` as template.
- Required: `SUPABASE_URL`, `SUPABASE_ANON_KEY` (app), `SUPABASE_SERVICE_ROLE_KEY` (worker), `YOUTUBE_API_KEY`
- Optional: `ANTHROPIC_API_KEY` (worker, for Claude Haiku analysis), `PIPED_API_URL` (defaults to pipedapi.kavin.rocks), `WORKER_API_KEY` (protects FastAPI endpoints)
