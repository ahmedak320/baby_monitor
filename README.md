# Baby Monitor

[![Download Latest APK](https://img.shields.io/github/v/release/ahmedak320/baby_monitor?label=Download%20APK&logo=android&color=3DDC84&style=for-the-badge)](https://github.com/ahmedak320/baby_monitor/releases/latest)
[![CI](https://img.shields.io/github/actions/workflow/status/ahmedak320/baby_monitor/ci.yml?label=CI&logo=github&style=for-the-badge)](https://github.com/ahmedak320/baby_monitor/actions/workflows/ci.yml)

**AI-powered parental control app for safe YouTube viewing.** Kids get a familiar YouTube-like experience with vertical Shorts, video feeds, and dark mode — while every video is screened by a multi-tier AI pipeline before it ever reaches their screen.

Built with Flutter (iOS + Android + Web), a Python AI analysis worker, and Supabase (PostgreSQL + Auth + Realtime).

---

## Download & Install (Testers)

### Android (Samsung, Google Pixel, OnePlus, etc.)

1. **Download the APK** from the [latest release](https://github.com/ahmedak320/baby_monitor/releases/latest)
2. Open the downloaded `.apk` file on your phone
3. If prompted, tap **Settings** and enable "Allow from this source" (one-time)
4. Tap **Install**
5. Open **Baby Monitor** from your app drawer

> **Requirements:** Android 6.0 or higher. Works on Samsung Galaxy, Google Pixel, OnePlus, Xiaomi, and all other Android phones.

### iOS (iPhone)

iOS builds are not yet available for direct download. An Apple Developer account ($99/year) is required to distribute builds via TestFlight. This is planned for a future release.

For now, iOS testers can run the app on the **iOS Simulator** (requires a Mac with Xcode). See [Running on iOS Simulator](#running-on-ios-simulator) below.

---

## Table of Contents

- [Download & Install (Testers)](#download--install-testers)
- [Why Baby Monitor](#why-baby-monitor)
- [Features](#features)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Environment Setup](#environment-setup)
  - [Running the Flutter App](#running-the-flutter-app)
  - [Running the Python Worker](#running-the-python-worker)
  - [Running on Android Emulator](#running-on-android-emulator)
  - [Running on iOS Simulator](#running-on-ios-simulator)
  - [Installing on a Samsung / Android Phone](#installing-on-a-samsung--android-phone)
  - [Installing on an iPhone](#installing-on-an-iphone)
- [Database Setup (Supabase)](#database-setup-supabase)
- [AI Analysis Pipeline](#ai-analysis-pipeline)
- [AI Provider Configuration](#ai-provider-configuration)
- [Testing](#testing)
- [CI/CD](#cicd)
- [App Configuration](#app-configuration)
- [Security & COPPA Compliance](#security--coppa-compliance)
- [Freemium Model](#freemium-model)
- [Developer Mode](#developer-mode)
- [API Reference](#api-reference)
- [Database Schema](#database-schema)
- [Contributing](#contributing)
- [License](#license)

---

## Why Baby Monitor

YouTube Kids has limited content and a UI that older kids (8-12) find childish. Other parental controls (Bark, Qustodio, Net Nanny) filter reactively — they flag content *after* the kid watches it.

Baby Monitor is different:

- **Proactive filtering** — AI analyzes videos *before* they appear in the feed
- **YouTube-native UI** — Kids see the same dark theme, Shorts feed, and navigation they're used to
- **Age-adaptive** — Sensitivity settings auto-adjust as kids grow through 4 age brackets
- **Multi-provider AI** — Choose Claude, Gemini, OpenAI, or a local model for analysis
- **Community-powered** — Parents rate analysis accuracy, improving safety scores for everyone
- **COPPA compliant** — Data minimization, 1-year retention, right-to-delete, no child PII shared with third parties

---

## Features

### Kid Mode (YouTube-Mirror Interface)

| Tab | Description |
|-----|-------------|
| **Home** | Search bar, horizontal Shorts preview row, category chips (Educational, Nature, Fun, Cartoons, Music, etc.), YouTube-style video card grid |
| **Shorts** | Full-screen vertical swipe feed (PageView). Auto-play, screen time pill overlay, safety badges. "You're all caught up!" end card |
| **Library** | Watch history with thumbnails, time-ago labels, and tap-to-replay |
| **You** | Child avatar, screen time progress bar (green/orange/red), "Exit Kid Mode" button with parental gate |

**Screen time enforcement:**
- Daily limits with configurable duration
- Mandatory breaks (default: 5 min break every 30 min)
- Wind-down warning (countdown banner in last 5 minutes)
- Bedtime / before-wakeup lockout (configurable hours)
- Full-screen overlay screens for each state (break, time's up, bedtime)

**Parental gates (multi-layer):**
1. Biometric (Face ID / fingerprint)
2. PIN code (SHA-256 hashed, stored in Supabase)
3. Math problem fallback (for devices without biometrics)

### Parent Dashboard

- **Activity overview** — per-child stats: watch time, video count, filtered count
- **Channel management** — approve/block channels, suggested channels based on watch patterns
- **Filter settings** — per-child sensitivity sliders for 5 categories (overstimulation, scariness, brainrot, language, violence)
- **Screen time settings** — daily limits, break intervals, bedtime/wakeup hours
- **Content scheduling** — restrict content types to specific time blocks (premium)
- **Filtered content log** — see what was blocked and why
- **Age transition alerts** — notified when a child crosses an age bracket boundary
- **Account settings** — delete child profiles or full account (COPPA)
- **Subscription management** — free/premium tier display
- **Link submission** — manually submit a YouTube URL for priority analysis

### Onboarding (5-step guided setup)

1. **Welcome** — feature overview
2. **Add Child** — name, date of birth, avatar selection
3. **Filter Setup** — drag-to-rank safety priorities, per-concern sensitivity sliders
4. **Channel Suggestions** — curated list of 13 age-appropriate channels (Cocomelon, Sesame Street, National Geographic Kids, Mark Rober, etc.)
5. **Content Preferences** — toggle content types between allowed/preferred/blocked

### Smart Discovery

- **Auto-discovery** — worker searches Piped API every 6 hours for popular kids content across all age brackets
- **Embedding-based recommendations** — Gemini Embedding 2 computes video similarity; recommends unwatched videos similar to watch history
- **Channel auto-suggestion** — channels with 3+ approved videos surface as suggestions to parents

---

## Architecture

```
                    +------------------+
                    |   Flutter App    |
                    | (iOS / Android)  |
                    +--------+---------+
                             |
                    Supabase Auth + REST + Realtime
                             |
              +--------------+--------------+
              |                             |
    +---------v----------+       +----------v----------+
    |     Supabase       |       |   Python AI Worker  |
    | (PostgreSQL + RLS) |<----->|   (FastAPI server)   |
    | + Edge Functions   |       |   + Queue Consumer   |
    | + pgvector         |       |   + Auto-Discovery   |
    +--------------------+       +----------+-----------+
                                            |
                              +-------------+-------------+
                              |             |             |
                        Claude API    Gemini API    OpenAI API
                        (Haiku)       (Flash)       (GPT-4o)
```

**Three-component system:**

1. **Flutter App** — Parent dashboard + kid-safe YouTube viewer. Clean architecture: config / data / domain / presentation layers. State management via Riverpod, routing via GoRouter.

2. **Python AI Worker** — Polls Supabase `analysis_queue`, runs videos through a 5-tier analysis pipeline (cache → embedding → text → visual → audio), writes results back. Also serves FastAPI endpoints and runs periodic auto-discovery.

3. **Supabase** — PostgreSQL with Row-Level Security, Auth, Edge Functions, Realtime subscriptions, and pgvector for embedding similarity search.

---

## Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| **Mobile App** | Flutter / Dart | 3.11+ / 3.27+ |
| **State Management** | Riverpod | 2.6+ |
| **Routing** | GoRouter | 14.8+ |
| **Local Storage** | Hive | 2.2+ |
| **Video Player** | youtube_player_iframe | 5.0+ |
| **Auth & Security** | local_auth, crypto | 2.3+, 3.0+ |
| **Payments** | RevenueCat (purchases_flutter) | 8.3+ |
| **Backend** | Supabase (PostgreSQL + Auth + RLS) | 2.9+ |
| **Vector Search** | pgvector (Supabase extension) | — |
| **AI Worker** | Python + FastAPI + Uvicorn | 3.12+ |
| **AI Providers** | Claude Haiku, Gemini Flash, GPT-4o, Ollama | Latest |
| **Embeddings** | Gemini Embedding 2 (768-dim) | Preview |
| **Transcription** | faster-whisper | 1.0+ |
| **Toxicity** | detoxify + hatesonar | Latest |
| **Video Processing** | yt-dlp + opencv-python-headless | Latest |
| **CI/CD** | GitHub Actions | — |

---

## Project Structure

```
baby_monitor/
├── app/                              # Flutter application
│   ├── lib/
│   │   ├── main.dart                 # Entry point (Supabase, Hive, RevenueCat init)
│   │   ├── app.dart                  # MaterialApp with GoRouter + theme
│   │   ├── config/                   # App config, themes, constants, legal text
│   │   │   ├── theme/
│   │   │   │   ├── kid_theme.dart    # YouTube dark mode (#0F0F0F, #FF0000)
│   │   │   │   └── parent_theme.dart # Professional dashboard theme
│   │   │   ├── constants.dart        # Age brackets, content types, limits
│   │   │   └── legal_content.dart    # Privacy policy + Terms of Service
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── local/            # Hive caches (approved videos, preferences)
│   │   │   │   └── remote/           # Supabase, YouTube API, Piped API, Analysis API
│   │   │   ├── models/               # VideoMetadata, VideoAnalysis
│   │   │   └── repositories/         # Auth, Profile, Video, ScreenTime, Subscription, WatchHistory
│   │   ├── domain/services/          # 14 business logic services
│   │   ├── presentation/
│   │   │   ├── auth/                 # Login, Signup screens
│   │   │   ├── onboarding/           # 6-screen guided setup flow
│   │   │   ├── kid_mode/             # 10 screens (home tabs, player, search, overlays)
│   │   │   ├── parent_dashboard/     # 16 screens (dashboard, settings, analytics)
│   │   │   ├── community/            # Content reporting
│   │   │   └── common/widgets/       # Shared UI (video cards, badges, layouts)
│   │   ├── providers/                # 6 app-wide Riverpod providers
│   │   ├── routing/                  # GoRouter config + auth/setup/child guards
│   │   └── utils/                    # Biometric helper, age calculator, formatters
│   ├── test/                         # Unit + widget tests
│   ├── assets/icon/                  # App icon + splash screen assets
│   ├── android/                      # Android platform config
│   ├── ios/                          # iOS platform config
│   └── pubspec.yaml                  # Dependencies (22 runtime + 10 dev)
│
├── worker/                           # Python AI analysis worker
│   ├── main.py                       # Entry point (FastAPI + consumer + discovery)
│   ├── config.py                     # All config fields from .env
│   ├── pipeline/                     # 5-tier analysis pipeline
│   │   ├── orchestrator.py           # Pipeline coordinator with early stopping
│   │   ├── tier0_cache.py            # Community cache lookup (free)
│   │   ├── tier05_embedding.py       # Gemini Embedding 2 similarity (fast-track)
│   │   ├── tier1_text.py             # Text analysis via AI provider (~$0.003)
│   │   ├── tier2_visual.py           # Frame analysis via AI vision (~$0.015)
│   │   └── tier3_audio.py            # Whisper + classifiers (~$0.005)
│   ├── providers/                    # AI provider abstraction (Claude/Gemini/OpenAI/Local)
│   ├── analyzers/                    # Specialized classifiers (toxicity, violence, NSFW, etc.)
│   ├── extractors/                   # Frame, audio, caption extraction
│   ├── discovery/                    # Auto-discovery + recommendation engine
│   ├── api/                          # FastAPI routes + rate limiter
│   ├── queue/                        # Supabase queue consumer + priority logic
│   ├── tests/                        # pytest test suite
│   └── requirements.txt              # Python dependencies
│
├── supabase/
│   ├── migrations/                   # 8 SQL migration files (schema, functions, RLS)
│   └── functions/                    # Edge functions (aggregate-ratings)
│
├── docs/
│   ├── coppa-compliance.md           # COPPA data map + compliance checklist
│   └── superpowers/specs/            # Design specification
│
├── .codex/README.md                  # Codex project-file convention
├── .github/workflows/ci.yml         # CI pipeline (Flutter + Python)
├── .env.example                      # Root env template
└── CLAUDE.md                         # Claude Code project context
```

---

## Getting Started

### Prerequisites

| Tool | Version | Required For |
|------|---------|-------------|
| **Flutter SDK** | 3.27+ | Mobile app |
| **Dart SDK** | 3.11+ | (Bundled with Flutter) |
| **Android Studio** | Latest | Android builds + emulator |
| **Xcode** | 15+ | iOS builds + simulator (macOS only) |
| **Python** | 3.12+ | AI worker |
| **Supabase account** | Free tier works | Database + auth |
| **Git** | Latest | Version control |

**Optional:**
- Google account with YouTube Data API v3 key (for live YouTube search)
- Anthropic API key (for Claude analysis)
- Google AI API key (for Gemini analysis + embeddings)
- OpenAI API key (for GPT-4 analysis)
- Apple Developer account ($99/year — required for iPhone deployment)

### Environment Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ahmedak320/baby_monitor.git
   cd baby_monitor
   ```

2. **Create environment files from templates:**
   ```bash
   # Root .env (for worker)
   cp .env.example .env

   # App .env (for Flutter)
   cp app/.env.example app/.env
   ```

3. **Fill in your credentials in both `.env` files.** At minimum you need:
   - `SUPABASE_URL` and `SUPABASE_ANON_KEY` (from your Supabase project dashboard → Settings → API)
   - `SUPABASE_SERVICE_ROLE_KEY` (for the worker — same dashboard, under "service_role")

4. **Install Flutter dependencies:**
   ```bash
   cd app
   flutter pub get
   ```

5. **Install Python dependencies (for the worker):**
   ```bash
   cd worker
   pip install -r requirements.txt
   ```

### Running the Flutter App

```bash
cd app

# Check your setup
flutter doctor

# Run on the first available device/emulator
flutter run --flavor mobile --dart-define-from-file=.env

# Run on a specific device
flutter devices              # List available devices
flutter run -d <device-id> --flavor mobile --dart-define-from-file=.env
```

### Running the Python Worker

```bash
cd worker
python main.py
```

This starts three concurrent processes:
- **FastAPI server** on `http://localhost:8000` (3 endpoints)
- **Queue consumer** polling Supabase every 10 seconds for videos to analyze
- **Auto-discovery** searching for popular kids content every 6 hours

### Running on Android Emulator

1. **Open Android Studio** → Tools → Device Manager → Create Virtual Device
2. Select a phone (e.g., Pixel 7) → Download a system image (API 34 recommended) → Finish
3. Start the emulator from Device Manager
4. Run the app:
   ```bash
   cd app
   flutter run -d emulator-5554 --flavor mobile --dart-define-from-file=.env
   ```
   (The device ID is shown by `flutter devices`)

**Alternatively, from the command line:**
```bash
# List available AVDs
emulator -list-avds

# Start an emulator
emulator -avd <avd-name> &

# Run the app
cd app && flutter run --flavor mobile --dart-define-from-file=.env
```

### Running on iOS Simulator

> Requires macOS with Xcode 15+ installed.

1. **Open Xcode** → Settings → Platforms → Install an iOS simulator runtime (iOS 17+ recommended)
2. **Open Simulator app** or run from terminal:
   ```bash
   open -a Simulator
   ```
3. Choose a device: File → Open Simulator → iPhone 15 Pro (or any model)
4. Run the app:
   ```bash
   cd app
   flutter run -d "iPhone 15 Pro" --dart-define-from-file=.env
   ```

**First-time iOS setup:**
```bash
cd app/ios
pod install    # Install CocoaPods dependencies (auto-generated by Flutter)
cd ..
flutter run --dart-define-from-file=.env
```

### Installing on a Samsung / Android Phone

#### Debug Build (for testing — no signing required)

1. **Enable Developer Options on your phone:**
   - Go to Settings → About Phone → tap "Build Number" 7 times
   - Go back to Settings → Developer Options → enable "USB Debugging"

2. **Connect your phone via USB cable**

3. **Verify the phone is detected:**
   ```bash
   flutter devices
   # Should show something like: SM G998B (mobile) • R5CR...  • android-arm64 • Android 14
   ```

4. **Build and install:**
   ```bash
   cd app

   # Option A: Build and run directly
   flutter run -d <device-id> --dart-define-from-file=.env

   # Option B: Build APK and install manually
   flutter build apk --debug --flavor mobile --dart-define-from-file=.env
   adb install build/app/outputs/flutter-apk/app-mobile-debug.apk
   ```

5. **The app will launch on your phone.** Grant permissions when prompted (biometric, internet).

#### Release Build (for distribution)

1. **Create a signing keystore:**
   ```bash
   keytool -genkey -v \
     -keystore ~/upload-keystore.jks \
     -keyAlias upload \
     -keyAlg RSA \
     -keySize 2048 \
     -validity 10000
   ```

2. **Create `app/android/key.properties`** (see `key.properties.example`):
   ```properties
   storePassword=your_password
   keyPassword=your_password
   keyAlias=upload
   storeFile=/home/yourusername/upload-keystore.jks
   ```

3. **Build the release APK:**
   ```bash
   cd app
   flutter build apk --release
   ```

4. **Install on your phone:**
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

#### Wireless Debugging (no cable)

```bash
# On your phone: Developer Options → Wireless Debugging → ON
# Note the IP and port shown

adb connect 192.168.x.x:port
flutter run -d 192.168.x.x:port
```

### Installing on an iPhone

> Requires a Mac with Xcode 15+. Physical device deployment requires an Apple Developer account.

#### On iOS Simulator (free, no Apple account needed)

```bash
cd app
flutter run -d "iPhone 15 Pro"
```

#### On a Physical iPhone

1. **Enroll in the Apple Developer Program** ($99/year) at [developer.apple.com](https://developer.apple.com)

2. **Open the iOS project in Xcode:**
   ```bash
   cd app/ios
   open Runner.xcworkspace
   ```

3. **Configure signing in Xcode:**
   - Select the "Runner" target → Signing & Capabilities
   - Check "Automatically manage signing"
   - Select your Team (your Apple Developer account)
   - Xcode will create a provisioning profile automatically

4. **Connect your iPhone via USB cable**
   - On iPhone: Settings → General → VPN & Device Management → trust your developer certificate (first time only)

5. **Build and run:**
   ```bash
   cd app
   flutter run -d <iphone-device-id>
   ```
   Or press the Play button in Xcode.

#### Distributing via TestFlight (beta testing)

1. Build an archive in Xcode: Product → Archive
2. Upload to App Store Connect via Xcode Organizer
3. In App Store Connect → TestFlight → add testers by email
4. Testers install via the TestFlight app on their iPhones

---

## Database Setup (Supabase)

1. **Create a project** at [supabase.com](https://supabase.com) (free tier works)

2. **Run migrations in order** — go to SQL Editor in your Supabase dashboard and run each file:
   ```
   supabase/migrations/001_initial_schema.sql       # 18 tables, RLS policies
   supabase/migrations/002_community_functions.sql   # Trust scores, usage tracking
   supabase/migrations/003_analytics_events.sql      # Analytics + beta feedback
   supabase/migrations/004_video_discovery.sql       # Discovery metadata, Shorts
   supabase/migrations/005_shorts_support.sql        # is_short column + index
   supabase/migrations/006_embedding_support.sql     # pgvector + similarity search
   supabase/migrations/007_rate_limiting.sql         # Rate limits, data cleanup
   supabase/migrations/008_parent_account_deletion.sql # COPPA account deletion
   ```

3. **Deploy the edge function:**
   ```bash
   supabase functions deploy aggregate-ratings
   ```

4. **Copy your credentials** from Supabase Dashboard → Settings → API into your `.env` files.

**Key tables (26 total):**

| Category | Tables |
|----------|--------|
| **Users** | `parent_profiles`, `child_profiles`, `devices`, `subscriptions` |
| **Content** | `yt_videos`, `yt_channels`, `video_analyses`, `analysis_queue` |
| **Curation** | `parent_channel_prefs`, `parent_video_overrides`, `content_preferences` |
| **Tracking** | `watch_history`, `filtered_log`, `screen_time_rules`, `screen_time_sessions` |
| **Community** | `community_ratings` |
| **Premium** | `content_schedules`, `offline_playlists` |
| **System** | `analytics_events`, `beta_feedback`, `video_interruptions`, `parent_link_submissions` |

All tables have Row-Level Security policies. Parents can only access their own data and their children's data.

---

## AI Analysis Pipeline

Videos pass through a 5-tier funnel with early stopping when confidence is high enough:

| Tier | Name | Cost | What it Does | Confidence Threshold |
|------|------|------|-------------|---------------------|
| **0** | Community Cache | $0 | Lookup existing analysis. Skip if found. | — |
| **0.5** | Embedding Pre-Filter | ~$0.0001 | Gemini Embedding 2 cosine similarity against known-safe/unsafe vectors | 0.85 |
| **1** | Text Analysis | ~$0.003 | Analyze title, description, tags, transcript via LLM | 0.85 |
| **2** | Visual Analysis | ~$0.015 | Extract 10-15 key frames, analyze each via vision model | 0.90 |
| **3** | Audio Analysis | ~$0.005 | Whisper transcription + toxicity/hate speech classifiers | — |

**Safety scores produced (1-10 scale):**

| Score | What it Measures |
|-------|-----------------|
| `overstimulation_score` | Rapid editing, flashing lights, sensory overload |
| `educational_score` | Learning value, educational content quality |
| `scariness_score` | Monsters, jump scares, dark themes |
| `brainrot_score` | Mindless repetitive content, low-effort videos |
| `language_safety_score` | Profanity, inappropriate language |
| `violence_score` | Physical violence, aggression |
| `audio_safety_score` | Audio content safety (screaming, disturbing sounds) |

**Verdict values:** `APPROVE`, `REJECT`, `PENDING`, `NEEDS_VISUAL_REVIEW`, `NEEDS_AUDIO_REVIEW`

---

## AI Provider Configuration

Set the `AI_PROVIDER` environment variable in the worker's `.env`:

| Provider | Value | Model Used | Cost per Analysis | Notes |
|----------|-------|-----------|------------------|-------|
| **Claude** | `claude` | Haiku 3.5 | ~$0.003 text, ~$0.015 vision | Best reasoning quality |
| **Gemini** | `gemini` | Flash 2.0 | ~$0.0001 text, ~$0.001 vision | Cheapest, fastest |
| **OpenAI** | `openai` | GPT-4o-mini / GPT-4o | ~$0.003 text, ~$0.01 vision | Good balance |
| **Local** | `local` | Ollama (any model) | $0 | Vision limited, text only |

All providers implement the same `AnalysisProvider` interface and produce identical output format.

---

## Testing

### Flutter Tests

```bash
cd app

# Run all tests
flutter test

# Run a specific test file
flutter test test/unit/content_filter_service_test.dart

# Run with verbose output
flutter test --reporter expanded
```

**Test suite (17 tests):**
- `test/widget_test.dart` — App renders without crashing, ProviderScope wraps correctly
- `test/unit/content_filter_service_test.dart` — Approve/reject/blacklist/confidence gating (4 tests)
- `test/unit/age_recommendation_service_test.dart` — Age bracket defaults, required keys, value ranges (6 tests)
- `test/unit/parental_control_service_test.dart` — PIN hashing, uniqueness, math problems (5 tests)

### Flutter Static Analysis

```bash
cd app
flutter analyze
# Expected: 0 errors, 0 warnings (2 info-level hints)
```

### Python Worker Tests

```bash
cd worker

# Run all tests
python -m pytest tests/ -v

# Run specific test file
python -m pytest tests/test_providers.py -v
```

**Test suite (12 tests):**
- `tests/test_providers.py` — Provider factory, result dataclasses, local provider behavior (12 tests)
- `tests/test_rate_limiter.py` — Rate limit enforcement, health bypass (3 tests)

---

## CI/CD

GitHub Actions pipeline (`.github/workflows/ci.yml`) runs on every push/PR to `main`:

| Job | Steps | Artifact |
|-----|-------|----------|
| **flutter-analyze-test** | `pub get` → `flutter analyze` → `flutter test` | — |
| **flutter-build-android** | Java 17 + Flutter → `flutter build apk --debug` | `debug-apk` |
| **python-worker-test** | Python 3.12 → `pip install` → `pytest tests/ -v` | — |

The Android build job depends on analyze+test passing first. Python tests run in parallel.

### Release Builds (Downloadable APK for Testers)

A separate workflow (`.github/workflows/release.yml`) builds a **signed release APK** whenever a version tag is pushed:

```bash
git tag v1.0.1
git push origin v1.0.1
```

Within ~5 minutes, a new [GitHub Release](https://github.com/ahmedak320/baby_monitor/releases) appears with the APK attached. Testers download it directly — no build tools needed.

**How it works:** The workflow decodes the signing keystore from GitHub Secrets, creates `key.properties`, builds with ProGuard minification, and publishes via `softprops/action-gh-release`.

**Required GitHub Secrets:** `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`, `ENV_FILE`

---

## App Configuration

### Age Brackets

| Bracket | Age | Default Sensitivity | Max Video Duration |
|---------|-----|--------------------|--------------------|
| **Toddler** | 0-2 | Very strict (8-9/10) | 15 min |
| **Preschool** | 3-5 | Strict (7/10) | 25 min |
| **Early School** | 5-8 | Moderate (5-6/10) | 30 min |
| **Older Kids** | 8-12 | Relaxed (4-5/10) | 45 min |

Sensitivity settings are per-child and adjustable by parents. When a child crosses a bracket boundary, the parent receives a notification with suggested new defaults.

### Content Categories

Educational, Nature, Cartoons, Music, Storytime, Fun, Soothing, Creative

Parents can set each to: **Allowed** (default), **Preferred** (boosted in feed), or **Blocked** (filtered out).

### Screen Time Defaults

- **Break interval:** 30 minutes of watching → 5 minute mandatory break
- **Wind-down warning:** Shows countdown banner in the last 5 minutes
- **Bedtime:** 9:00 PM (configurable)
- **Wake-up:** 7:00 AM (configurable)

---

## Security & COPPA Compliance

### Security Measures

- **Row-Level Security (RLS)** — Every Supabase table has policies isolating parent data
- **PIN hashing** — SHA-256 with no plaintext storage
- **Biometric auth** — Face ID / fingerprint for kid mode transitions
- **Web biometric disabled** — Forces PIN fallback on web (no false `true` return)
- **Rate limiting** — 10 requests/minute per user on worker API (sliding window)
- **Community anti-gaming** — 100 ratings/day cap, 20 pending analyses/user cap
- **API key auth** — Worker endpoints protected by `WORKER_API_KEY` bearer token
- **Certificate pinning ready** — Supabase CA pinning infrastructure in place
- **ProGuard/R8** — Release builds minified with keep rules for all dependencies
- **No secrets in git** — `.env` files gitignored, `key.properties` gitignored

### COPPA Compliance

- **Parental consent** — Only parents create accounts (18+ required)
- **Data minimization** — Only name and DOB collected for children; no photos, location, contacts, or voice
- **Right to delete** — Account Settings screen with "Delete Child Profile" and "Delete My Account" buttons
- **Auto-cleanup** — `cleanup_old_watch_history()` deletes records older than 1 year
- **No child PII to third parties** — AI analysis uses video metadata only, not child profiles
- **No child-to-child features** — No social, chat, or sharing between children
- **Privacy policy** — Full COPPA-compliant privacy policy accessible in-app (About → Privacy Policy)

See [`docs/coppa-compliance.md`](docs/coppa-compliance.md) for the full data map and implementation checklist.

---

## Freemium Model

| Feature | Free | Premium |
|---------|------|---------|
| AI analyses per month | 50 | Unlimited |
| Child profiles | 1 | Unlimited |
| Screen time management | Basic | Full |
| Content scheduling | No | Yes |
| Offline playlists | No | Yes |
| Community ratings | Yes | Yes |
| All safety filters | Yes | Yes |

Payment processing uses RevenueCat (`purchases_flutter`). For development/testing, use [Developer Mode](#developer-mode) to toggle tiers without a real subscription.

---

## Developer Mode

Access: About screen → tap version number 7 times (debug builds only).

| Setting | What it Does |
|---------|-------------|
| **Subscription Tier** | Toggle between Free and Premium for testing feature gates |
| **Reset Analysis Count** | Reset monthly usage counter to 0 |
| **AI Provider** | Switch between Claude, Gemini, OpenAI, Local for analysis testing |
| **Skip Biometric** | Bypass biometric gates during development |

---

## API Reference

The worker exposes 4 FastAPI endpoints on port 8000. All endpoints except `/api/health` require `Authorization: Bearer <WORKER_API_KEY>` header.

### `GET /api/health`
Returns worker status. Bypasses rate limiting.
```json
{"status": "ok", "worker": "baby-monitor-analysis"}
```

### `POST /api/analyze`
Trigger analysis for a video.
```json
// Request
{"video_id": "dQw4w9WgXcQ"}

// Response
{
  "video_id": "dQw4w9WgXcQ",
  "age_min_appropriate": 0,
  "age_max_appropriate": 18,
  "overstimulation_score": 2.0,
  "educational_score": 3.0,
  "scariness_score": 1.0,
  "brainrot_score": 4.0,
  "language_safety_score": 9.0,
  "violence_score": 1.0,
  "audio_safety_score": 9.0,
  "content_labels": ["music"],
  "detected_issues": [],
  "confidence": 0.92,
  "overall_verdict": "APPROVE"
}
```

### `GET /api/analysis/{video_id}`
Retrieve cached analysis result.

### `GET /api/recommendations/{child_id}?limit=20`
Get personalized video recommendations based on watch history embeddings.

**Rate limit:** 10 requests per minute per user (429 Too Many Requests when exceeded).

---

## Database Schema

### Entity Relationship (key tables)

```
parent_profiles 1──* child_profiles
parent_profiles 1──* parent_channel_prefs
parent_profiles 1──* parent_video_overrides
parent_profiles 1──1 subscriptions
child_profiles  1──* watch_history
child_profiles  1──* screen_time_sessions
child_profiles  1──* screen_time_rules
child_profiles  1──* content_preferences
child_profiles  1──* filtered_log
yt_channels     1──* yt_videos
yt_videos       1──1 video_analyses
video_analyses  1──* community_ratings
```

### Key SQL Functions

| Function | Purpose |
|----------|---------|
| `handle_new_user()` | Trigger: auto-creates `parent_profiles` + `subscriptions` on signup |
| `update_channel_trust_scores()` | Averages confidence across 3+ videos per channel |
| `increment_analysis_usage(user_id)` | Tracks monthly analysis count for freemium |
| `get_community_consensus(video_id)` | Aggregates community rating votes |
| `match_video_embeddings(vector, threshold, count)` | pgvector cosine similarity search |
| `check_rating_rate_limit(user_id)` | Enforces 100 ratings/day cap |
| `check_queue_limit(user_id)` | Enforces 20 pending analyses cap |
| `delete_child_data(child_id)` | Cascade-deletes all child data (COPPA) |
| `delete_parent_account(user_id)` | Cascade-deletes entire account (COPPA) |
| `cleanup_old_watch_history()` | Removes records older than 1 year |
| `reset_monthly_analysis_counters()` | Resets free-tier usage (run monthly) |

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Run tests: `cd app && flutter analyze && flutter test`
5. Commit with a descriptive message
6. Push and open a Pull Request

**Code style:**
- Flutter: follow `flutter_lints` rules, use Riverpod for state, GoRouter for navigation
- Python: type hints required, Pydantic for models, async/await for I/O
- File naming: `snake_case` everywhere

---

## License

This project is proprietary. All rights reserved.

---

Built with Flutter, Supabase, and multi-provider AI analysis.
