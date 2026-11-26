import tensorflow as tf
import os
from tensorflow.keras.preprocessing.image import ImageDataGenerator

tf.config.run_functions_eagerly(True)

# Paths
MODEL_DIR = 'OriginalModel'
IMAGES_DIR = 'images'
OUTPUT_DIR = 'FineTunedModel'
EPOCHS = 3
BATCH_SIZE = 16

# Find model path (.h5, .keras, or SavedModel)
def find_model_path():
    for file in os.listdir(MODEL_DIR):
        if file.endswith('.h5') or file.endswith('.keras'):
            return os.path.join(MODEL_DIR, file)
    if os.path.exists(os.path.join(MODEL_DIR, 'saved_model.pb')):
        return MODEL_DIR
    raise FileNotFoundError('No .h5, .keras, or SavedModel found in OriginalModel folder.')

model_path = find_model_path()
model = tf.keras.models.load_model(model_path)

# images/<class>/... -> class from folder name
def get_data_generator():
    datagen = ImageDataGenerator(rescale=1./255, validation_split=0.2)
    train_gen = datagen.flow_from_directory(
        directory=IMAGES_DIR,
        target_size=(150, 150),
        batch_size=BATCH_SIZE,
        class_mode='binary',
        subset='training',
        shuffle=True
    )
    val_gen = datagen.flow_from_directory(
        directory=IMAGES_DIR,
        target_size=(150, 150),
        batch_size=BATCH_SIZE,
        class_mode='binary',
        subset='validation',
        shuffle=True
    )
    return train_gen, val_gen

train_gen, val_gen = get_data_generator()


model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])

# Fine-tune
model.fit(
    train_gen,
    steps_per_epoch=len(train_gen),
    epochs=EPOCHS,
    validation_data=val_gen,
    validation_steps=len(val_gen)
)

# Replace the previous model in OriginalModel
import shutil
# Remove all contents in OriginalModel
for filename in os.listdir(MODEL_DIR):
    file_path = os.path.join(MODEL_DIR, filename)
    if os.path.isfile(file_path) or os.path.islink(file_path):
        os.unlink(file_path)
    elif os.path.isdir(file_path):
        shutil.rmtree(file_path)
# Save the fine-tuned model in OriginalModel with .h5 extension
finetuned_model_path = os.path.join(MODEL_DIR, "oral_cancer.h5")
model.save(finetuned_model_path)
print('Fine-tuning complete. Model saved as', finetuned_model_path)
