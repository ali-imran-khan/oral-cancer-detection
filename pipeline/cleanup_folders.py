import shutil
import os

folders_to_delete = ['images', 'OriginalModel', 'TFLiteModel']

for folder in folders_to_delete:
    if os.path.exists(folder):
        shutil.rmtree(folder)
        print(f"Deleted folder: {folder}")
    else:
        print(f"Folder not found: {folder}")
