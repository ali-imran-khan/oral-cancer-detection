import subprocess

# Sequence: cleanup -> download images -> download model -> fine-tune -> convert to tflite

def run_script(script_name):
    print(f"Running {script_name}...")
    result = subprocess.run(['python', script_name], capture_output=True, text=True)
    print(result.stdout)
    if result.returncode != 0:
        print(result.stderr)
        raise RuntimeError(f"{script_name} failed.")

if __name__ == "__main__":
    run_script('cleanup_folders.py')
    run_script('download_supabase_images_labelled.py')
    run_script('download_tensorflow_model.py')
    run_script('fine_tune_model.py')
    run_script('convert_to_tflite.py')
    run_script('upload_originalmodel_to_supabase.py')
    run_script('upload_tflite_to_supabase.py')
    print("All steps completed successfully.")
