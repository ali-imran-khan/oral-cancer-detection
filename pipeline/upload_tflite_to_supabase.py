import os
from supabase import create_client, Client
from config import SUPABASE_URL, SUPABASE_KEY, IMAGE_BUCKET, MODEL_BUCKET

BUCKET_NAME = MODEL_BUCKET
PREFIX = "tflite/"
LOCAL_TFLITE_PATH = os.path.join("TFLiteModel", "oral_cancer.tflite")
REMOTE_TFLITE_PATH = PREFIX + "oral_cancer.tflite"

def main():
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    # Delete old tflite file if exists
    files = supabase.storage.from_(BUCKET_NAME).list(path=PREFIX)
    for file in files:
        if file['name'] == "oral_cancer.tflite":
            supabase.storage.from_(BUCKET_NAME).remove([REMOTE_TFLITE_PATH])
            print(f"Deleted old {REMOTE_TFLITE_PATH} from Supabase.")
    # Upload new tflite file
    with open(LOCAL_TFLITE_PATH, "rb") as f:
        supabase.storage.from_(BUCKET_NAME).upload(REMOTE_TFLITE_PATH, f)
    print(f"Uploaded {LOCAL_TFLITE_PATH} to Supabase as {REMOTE_TFLITE_PATH}.")

if __name__ == "__main__":
    main()
