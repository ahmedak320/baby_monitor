-- Enable pgvector extension for embedding similarity search
CREATE EXTENSION IF NOT EXISTS vector;

-- Add embedding column to video_analyses
ALTER TABLE video_analyses
  ADD COLUMN IF NOT EXISTS embedding vector(768);

-- Create IVFFlat index for fast cosine similarity search
-- Note: requires at least 100 rows for lists=100 to be effective
CREATE INDEX IF NOT EXISTS idx_video_analyses_embedding
  ON video_analyses USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

-- Function for matching video embeddings by cosine similarity
CREATE OR REPLACE FUNCTION match_video_embeddings(
  query_embedding vector(768),
  match_threshold float DEFAULT 0.85,
  match_count int DEFAULT 5
)
RETURNS TABLE (
  video_id text,
  verdict text,
  similarity float
)
LANGUAGE sql STABLE
AS $$
  SELECT
    va.video_id,
    LOWER(va.verdict) as verdict,
    1 - (va.embedding <=> query_embedding) as similarity
  FROM video_analyses va
  WHERE va.embedding IS NOT NULL
    AND 1 - (va.embedding <=> query_embedding) > match_threshold
  ORDER BY va.embedding <=> query_embedding
  LIMIT match_count;
$$;
