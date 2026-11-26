import os
import requests
from supabase import create_client, Client
from config import SUPABASE_URL, SUPABASE_KEY, IMAGE_BUCKET, MODEL_BUCKET

MODEL_BUCKET_NAME = MODEL_BUCKET
MODEL_PREFIX = "original/"   # Path prefix inside the bucket

# Folder to save the model
MODEL_FOLDER = "OriginalModel"

def ensure_model_folder():
    if not os.path.exists(MODEL_FOLDER):
        os.makedirs(MODEL_FOLDER)

def download_tensorflow_model():
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
    # List all files under the 'original/' prefix in the 'model' bucket
    files = supabase.storage.from_(MODEL_BUCKET_NAME).list(path=MODEL_PREFIX)
    ensure_model_folder()
    for file in files:
        # Download only TensorFlow SavedModel files (usually .h5, variables/, assets/)
        if file['name'].endswith('.h5') or file['name'].startswith('variables') or file['name'].startswith('assets'):
            # The file['name'] is relative to the prefix, so join with prefix for full path
            full_path = MODEL_PREFIX + file['name']
            url = supabase.storage.from_(MODEL_BUCKET_NAME).get_public_url(full_path)
            file_path = os.path.join(MODEL_FOLDER, file['name'])
            # Create subfolders if needed
            os.makedirs(os.path.dirname(file_path), exist_ok=True)
            data = requests.get(url).content
            with open(file_path, 'wb') as f:
                f.write(data)
            print(f"Downloaded {full_path} to {file_path}")

if __name__ == "__main__":
    download_tensorflow_model()
