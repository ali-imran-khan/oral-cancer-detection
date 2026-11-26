-- Supabase SQL script for oral cancer analysis history
-- Stores image public URL from Supabase Storage

CREATE TABLE oral_cancer_analysis_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  image_url text NOT NULL,           -- Supabase Storage public URL
  analysis_date timestamptz NOT NULL DEFAULT now(),
  results jsonb NOT NULL,            -- [{"label": "...", "confidence": ...}, ...]
  oral_tissue_percentage float8,
  error_message text,                -- If any error occurred
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_oral_cancer_analysis_history_user_id
  ON oral_cancer_analysis_history (user_id);
