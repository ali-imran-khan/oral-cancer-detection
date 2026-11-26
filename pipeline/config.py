import os

# Set these in your shell or a .env file. The service-role key must never be committed.
SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_SERVICE_KEY"]

IMAGE_BUCKET = os.environ.get("SUPABASE_IMAGE_BUCKET", "oral-cancer-images")
MODEL_BUCKET = os.environ.get("SUPABASE_MODEL_BUCKET", "model")
