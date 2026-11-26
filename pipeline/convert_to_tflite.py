import tensorflow as tf

import os

def find_model_path():
    model_dir = 'OriginalModel'
    # Check for .h5 file
    for file in os.listdir(model_dir):
        if file.endswith('.h5'):
            return os.path.join(model_dir, file)
    # If no .h5, check for SavedModel format (saved_model.pb)
    if os.path.exists(os.path.join(model_dir, 'saved_model.pb')):
        return model_dir  # SavedModel directory
    # If not found, raise error
    raise FileNotFoundError('No .h5 or SavedModel found in OriginalModel folder.')

model_path = find_model_path()
model = tf.keras.models.load_model(model_path)

# Convert to TensorFlow Lite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

# Save the TFLite model in 'TFLiteModel' folder
output_dir = 'TFLiteModel'
os.makedirs(output_dir, exist_ok=True)
output_path = os.path.join(output_dir, 'oral_cancer.tflite')
with open(output_path, 'wb') as f:
    f.write(tflite_model)

print(f'Conversion complete: {output_path} created.')
