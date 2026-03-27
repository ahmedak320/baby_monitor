# Baby Monitor v2 — Design Specification

## Context

The Baby Monitor app is a Flutter + Supabase + Python AI worker system that provides kid-safe YouTube viewing with AI-powered content analysis. The app has a solid architecture (4-tier analysis pipeline, community consensus, per-child sensitivity, RLS-protected database) but has 6 unfinished TODOs, incomplete features (category filtering, content scheduling, PIN verification), no automated tests, and a kid-mode UI that doesn't match what kids expect from a video app.

**Problem:** The app needs to be production-ready for testing on real iOS and Android devices. Kids expect a YouTube-like experience (especially Shorts), not a custom "kid app" UI. The AI pipeline is locked to a single provider (Claude Haiku). Security gaps exist in authentication fallbacks, rate limiting, and COPPA compliance.

**Goal:** Complete all features, fix all bugs, mirror YouTube's UI with Shorts-first design, add multi-provider AI support, harden security, build comprehensive tests, and deploy to real devices for testing.

**Non-goals:** App Store publication (later), real payment processing (keep code, add dev toggle), offline video downloads (deferred).

---

## Phase 1: Foundation — Fix Everything Broken

### 1.1 TODO Fixes

**PIN Verification (CRITICAL)**
- File: `app/lib/presentation/kid_mode/widgets/biometric_switch.dart:66`
- Complete the PIN hash verification against `parent_profiles.pin_hash`
- Auth chain: biometric → PIN dialog → math gate fallback
- Use existing `ParentalControlService.verifyPin()` and `hashPin()` from `domain/services/parental_control_service.dart`

**Missing childId in Routes (HIGH)**
- File: `app/lib/routing/app_router.dart:122,130`
- Wire `currentChildProvider` into ScreenTimeSettingsScreen and ContentScheduleScreen routes
- Both screens already accept `childId` parameter, just need the provider value passed through

**Category Filter Not Wired (HIGH)**
- File: `app/lib/presentation/kid_mode/screens/kid_home_screen.dart:97`
- Wire category bubble tap to `FeedCurationService` filter
- Add `selectedCategory` state to the screen, pass to `getApprovedVideos()` call
- Categories already defined in the UI — connect selection to data query

**RevenueCat Paywall Stub (MEDIUM)**
- File: `app/lib/presentation/parent_dashboard/screens/subscription_screen.dart:107`
- Keep RevenueCat dependency and all subscription code
- Replace the TODO launch with a message: "Payments coming soon. Use Dev Settings to test premium features."
- Dev Settings toggle controls the tier (see 1.2)

**Widget Smoke Test (MEDIUM)**
- File: `app/test/widget_test.dart`
- Replace placeholder with actual `WidgetTester` that pumps `MyApp` and verifies it renders without error
- Full test suite comes in Phase 6

**Content Schedule Integration (LOW)**
- File: content_schedule_screen receives empty `childId`
- Fixed by the routing fix above (1.1 item 2)
- Verify `FeedCurationService` correctly applies schedule rules when childId is present

### 1.2 Dev/Test Mode

**Access:** 7-tap on version number in About screen (standard Android/iOS developer mode pattern)

**Settings panel provides:**
- **Subscription Tier Toggle** — switch between `free` and `premium` in Supabase `subscriptions` table for current user. Calls `subscriptionRepository.updateTier(tier)`.
- **Analysis Count Reset** — sets `monthly_analyses_used` to 0 for current user
- **AI Provider Selector** — choose Claude/Gemini/OpenAI/Local (stored in `.env` override, communicated to worker via Supabase `devices` table metadata)
- **Skip Biometric Auth** — boolean flag in `PreferencesCache` that `BiometricHelper` checks first
- **Simulate Child Age** — override current child's DOB to test age-specific filtering at ages 3, 6, 9, 12

**Implementation:** New screen `app/lib/presentation/parent_dashboard/screens/dev_settings_screen.dart`. Uses existing `SubscriptionRepository`, `ProfileRepository`, `PreferencesCache`. Gate behind `kDebugMode` or a compile-time flag so it never ships to production.

### 1.3 Cleanup

- Remove unused imports flagged by `flutter analyze`
- Ensure all existing Dart files pass `flutter analyze` with zero warnings
- Fix any deprecated API usage in dependencies

---

## Phase 2: YouTube-Mirror UI

### 2.1 Navigation Restructure

Replace current kid mode navigation with YouTube-style 4-tab bottom navigation:

