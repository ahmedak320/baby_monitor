# Baby Monitor — AI Coding Agent Guide

This file provides essential context for AI coding agents working on the Baby Monitor project.

## Project Overview

Baby Monitor is an AI-powered parental control app for safe YouTube viewing. Kids get a familiar YouTube-like experience with vertical Shorts, video feeds, and dark mode — while every video is screened by a multi-tier AI pipeline before it ever reaches their screen.

**Key Features:**
- Proactive AI filtering of YouTube content before it reaches children
- YouTube-native UI with dark theme, Shorts feed, and familiar navigation
- Age-adaptive sensitivity settings (4 age brackets: 0-2, 3-5, 5-8, 8-12)
- Multi-provider AI analysis (Claude, Gemini, OpenAI, or local models)
- Parent dashboard with activity overview, filter settings, and screen time management
- COPPA compliant with data minimization and parental consent

## Architecture

The system consists of three main components:

```
+------------------+        +------------------+        +------------------+
|   Flutter App    |<------>|    Supabase      |<------>|  Python Worker   |
| (iOS/Android/Web)|        | (PostgreSQL+Auth)|        | (FastAPI+Queue)  |
+------------------+        +------------------+        +------------------+
```

1. **Flutter App** (`app/`): Parent dashboard + kid-safe YouTube viewer
   - Clean architecture with config/data/domain/presentation layers
   - State management via Riverpod, routing via GoRouter
   - Local storage via Hive, video playback via youtube_player_iframe

2. **Python AI Worker** (`worker/`): Video analysis pipeline
   - Polls Supabase `analysis_queue` for videos to analyze
   - 5-tier analysis pipeline with early stopping (cache → embedding → text → visual → audio)
   - FastAPI server for direct analysis triggers
   - Auto-discovery runs every 6 hours to find popular kids content

3. **Supabase** (`supabase/`): Backend infrastructure
   - PostgreSQL database with Row-Level Security (RLS) policies
   - Auth, Edge Functions, Realtime subscriptions
   - pgvector extension for embedding similarity search

## Technology Stack

| Component | Technology | Version |
|-----------|------------|---------|
| **Mobile App** | Flutter / Dart | 3.41.x / 3.11+ |
| **State Management** | Riverpod | 2.6+ |
| **Routing** | GoRouter | 14.8+ |
| **Local Storage** | Hive | 2.2+ |
| **Backend** | Supabase | 2.9+ |
| **AI Worker** | Python | 3.12+ |
| **Worker Framework** | FastAPI + Uvicorn | Latest |
| **Database** | PostgreSQL + pgvector | 15+ |

## Project Structure

```
baby_monitor/
├── app/                          # Flutter application
│   ├── lib/
│   │   ├── main.dart             # Entry point
│   │   ├── app.dart              # MaterialApp with routing
│   │   ├── config/               # Themes, constants, legal text
│   │   │   ├── theme/
│   │   │   │   ├── kid_theme.dart
│   │   │   │   └── parent_theme.dart
│   │   │   └── constants.dart
│   │   ├── data/
│   │   │   ├── datasources/      # Local (Hive) and Remote (Supabase, YouTube, Piped)
│   │   │   ├── models/           # Data models
│   │   │   └── repositories/     # Repository implementations
│   │   ├── domain/services/      # Business logic services
│   │   ├── presentation/         # UI screens by feature
│   │   │   ├── auth/             # Login, Signup
│   │   │   ├── onboarding/       # 5-step guided setup
│   │   │   ├── kid_mode/         # Child-facing UI
│   │   │   └── parent_dashboard/ # Parent-facing UI
│   │   ├── providers/            # Riverpod providers
│   │   ├── routing/              # GoRouter configuration
│   │   └── utils/                # Helpers and utilities
│   ├── test/                     # Unit and widget tests
│   └── pubspec.yaml              # Dart dependencies
│
├── worker/                       # Python AI analysis worker
│   ├── main.py                   # Entry point
│   ├── config.py                 # Environment-based configuration
│   ├── pipeline/                 # 5-tier analysis pipeline
│   │   ├── orchestrator.py       # Pipeline coordinator
│   │   ├── tier0_cache.py        # Community cache lookup
│   │   ├── tier05_embedding.py   # Embedding similarity
│   │   ├── tier1_text.py         # Text analysis
│   │   ├── tier2_visual.py       # Visual frame analysis
│   │   └── tier3_audio.py        # Audio analysis
│   ├── providers/                # AI provider implementations
│   │   ├── base_provider.py
│   │   ├── claude_provider.py
│   │   ├── gemini_provider.py
│   │   ├── openai_provider.py
│   │   └── local_provider.py
│   ├── analyzers/                # Specialized classifiers
│   ├── extractors/               # Frame, audio, caption extraction
│   ├── discovery/                # Auto-discovery + recommendations
│   ├── api/                      # FastAPI routes
│   ├── job_queue/                # Queue consumer
│   └── tests/                    # pytest test suite
│
├── supabase/
│   ├── migrations/               # 21 SQL migration files
│   └── functions/                # Edge functions
│
├── scripts/                      # Utility scripts
│   ├── seed_videos.py            # Database seeding
│   ├── requeue_broken_analyses.py
│   └── bump_version.sh           # Version bumping
│
├── .github/workflows/            # CI/CD pipelines
│   ├── ci.yml                    # Pull request CI
│   └── release.yml               # Release builds
│
├── docs/
│   └── coppa-compliance.md       # COPPA compliance documentation
│
├── .env.example                  # Environment template (root)
├── app/.env.example              # Environment template (app)
└── README.md                     # Full project documentation
```

