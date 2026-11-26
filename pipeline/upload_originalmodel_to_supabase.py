import os
from supabase import create_client, Client
from config import SUPABASE_URL, SUPABASE_KEY, IMAGE_BUCKET, MODEL_BUCKET

BUCKET_NAME = MODEL_BUCKET
PREFIX = "original/"
LOCAL_MODEL_PATH = os.path.join("OriginalModel", "oral_cancer.h5")
REMOTE_MODEL_PATH = PREFIX + "oral_cancer.h5"

def main():
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    # Delete old model file if exists
    files = supabase.storage.from_(BUCKET_NAME).list(path=PREFIX)
    for file in files:
        if file['name'] == "oral_cancer.h5":
            supabase.storage.from_(BUCKET_NAME).remove([REMOTE_MODEL_PATH])
            print(f"Deleted old {REMOTE_MODEL_PATH} from Supabase.")
    # Upload new model file
    with open(LOCAL_MODEL_PATH, "rb") as f:
        supabase.storage.from_(BUCKET_NAME).upload(REMOTE_MODEL_PATH, f)
    print(f"Uploaded {LOCAL_MODEL_PATH} to Supabase as {REMOTE_MODEL_PATH}.")

if __name__ == "__main__":
    main()
