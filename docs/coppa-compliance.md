# COPPA Compliance Checklist

## Overview
Baby Monitor collects data about children's video viewing habits to provide AI-powered content safety filtering. This document maps all data collection, purpose, and retention policies per COPPA requirements (FTC Rule, amended June 2025, compliance deadline April 22, 2026).

## Data Map

| Table | Data Collected | Purpose | Retention | Third-Party Sharing |
|-------|---------------|---------|-----------|-------------------|
| `child_profiles` | Name, DOB | Identify child, compute age for filtering | Until parent deletes | None |
| `watch_history` | Video IDs, timestamps, duration | Track screen time, build recommendations | 1 year auto-delete | None |
| `filtered_log` | Blocked video IDs, filter reason | Show parents what was filtered | 1 year auto-delete | None |
| `screen_time_sessions` | Session timestamps, duration | Enforce screen time limits | 1 year auto-delete | None |
| `screen_time_rules` | Daily limits, break intervals | Configure per-child limits | Until parent changes | None |
| `content_preferences` | Preferred/blocked content types | Customize content filtering | Until parent changes | None |
| `community_ratings` | Parent ratings on videos | Community safety consensus | Indefinite (anonymized) | Aggregated only |
| `consent_records` | Consent type, version, legal name, timestamp | COPPA audit trail | Account lifetime + 7 years | None |

## Parental Consent
- **Mechanism:** Parent creates account with email + password verification via Supabase Auth
- **Verification:** Email verification required before child data is collected
- **COPPA Consent Screen:** Dedicated in-app consent screen (`parental_consent_screen.dart`) shown before first child profile creation
  - Plain-language explanation of all child data collection
  - Granular checkboxes for each category (name/DOB, watch history, screen time, filtering logs, AI analysis, community scores)
  - Parent must enter full legal name to acknowledge consent
  - Consent recorded in `consent_records` table with timestamp and version
  - Re-shown when consent version changes
- **Child profiles:** Created only by authenticated parents, never self-registered
- **Signup consent:** Required checkboxes for ToS/PP acceptance and age/guardian confirmation before account creation

## Data Minimization
- No precise geolocation collected
- No photos/videos of children collected
- No social features between children
- Device ID stored only for screen time tracking across devices
- YouTube video content is analyzed server-side; child's device never sends personal data to YouTube
- Child identifiers in analytics are SHA-256 hashed before storage (irreversible)

## Right to Delete
- **Implementation:** `delete_child_data()` SQL function cascade-deletes all child-associated data
- **Account deletion:** `delete_parent_account()` cascade-deletes all children and all associated data
- **Access:** Parent can request deletion from app settings (Account Settings screen)
- **Timeline:** Immediate upon request

## Data Retention
- Watch history: auto-deleted after 1 year via `cleanup_old_watch_history()` function
- Filtered log: auto-deleted after 1 year
- Screen time sessions: auto-deleted after 1 year
- Analytics events: auto-deleted after 1 year
- Account data: retained until parent deletes account
- Consent records: retained for account lifetime + 7 years for legal compliance

## Third-Party Services
| Service | Data Shared | Purpose | COPPA Status |
|---------|-------------|---------|--------------|
| Supabase (PostgreSQL) | All app data | Database hosting | Data processor, no direct child access |
| YouTube Data API | Search queries, video IDs | Fetch video metadata | No child PII sent |
| Piped API | Search queries, video IDs | YouTube fallback | No child PII sent |
| Anthropic (Claude) | Video metadata, transcripts | Content safety analysis | No child PII sent |
| Google (Gemini) | Video metadata, transcripts | Content safety analysis | No child PII sent |
| OpenAI | Video metadata, transcripts | Content safety analysis | No child PII sent |
| RevenueCat | Device ID, subscription status | Subscription management | No child PII sent |

## No Persistent Identifiers Shared
- YouTube API calls use server-side API key, not child identifiers
- AI analysis sends video content only, never child profiles
- Community ratings are associated with parent accounts, not children
- Analytics child IDs are irreversibly hashed (SHA-256)

## Privacy Policy Requirements
- [x] Clearly states what data is collected from children
- [x] Describes how data is used and protected
- [x] Provides parent access to review/delete child data
- [x] Accessible from app settings and app store listing
- [x] Standalone Children's Privacy Notice (`childrensPrivacyNotice` in `legal_content.dart`)

## AI Filtering Disclaimer
- [x] Clear disclaimer that AI filtering is not 100% accurate (`aiFilteringDisclaimer` in `legal_content.dart`)
- [x] Disclaimer in Terms of Service (Section 5)
- [x] Welcome screen uses non-absolute language ("AI-screened for safety" not "guaranteed safe")
- [x] App metadata description avoids safety guarantees

## Implementation Status
- [x] Email verification for parent accounts
- [x] RLS policies isolating data per parent
- [x] No child-to-child communication features
- [x] PIN/biometric gating for child mode transitions
- [x] Rate limiting on API endpoints
- [x] Data deletion function (`delete_child_data`)
- [x] Data retention policy (1 year auto-delete)
- [x] Privacy Policy in app (`legal_content.dart` — comprehensive, COPPA-compliant)
- [x] Children's Privacy Notice in app (standalone document)
- [x] Terms of Service with AI disclaimer, arbitration, indemnification
- [x] CCPA/CPRA notice supplement
- [x] Parental consent screen with granular checkboxes
- [x] Consent records database table (`018_consent_records.sql`)
- [x] Signup consent checkboxes (ToS/PP + age/guardian confirmation)
- [x] Analytics opt-in/opt-out (default OFF for GDPR compliance)
- [x] Subscription auto-renewal disclosures (Apple/Google required language)
- [x] All legal documents accessible from About screen
- [ ] pg_cron schedule for `cleanup_old_watch_history()` (deploy-time task)
- [ ] Website versions of legal documents at babymonitor.app (separate deployment)
- [ ] App store data safety declarations (submitted during store listing)