## Build and Test Commands

### Flutter App

```bash
cd app

# Install dependencies
flutter pub get

# Run static analysis
flutter analyze --no-fatal-infos

# Check formatting
dart format --set-exit-if-changed lib/ test/

# Run all tests
flutter test

# Run specific test file
flutter test test/unit/content_filter_service_test.dart

# Run app on device/emulator
flutter run --flavor mobile --dart-define-from-file=.env

# Build debug APK
flutter build apk --debug --flavor mobile --dart-define-from-file=.env

# Build release APK (requires signing setup)
flutter build apk --release --flavor mobile

# Code generation (when using freezed/riverpod annotations)
dart run build_runner build --delete-conflicting-outputs
```

### Python Worker

```bash
cd worker

# Install dependencies
pip install -r requirements.txt

# Run the worker (starts FastAPI + queue consumer + auto-discovery)
python main.py

# Run tests
python -m pytest tests/ -v

# Docker build
docker build -t baby-monitor-worker .
```

### Database Scripts

```bash
cd scripts

# Seed database with initial content
python seed_videos.py

# Repair video cache
python repair_video_cache.py

# Requeue failed analyses
python requeue_broken_analyses.py
```

## Environment Setup

### Required Environment Variables

**Root `.env` (for worker):**
```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
YOUTUBE_API_KEY=your-youtube-api-key
YOUTUBE_API_KEYS=key1,key2,key3  # Multiple keys for quota rotation
ANTHROPIC_API_KEY=your-anthropic-key  # or GEMINI_API_KEY or OPENAI_API_KEY
AI_PROVIDER=claude  # Options: claude, gemini, openai, local
```

**`app/.env` (for Flutter):**
```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
YOUTUBE_API_KEY=your-youtube-api-key
REVENUECAT_API_KEY=  # Optional, leave empty for dev mode
```

Copy from templates:
```bash
cp .env.example .env
cp app/.env.example app/.env
```

## Code Style Guidelines

### Flutter

- **File naming**: `snake_case.dart`
- **Class naming**: `PascalCase`
- **State management**: Use Riverpod (`ConsumerWidget`, `ConsumerStatefulWidget`)
- **Routing**: Use GoRouter with named routes
- **Static analysis**: Follow `flutter_lints` rules (configured in `analysis_options.yaml`)
- **Architecture**: Clean architecture with clear layer boundaries (config → data → domain → presentation)

### Python Worker

- **Type hints**: Required for all function signatures
- **Data models**: Use Pydantic for validation
- **Async/await**: Use for all I/O operations
- **File naming**: `snake_case.py`
- **Logging**: Use Python `logging` module, not print statements

## Testing Strategy

### Flutter Tests

Located in `app/test/`:
- `widget_test.dart` — App renders correctly with ProviderScope
- `unit/content_filter_service_test.dart` — Content filtering logic (4 tests)
- `unit/age_recommendation_service_test.dart` — Age bracket handling (6 tests)
- `unit/parental_control_service_test.dart` — PIN hashing, math problems (5 tests)

**Test execution:**
```bash
cd app
flutter test
```

### Python Tests

