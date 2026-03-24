# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Flutter (app/)
- **Analyze**: `cd app && flutter analyze`
- **Run all tests**: `cd app && flutter test`
- **Run single test**: `cd app && flutter test test/path/to_test.dart`
- **Run app**: `cd app && flutter run`
- **Code generation** (freezed/json_serializable/riverpod): `cd app && dart run build_runner build --delete-conflicting-outputs`

### Python worker (worker/)
- **Run worker**: `cd worker && python main.py`
- **Syntax check**: `cd worker && python -m py_compile main.py`
- **Run tests**: `cd worker && pytest`
- **Install deps**: `cd worker && pip install -r requirements.txt`

### Supabase
- Migrations live in `supabase/migrations/` (numbered SQL files)
- Edge functions in `supabase/functions/`

## Architecture

### Three-component system
1. **Flutter app** (`app/`) — parent-facing dashboard + kid-safe YouTube viewer
2. **Python AI worker** (`worker/`) — polls Supabase `analysis_queue`, runs videos through a tiered analysis pipeline, writes results back
3. **Supabase** — PostgreSQL database, auth, edge functions, realtime. All RLS-enabled.

### Flutter app layers (`app/lib/`)
The app follows clean architecture with clear layer boundaries:

- **`config/`** — App config (env vars via `flutter_dotenv`), theme (separate `kid_theme.dart` and `parent_theme.dart`), constants
- **`data/`** — Datasources (remote: Supabase, YouTube v3, Piped fallback, analysis API; local: Hive caches), repositories, DTOs, models
- **`domain/services/`** — Business logic: content filtering, age recommendations, feed curation, screen time, subscriptions, content scheduling
- **`presentation/`** — UI organized by feature: `auth/`, `onboarding/`, `parent_dashboard/`, `kid_mode/`, `community/`, `common/`. Each feature has `screens/`, `providers/`, and optionally `widgets/`
- **`providers/`** — App-wide Riverpod providers (current user, current child, subscription, connectivity, device ID)
- **`routing/`** — GoRouter config with auth guard redirect. Routes: `/login`, `/signup`, `/onboarding/*`, `/dashboard/**` (parent), `/kid/*` (child)

### YouTube API strategy
Hybrid approach: official YouTube Data API v3 is primary with a 10,000 daily quota tracker. When quota is exhausted, falls back to Piped API (`PipedApiClient`). Both in `data/datasources/remote/`.

### AI analysis pipeline (worker/)
4-tier funnel with early stopping when confidence is high enough:
- **Tier 0**: Community cache lookup (free) — skip already-analyzed videos
- **Tier 1**: Metadata + transcript text analysis via Claude Haiku (~$0.003) — threshold: 0.85 confidence
- **Tier 2**: Visual frame analysis (~$0.015) — only if Tier 1 can't decide, threshold: 0.90
- **Tier 3**: Audio analysis via Whisper + classifiers (~$0.005) — only if flagged for audio review

Worker analyzers: `haiku_text_analyzer`, `haiku_vision_analyzer`, `whisper_transcriber`, `toxicity_analyzer`, `violence_classifier`, `nsfw_classifier`, `audio_classifier`, `kids_content_classifier`

### Database schema (Supabase)
Key tables: `parent_profiles`, `child_profiles`, `subscriptions` (free/premium tiers), `yt_videos`, `yt_channels`, `video_analyses` (community-shared scores), `analysis_queue`, `parent_channel_prefs`, `parent_video_overrides`, `screen_time_rules`, `screen_time_sessions`, `watch_history`, `filtered_log`, `content_schedules`, `offline_playlists`, `community_ratings`

`handle_new_user()` trigger auto-creates `parent_profiles` + `subscriptions` rows on auth signup.

### Freemium model
- Free: 50 analyses/month
- Premium: unlimited analyses, content scheduling, offline playlists
- Tracked in `subscriptions` table (`tier`, `monthly_analyses_used`, `monthly_analyses_limit`)

## Conventions

### Flutter
- State management: Riverpod (`flutter_riverpod` + `riverpod_annotation`)
- Routing: GoRouter with named routes (see `route_names.dart`)
- Data classes: freezed + json_serializable (run build_runner after changes)
- Local storage: Hive
- Widgets reading providers: use `ConsumerWidget` / `ConsumerStatefulWidget`
- File naming: snake_case

### Python worker
- Python 3.12+, type hints required
- Pydantic for data models, async/await for I/O
- Config via `dataclass` in `config.py` (loaded from .env)
- Logging via Python `logging` module

## Environment Variables
- Store in `.env` (never commit). Use `.env.example` as template.
- Required: `SUPABASE_URL`, `SUPABASE_ANON_KEY` (app), `SUPABASE_SERVICE_ROLE_KEY` (worker), `YOUTUBE_API_KEY`
- Optional: `ANTHROPIC_API_KEY` (worker, for Claude Haiku analysis), `PIPED_API_URL` (defaults to pipedapi.kavin.rocks)