| Tab | Icon | Content |
|-----|------|---------|
| Home | House | Shorts preview row + video grid (mixed feed) |
| Shorts | Fire/Lightning | Full-screen vertical swipe Shorts feed |
| Library | Book | Watch history + saved/liked videos |
| You | Person | Child profile, screen time stats, settings access |

**Files to modify:**
- `app/lib/presentation/kid_mode/screens/kid_home_screen.dart` — restructure as tab host
- New: `app/lib/presentation/kid_mode/screens/shorts_feed_screen.dart`
- New: `app/lib/presentation/kid_mode/screens/kid_library_screen.dart`
- New: `app/lib/presentation/kid_mode/screens/kid_profile_screen.dart`
- `app/lib/routing/app_router.dart` — add routes for new tabs

### 2.2 Shorts Vertical Swipe Feed

**Primary experience.** Uses Flutter `PageView` with `scrollDirection: Axis.vertical`.

**Architecture:**
- `ShortsFeedScreen` — StatefulWidget wrapping PageView
- `ShortsFeedProvider` (Riverpod) — manages the pre-filtered Shorts pool, handles pagination
- `ShortsPlayerWidget` — individual Short display: YouTube iframe player (full-screen), action buttons overlay, creator info overlay, safety badge
- `ShortsPreloadManager` — preloads next 2 Shorts for instant swipe

**Content source:** Query `yt_videos` where `is_short = true` AND video passes `ContentFilterService` for current child. Pool managed by `FeedCurationService` with Shorts-specific logic.

