import os
import requests
from supabase import create_client, Client
from config import SUPABASE_URL, SUPABASE_KEY, IMAGE_BUCKET, MODEL_BUCKET

BUCKET_NAME = IMAGE_BUCKET

# Output folders
NORMAL_DIR = os.path.join('images', 'Normal')
ORAL_CANCER_DIR = os.path.join('images', 'Oral Cancer')
os.makedirs(NORMAL_DIR, exist_ok=True)
os.makedirs(ORAL_CANCER_DIR, exist_ok=True)

def get_supabase_client() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)

def fetch_analysis_history(supabase: Client):
    return supabase.table('oral_cancer_analysis_history').select('*').execute().data

def download_image(url, dest_path):
    r = requests.get(url)
    if r.status_code == 200:
        with open(dest_path, 'wb') as f:
            f.write(r.content)
        print(f"Downloaded: {dest_path}")
    else:
        print(f"Failed to download {url}")

def main():
    supabase = get_supabase_client()
    records = fetch_analysis_history(supabase)
    for rec in records:
        image_url = rec['image_url']
        results = rec['results']
        # Find label with highest confidence
        best = max(results, key=lambda x: x['confidence'])
        label = best['label']
        confidence = best['confidence']
        # Set folder and filename
        if label == 'Oral Cancer':
            folder = ORAL_CANCER_DIR
        else:
            folder = NORMAL_DIR
        filename = f"{confidence:.6f}.jpg"
        dest_path = os.path.join(folder, filename)
        download_image(image_url, dest_path)

if __name__ == '__main__':
    main()
