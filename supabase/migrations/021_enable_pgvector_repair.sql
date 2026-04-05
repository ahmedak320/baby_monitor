-- Repair: enable pgvector and recreate embedding infrastructure.
-- Migration 006 ran but pgvector wasn't available at the time,
-- so CREATE EXTENSION succeeded silently but the extension was empty.

-- Enable pgvector in the extensions schema (Supabase convention)
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;

-- Add embedding column if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'video_analyses'
          AND column_name = 'embedding'
    ) THEN
        ALTER TABLE public.video_analyses ADD COLUMN embedding extensions.vector(768);
    END IF;
END;
$$;

-- Recreate the IVFFlat index (requires extension + column)
DROP INDEX IF EXISTS idx_video_analyses_embedding;
CREATE INDEX IF NOT EXISTS idx_video_analyses_embedding
  ON public.video_analyses USING ivfflat (embedding extensions.vector_cosine_ops)
  WITH (lists = 10);  -- Use lists=10 until we have 1000+ rows, then increase

-- Recreate the match function using extensions schema types
CREATE OR REPLACE FUNCTION public.match_video_embeddings(
  query_embedding extensions.vector(768),
  match_threshold float DEFAULT 0.85,
  match_count int DEFAULT 5
)
RETURNS TABLE (
  video_id text,
  verdict text,
  similarity float
)
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    va.video_id,
    LOWER(COALESCE(va.verdict, 'pending')) as verdict,
    1 - (va.embedding OPERATOR(extensions.<=>) query_embedding) as similarity
  FROM video_analyses va
  WHERE va.embedding IS NOT NULL
    AND 1 - (va.embedding OPERATOR(extensions.<=>) query_embedding) > match_threshold
  ORDER BY va.embedding OPERATOR(extensions.<=>) query_embedding
  LIMIT match_count;
$$;