Located in `worker/tests/`:
- `test_providers.py` — Provider factory, result dataclasses (12 tests)
- `test_rate_limiter.py` — Rate limit enforcement (3 tests)

**Test execution:**
```bash
cd worker
python -m pytest tests/ -v
```

## Security Considerations

### Authentication & Authorization

- **Row-Level Security (RLS)**: All Supabase tables have RLS policies
- **PIN hashing**: SHA-256 with no plaintext storage
- **Biometric auth**: Face ID / fingerprint for sensitive transitions
- **Worker API**: Protected by `WORKER_API_KEY` bearer token
- **Rate limiting**: 10 requests/minute per user on worker API

### Data Protection (COPPA Compliance)

- Only parents create accounts (18+ required)
- Data minimization: Only name and DOB for children; no photos, location, or contacts
- Right to delete: Account deletion cascade removes all child data
- Auto-cleanup: Watch history deleted after 1 year
- No child PII shared with AI providers (analysis uses video metadata only)
- No child-to-child features (no social/chat)

### Build Security

- No secrets in git (`.env` files gitignored)
- `key.properties` for Android signing gitignored
- ProGuard/R8 minification enabled for release builds
- Certificate pinning infrastructure in place

## CI/CD Pipeline

**Pull Request / Push to main** (`.github/workflows/ci.yml`):
1. Flutter analyze + format check + tests
2. Build mobile APK (debug)
3. Build TV APK (debug)
4. Python worker tests
5. Security audit

**Release** (`.github/workflows/release.yml`):
Triggered by pushing `v*` tags:
```bash
git tag v1.0.0
git push origin v1.0.0
```
Builds signed release APKs and creates GitHub Release with artifacts.

## AI Analysis Pipeline

The 5-tier analysis funnel with early stopping:

| Tier | Name | Cost | Description | Threshold |
|------|------|------|-------------|-----------|
| 0 | Community Cache | $0 | Skip if already analyzed | — |
| 0.5 | Embedding Pre-Filter | ~$0.0001 | Vector similarity check | 0.85 |
| 1 | Text Analysis | ~$0.003 | Title, description, tags, transcript | 0.85 |
| 2 | Visual Analysis | ~$0.015 | Key frame analysis via vision model | 0.90 |
| 3 | Audio Analysis | ~$0.005 | Whisper + toxicity classifiers | — |

**Safety scores** (1-10 scale):
- `overstimulation_score` — Rapid editing, flashing lights
- `educational_score` — Learning value
- `scariness_score` — Monsters, jump scares
- `brainrot_score` — Mindless repetitive content
- `language_safety_score` — Profanity
- `violence_score` — Physical violence
- `audio_safety_score` — Disturbing sounds

## Key Conventions

### Supabase Client Access

Use the singleton wrapper:
```dart
import 'package:app/data/datasources/remote/supabase_client.dart';

final client = SupabaseClientWrapper.client;
final auth = SupabaseClientWrapper.auth;
```

### Biometric Authentication

Use `BiometricHelper` for sensitive transitions:
```dart
import 'package:app/utils/biometric_helper.dart';

final success = await BiometricHelper.authenticateForExitKidMode();
```

### Kid/Parent Mode Switching

- Child selection requires biometric auth → sets `currentChildProvider` → navigates to `/kid/*`
- Exiting kid mode requires biometric auth → returns to `/dashboard`
- Each mode applies its own theme (`KidTheme` / `ParentTheme`)

### Data Models

Currently plain Dart classes with manual serialization:
```dart
class VideoMetadata {
  Map<String, dynamic> toSupabaseRow() => {...};
  factory VideoMetadata.fromSupabaseRow(Map<String, dynamic> row) => ...;
}
```

Freezed + json_serializable dependencies are declared but not yet actively used.

## Troubleshooting

### Worker won't start
- Check `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are set
- Verify temp directory exists and is writable (`/tmp/baby_monitor_worker`)

### Flutter build fails
- Run `flutter clean && flutter pub get`
- Check `.env` file exists in `app/` directory
- Ensure Flutter 3.41+ is installed

### Database connection issues
- Verify Supabase project is active
- Check RLS policies allow the operation
- Ensure correct keys (anon for app, service_role for worker)

## Resources

- **README.md**: Full project documentation with setup instructions
- **CLAUDE.md**: Additional context for Claude Code
- **docs/coppa-compliance.md**: COPPA compliance details
- **Supabase Dashboard**: Manage database, auth, and edge functions