**Data model change:** Add `is_short BOOLEAN DEFAULT false` to `yt_videos` table if not present. The existing `VideoMetadata.detectedAsShort` heuristic (≤60s or #shorts in title) populates this.

**Key behaviors:**
- Pre-filtered only — every Short in the feed has already passed AI analysis
- Screen time overlay — subtle pill in top-right showing remaining time
- Winddown/break/bedtime overlays block playback (reuse existing overlay widgets)
- No comments, no external links, no unfiltered recommendations
- Like button is cosmetic (stores preference locally for recommendation engine)
- Bounded infinite scroll — when pre-filtered pool runs low, show "More coming soon!" card
- Auto-pause when swiped away, auto-play when swiped to

### 2.3 Home Tab Redesign

Mirror YouTube's home tab:
- **Top:** Search bar with voice search icon (uses existing `kid_search_screen.dart` flow)
- **Shorts row:** Horizontal scroll of Shorts thumbnails (tall aspect ratio cards). Tap opens Shorts feed at that position.
- **Category chips:** Horizontal scroll of category filters (All, Music, Gaming, Science, Crafts, Animals, Cartoons, Educational). Wired to `FeedCurationService` category filter (Phase 1 fix).
- **Video grid:** Standard YouTube-style list of video cards (thumbnail, channel avatar, title, channel name, view count, age). Uses existing `video_card.dart` widget, restyled to match YouTube's dark theme.

### 2.4 Library Tab

- **Watch History** — query `watch_history` for current child, display as reverse-chronological list
- **Liked Videos** — videos the child tapped "like" on (stored locally in Hive, synced to Supabase)
- Create new `WatchHistoryRepository` in `app/lib/data/repositories/watch_history_repository.dart` — queries `watch_history` table for current child, returns list of `VideoMetadata`

### 2.5 Profile Tab ("You")

- Child's avatar and name
- Screen time summary (today's usage, daily limit, streak of days under limit)
- Content preferences (what categories they watch most — auto-computed)
- Parent exit button (biometric → PIN → math gate chain)

### 2.6 Theme

- **Dark theme** matching YouTube's `#0f0f0f` background, `#212121` cards, `#fff` text
- Reuse existing `kid_theme.dart` but override colors to match YouTube dark mode
- Typography: Roboto (Flutter default, same as YouTube)
- No childish fonts, colors, or decorations — the safety is invisible

### 2.7 Parent Dashboard Updates

Minimal changes:
- Add Shorts vs Videos breakdown in `child_activity_screen.dart`
- Add approved channels section in `channel_management_screen.dart` (for Phase 4)
- Wire dev settings access from About screen (Phase 1)

---

## Phase 3: Multi-Provider AI

### 3.1 Provider Abstraction

Create `worker/providers/base_provider.py`:

```python
class AnalysisProvider(ABC):
    @abstractmethod
    async def analyze_text(self, text: str, metadata: dict) -> AnalysisResult: ...

    @abstractmethod
    async def analyze_image(self, frames: list[bytes]) -> AnalysisResult: ...

    @abstractmethod
    def get_cost_per_analysis(self) -> float: ...

    @abstractmethod
    def get_provider_name(self) -> str: ...
```

**Implementations:**
- `worker/providers/claude_provider.py` — wraps existing `haiku_text_analyzer` and `haiku_vision_analyzer`
- `worker/providers/gemini_provider.py` — uses `google-generativeai` SDK, Gemini 2.0 Flash for text, Gemini 2.0 Flash for vision
- `worker/providers/openai_provider.py` — uses `openai` SDK, GPT-4o-mini for text, GPT-4o for vision
- `worker/providers/local_provider.py` — stub that calls a local HTTP endpoint (e.g., Ollama) for text analysis

**Selection:** `AI_PROVIDER` env var. `worker/config.py` reads it. `pipeline/orchestrator.py` instantiates the selected provider.

### 3.2 Gemini Embedding 2 (Tier 0.5)

New tier in the analysis pipeline, between Tier 0 (cache) and Tier 1 (text analysis):

**How it works:**
1. Compute embedding vector for the video's title + description + transcript (if available) using `gemini-embedding-2-preview`
2. Compare against a vector database of already-analyzed videos using cosine similarity
3. If similarity > 0.92 to a known-safe video → fast-track as safe (confidence 0.88)
4. If similarity > 0.92 to a known-unsafe video → fast-track as unsafe (confidence 0.88)
5. Otherwise → continue to Tier 1

**Storage:** Add `embedding VECTOR(768)` column to `video_analyses` table (Supabase supports pgvector). Store embedding alongside analysis results.

**Cost:** Gemini Embedding 2 is significantly cheaper than Claude Haiku text analysis (~10x cheaper), so this tier saves money on videos similar to already-analyzed content.

**File:** `worker/pipeline/tier05_embedding.py`

### 3.3 Cost Tracking Per Provider

Extend existing `worker/utils/cost_tracker.py`:
- Track cost per provider (Claude, Gemini, OpenAI)
- Track cost per tier (0, 0.5, 1, 2, 3)
- Daily/monthly aggregation
- Log to Supabase `analysis_costs` table (new)

---

## Phase 4: Smart Discovery

### 4.1 Parent-Approved Channels

**Existing infrastructure:** `parent_channel_prefs` table already supports per-channel approval/blocking.

**New UI in parent dashboard:**
- "Approved Channels" section in `channel_management_screen.dart`
- Search for channels by name, see channel trust score, star to approve
- Suggested channels: channels that other parents with similar-age children approve (from community data)
- Channel auto-suggestion: when a child watches 3+ videos from an unapproved channel that all pass analysis, suggest the channel to the parent

### 4.2 Watch-History Recommendations

**Algorithm:**
1. Take the child's last 50 approved watch history entries
2. Compute average embedding vector (using Gemini Embedding 2) of those videos
3. Find un-watched videos in the `video_analyses` table with high similarity to the average vector
4. Filter through `ContentFilterService` for the child's sensitivity settings
5. Rank by: similarity score (0.4) + recency (0.2) + channel trust (0.2) + category diversity bonus (0.2)

**File:** `worker/discovery/recommendation_engine.py`

**Integration:** `FeedCurationService` calls recommendation endpoint when building the feed.

### 4.3 Feed Composition

The kid's feed is assembled from weighted sources:

| Source | Weight | Description |
|--------|--------|-------------|
| Approved channels | 40% | New content from parent-starred channels |
| Watch-history similar | 30% | Embedding-similar to previously enjoyed content |
| Trending safe | 20% | Popular videos that pass analysis (from auto-discovery) |
| Discovery | 10% | New channels/content the child hasn't seen, passing analysis |

Weights are configurable per parent in `content_preferences` table.

---

## Phase 5: Security & COPPA

### 5.1 Authentication Hardening

- **Complete PIN verification chain:** biometric → PIN dialog → math gate (Phase 1 fix)
- **PIN complexity:** enforce 4-6 digits, stored as SHA-256 hash in `parent_profiles.pin_hash`
- **Biometric on web:** currently returns `true` (insecure). Change to require PIN on web since biometrics unavailable.
- **Session timeout:** auto-lock kid mode after 4 hours of continuous use, require re-auth

### 5.2 Network Security

- **Certificate pinning:** Pin Supabase and worker API TLS certificates using `dio`'s `SecurityContext`. Pin the CA certificate, not the leaf (allows rotation).
- **HTTPS enforcement:** ensure all API calls use HTTPS (already the case via Supabase SDK, verify Piped API and worker)
- **API key rotation:** document process for rotating `WORKER_API_KEY`, `YOUTUBE_API_KEY`, `SUPABASE_ANON_KEY`

### 5.3 Rate Limiting

- **Worker API:** max 10 analysis requests/minute per user (implement in FastAPI middleware)
- **Community ratings:** max 100 ratings/day per user (Supabase RLS or edge function check)
- **Analysis queue:** max 20 queued items per user (prevent queue flooding)

### 5.4 Community Rating Anti-Gaming

- Require minimum 30 seconds of watch time before allowing a rating
- Detect vote flooding: if a user rates >10 videos in 5 minutes, flag for review
- Weight ratings by parent account age and rating history consistency
- Outlier detection: ratings that differ significantly from community consensus are weighted lower

### 5.5 Input Sanitization

- Audit all user-facing text inputs (child name, search queries, feedback text)
- Supabase parameterized queries already prevent SQL injection — verify no raw string concatenation
- Sanitize display of user-generated content (channel names, video titles from YouTube) to prevent XSS in Flutter (Flutter's Text widget is inherently XSS-safe, but verify WebView/iframe contexts)

### 5.6 COPPA Compliance

**Data map document:** catalog all data collected, purpose, storage location, retention period, third-party sharing.

**Key requirements (April 22, 2026 deadline):**
- Parental consent: verify parent identity before collecting child data (email verification already exists via Supabase Auth)
- Data minimization: only collect what's necessary (audit current schema)
- Data retention: define and implement retention periods (e.g., watch history older than 1 year auto-deleted)
- No persistent identifiers shared with third parties without consent
- Privacy policy: write child-focused privacy policy
- Right to delete: parent can request full deletion of child's data

**File:** `docs/coppa-compliance.md` — full compliance checklist and implementation status

---

## Phase 6: Testing & Device Deployment

### 6.1 Flutter Unit Tests

Test each domain service in isolation with mocked dependencies:

| Service | Test file | Key test cases |
|---------|-----------|----------------|
| `ContentFilterService` | `content_filter_service_test.dart` | Override approval, blacklist rejection, age filtering, score thresholds, confidence gating |
| `ScreenTimeService` | `screen_time_service_test.dart` | Active/winddown/break/timeUp/bedtime states, timer ticking, session tracking |
| `AgeRecommendationService` | `age_recommendation_service_test.dart` | Each age bracket returns correct defaults |
| `FeedCurationService` | `feed_curation_service_test.dart` | Category filtering, variety rotation, schedule enforcement |
| `MetadataGateService` | `metadata_gate_service_test.dart` | Blocklist detection, duration check, channel trust check |
| `ParentalControlService` | `parental_control_service_test.dart` | PIN hash/verify, math problem generation, biometric chain |
| `QuotaManagerService` | `quota_manager_service_test.dart` | Bucket allocation, Piped fallback trigger, daily reset |
| `ContentScheduleService` | `content_schedule_service_test.dart` | Time-gated content types |
| `AgeTransitionService` | `age_transition_service_test.dart` | Bracket boundary detection |

### 6.2 Flutter Widget Tests

| Screen/Widget | Test file | Key assertions |
|---------------|-----------|----------------|
| `KidHomeScreen` | `kid_home_screen_test.dart` | Renders tabs, Shorts row, video grid, category chips |
| `ShortsFeedScreen` | `shorts_feed_screen_test.dart` | Vertical swipe works, screen time overlay, break overlay |
| `KidVideoPlayerScreen` | `kid_video_player_test.dart` | Player renders, controls work, no external links |
| `ParentDashboardScreen` | `parent_dashboard_test.dart` | Stats render, navigation works |
| `ChildSelectScreen` | `child_select_test.dart` | Profiles display, biometric gate triggers |
| `FilterSettingsScreen` | `filter_settings_test.dart` | Sliders adjust, save persists |
| `DevSettingsScreen` | `dev_settings_test.dart` | Tier toggle, analysis reset, provider switch |

### 6.3 Flutter Integration Tests

| Flow | Test file | Steps |
|------|-----------|-------|
| Auth flow | `auth_flow_test.dart` | Sign up → verify → login → see dashboard |
| Onboarding | `onboarding_flow_test.dart` | Welcome → add child → filter setup → channel suggestions → complete |
| Kid mode entry/exit | `kid_mode_test.dart` | Select child (biometric) → kid home → browse → exit (biometric) → dashboard |
| Video playback | `playback_test.dart` | Tap video → player loads → screen time ticks → break triggers |
| Screen time | `screen_time_test.dart` | Configure limits → enter kid mode → verify enforcement |

### 6.4 Python Worker Tests

| Module | Test file | Key test cases |
|--------|-----------|----------------|
| `pipeline/orchestrator.py` | `test_orchestrator.py` | Full pipeline flow, early stopping at each tier, provider selection |
| `pipeline/tier05_embedding.py` | `test_embedding.py` | Similarity calculation, fast-track thresholds |
| `providers/claude_provider.py` | `test_claude.py` | Text analysis, vision analysis, error handling |
| `providers/gemini_provider.py` | `test_gemini.py` | Text analysis, embedding generation |
| `queue/consumer.py` | `test_consumer.py` | Queue polling, job processing, error recovery |
| `api/routes.py` | `test_api.py` | Health check, analyze endpoint, rate limiting |
| `discovery/recommendation_engine.py` | `test_recommendations.py` | Similarity ranking, diversity, weight balance |

### 6.5 Platform Configuration

**Android:**
- `app/android/app/build.gradle`: set `minSdkVersion 23`, `targetSdkVersion 34`, `compileSdkVersion 34`
- Signing config: generate debug + release keystores
- Permissions: INTERNET, USE_BIOMETRIC, USE_FINGERPRINT
- ProGuard rules for release builds

**iOS:**
- `app/ios/Runner/Info.plist`: NSFaceIDUsageDescription, NSMicrophoneUsageDescription (voice search)
- Minimum deployment target: iOS 14.0
- Signing: development provisioning profile (for real device testing)
- Capabilities: Face ID

**Shared:**
- App icons for all required sizes (use flutter_launcher_icons)
- Splash screen (use flutter_native_splash)

### 6.6 Build & Run Scripts

```bash
# Android debug APK (install on Samsung/Google phones)
cd app && flutter build apk --debug

# Android release APK
cd app && flutter build apk --release

# iOS debug (requires Mac + Xcode)
cd app && flutter build ios --debug

# Run on connected device
cd app && flutter run -d <device-id>

# Run on iOS simulator
cd app && flutter run -d "iPhone 15 Pro"

# Run on Android emulator
cd app && flutter run -d emulator-5554
```

### 6.7 CI Pipeline (GitHub Actions)

```yaml
# .github/workflows/ci.yml
# On PR: lint → unit tests → widget tests → build APK → build iOS (if Mac runner)
```

---

## Verification Plan

### Per-Phase Verification

**Phase 1:**
- Run `flutter analyze` — zero warnings
- Run `flutter test` — smoke test passes
- Manually test PIN verification chain on device
- Manually test dev settings panel (tier toggle, analysis reset)
- Verify ScreenTimeSettings and ContentSchedule screens receive correct childId
- Verify category filter bubbles filter the feed

**Phase 2:**
- Run on iOS simulator and Android emulator — 4-tab navigation works
- Shorts feed: vertical swipe works, videos auto-play/pause
- Screen time overlay shows correctly in Shorts
- Break/bedtime overlays block Shorts playback
- Home tab shows Shorts row + video grid
- Search returns filtered results
- No way to access unfiltered YouTube content from kid mode

**Phase 3:**
- Switch AI_PROVIDER to each provider, trigger analysis, verify results
- Verify Gemini Embedding 2 computes and stores vectors
- Verify Tier 0.5 fast-tracks similar videos
- Verify cost tracking logs per provider

**Phase 4:**
- Parent approves a channel → child sees content from that channel in feed
- Watch 10+ videos → recommendations show similar content
- Feed composition matches expected weights (40/30/20/10)
- Channel auto-suggestion triggers after 3 approved videos from same channel

**Phase 5:**
- Biometric → PIN → math gate chain works on iOS and Android
- Web requires PIN (not auto-pass)
- Rate limiting rejects 11th analysis request in 1 minute
- Community rating requires 30s watch time
- COPPA compliance checklist passes

**Phase 6:**
- All unit tests pass: `flutter test` (app), `pytest` (worker)
- All widget tests pass
- Integration tests pass on simulator
- APK installs and runs on Samsung/Google phone
- iOS app installs and runs on iPhone (via Xcode)
- CI pipeline runs green on GitHub Actions

### End-to-End Test Scenario

1. Fresh install → sign up → onboarding → add 2 children (age 4 and age 10)
2. Parent dashboard shows both children with correct age brackets
3. Switch to child 1 (age 4) via biometric → kid mode with YouTube-like UI
4. Shorts feed shows age-appropriate content only
5. Watch 5 Shorts → screen time ticks down → break triggers
6. Exit kid mode (biometric) → switch to child 2 (age 10)
7. Feed shows different content appropriate for tweens
8. Parent opens filter settings → adjusts scariness slider → feed updates
9. Parent approves a channel → child sees channel content in feed
10. Dev settings: switch to free tier → verify analysis limit message
11. Dev settings: switch AI provider → trigger analysis → verify different provider used
