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

## Parental Consent
- **Mechanism:** Parent creates account with email + password verification via Supabase Auth
- **Verification:** Email verification required before child data is collected
- **Child profiles:** Created only by authenticated parents, never self-registered

## Data Minimization
- No precise geolocation collected
- No photos/videos of children collected
- No social features between children
- Device ID stored only for screen time tracking across devices
- YouTube video content is analyzed server-side; child's device never sends personal data to YouTube

## Right to Delete
- **Implementation:** `delete_child_data()` SQL function cascade-deletes all child-associated data
- **Access:** Parent can request deletion from app settings
- **Timeline:** Immediate upon request

## Data Retention
- Watch history: auto-deleted after 1 year via `cleanup_old_watch_history()` function
- Filtered log: auto-deleted after 1 year
- Screen time sessions: auto-deleted after 1 year
- Account data: retained until parent deletes account

## Third-Party Services
| Service | Data Shared | Purpose | COPPA Status |
|---------|-------------|---------|--------------|
| Supabase (PostgreSQL) | All app data | Database hosting | Data processor, no direct child access |
| YouTube Data API | Search queries, video IDs | Fetch video metadata | No child PII sent |
| Piped API | Search queries, video IDs | YouTube fallback | No child PII sent |
| Anthropic (Claude) | Video metadata, transcripts | Content safety analysis | No child PII sent |
| Google (Gemini) | Video metadata, transcripts | Content safety analysis | No child PII sent |

## No Persistent Identifiers Shared
- YouTube API calls use server-side API key, not child identifiers
- AI analysis sends video content only, never child profiles
- Community ratings are associated with parent accounts, not children

## Privacy Policy Requirements
- Must clearly state what data is collected from children
- Must describe how data is used and protected
- Must provide parent access to review/delete child data
- Must be accessible from app settings and app store listing

## Implementation Status
- [x] Email verification for parent accounts
- [x] RLS policies isolating data per parent
- [x] No child-to-child communication features
- [x] PIN/biometric gating for child mode transitions
- [x] Rate limiting on API endpoints
- [x] Data deletion function (`delete_child_data`)
- [x] Data retention policy (1 year auto-delete)
- [ ] Privacy policy in app (template exists in legal_content.dart)
- [ ] pg_cron schedule for `cleanup_old_watch_history()`
