-- Migration 018: Consent records for COPPA and legal compliance
-- Tracks parental consent for child data collection and ToS/PP acceptance.

-- Consent records table
CREATE TABLE IF NOT EXISTS consent_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID NOT NULL REFERENCES parent_profiles(id) ON DELETE CASCADE,
    consent_type TEXT NOT NULL CHECK (consent_type IN (
        'tos_acceptance',
        'privacy_policy_acceptance',
        'coppa_parental_consent',
        'analytics_opt_in',
        'analytics_opt_out',
        'consent_withdrawal',
        'policy_update_acceptance'
    )),
    consent_version TEXT NOT NULL,
    full_legal_name TEXT,
    consented_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT,
    consent_details JSONB DEFAULT '{}'::jsonb
);

-- Index for looking up consent by parent
CREATE INDEX IF NOT EXISTS idx_consent_records_parent_id
    ON consent_records (parent_id);

-- Index for looking up consent by type and version
CREATE INDEX IF NOT EXISTS idx_consent_records_type_version
    ON consent_records (consent_type, consent_version);

-- Add analytics opt-in and consent tracking columns to parent_profiles
ALTER TABLE parent_profiles
    ADD COLUMN IF NOT EXISTS analytics_opted_in BOOLEAN DEFAULT FALSE;

ALTER TABLE parent_profiles
    ADD COLUMN IF NOT EXISTS last_consent_version TEXT;

-- RLS: parents can only see and insert their own consent records
ALTER TABLE consent_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY consent_records_select_own ON consent_records
    FOR SELECT USING (auth.uid() = parent_id);

CREATE POLICY consent_records_insert_own ON consent_records
    FOR INSERT WITH CHECK (auth.uid() = parent_id);

-- Comment for documentation
COMMENT ON TABLE consent_records IS
    'Tracks parental consent events for COPPA compliance and legal audit trail. '
    'Records are retained for 7 years after account deletion for legal compliance.';
