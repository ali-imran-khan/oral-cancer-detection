import tensorflow as tf
from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing import image
import numpy as np

import sys

model_path = "models/oral_cancer.h5"
image_path = sys.argv[1]

# Load the model
model = load_model(model_path)
print("Model loaded successfully!")

# --------------------------
# Image preprocessing
img = image.load_img(image_path, target_size=(150, 150))
img_array = image.img_to_array(img)
img_array = np.expand_dims(img_array, axis=0)
img_array = img_array / 255.0  # same scaling as training

# --------------------------
# Prediction
prediction = model.predict(img_array)
print(f"Raw model output: {prediction}")




# sigmoid output -> threshold at 0.5
predicted_class = 1 if prediction[0][0] > 0.5 else 0
labels = ['benign', 'malignant']
predicted_label = labels[predicted_class]
print(f"Predicted class: {predicted_class}")
print(f"Predicted label: {predicted_label}")
