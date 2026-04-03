-- Remove stale public Piped defaults that no longer serve API traffic.
-- Healthy instances should be supplied via runtime config or build-time env.

UPDATE app_config
SET value = '[]'::jsonb,
    updated_at = NOW()
WHERE key = 'piped_instances'
  AND value IN (
    '["https://pipedapi.kavin.rocks"]'::jsonb,
    '["https://pipedapi.kavin.rocks", "https://pipedapi.adminforge.de"]'::jsonb
  );
