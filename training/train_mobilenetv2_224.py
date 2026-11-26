import tensorflow as tf
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D, Dropout
from tensorflow.keras.models import Model
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau
import numpy as np
import matplotlib.pyplot as plt
from sklearn.metrics import classification_report, confusion_matrix
import cv2
import os
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')


class OralCancerClassifier:
    def __init__(self, img_height=224, img_width=224, batch_size=32):
        self.img_height = img_height
        self.img_width = img_width
        self.batch_size = batch_size
        self.model = None
        self.history = None
        print(f"Image size: {img_height}x{img_width}, Batch size: {batch_size}")
    
    def analyze_dataset(self, dataset_path):
        """
        Basic dataset analysis
        """
        print("Analyzing dataset...")
        analysis = {}
        total_images = 0
        
        for class_name in os.listdir(dataset_path):
            class_path = os.path.join(dataset_path, class_name)
            if os.path.isdir(class_path):
                image_files = [f for f in os.listdir(class_path) 
                             if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
                count = len(image_files)
                analysis[class_name] = count
                total_images += count
                print(f"Class '{class_name}': {count} images")
        
        print(f"Total images: {total_images}")
        print(f"Number of classes: {len(analysis)}")
        
        # Check for class imbalance
        if len(analysis) > 1:
            counts = list(analysis.values())
            imbalance_ratio = max(counts) / min(counts) if min(counts) > 0 else float('inf')
            print(f"Class imbalance ratio: {imbalance_ratio:.2f}")
            
            if imbalance_ratio > 2.0:
                print("WARNING: Significant class imbalance detected!")
                print("Consider using class weights or data augmentation")
        
        return analysis
    
    def create_model(self):
        """
        MobileNetV2 backbone + small dense head
        """
        print("Creating model...")
        
        # Load pre-trained MobileNetV2
        base_model = MobileNetV2(
            weights='imagenet',
            include_top=False,
            input_shape=(self.img_height, self.img_width, 3)
        )
        
        # Freeze base model initially
        base_model.trainable = False
        
        # Add custom classification head
        inputs = tf.keras.Input(shape=(self.img_height, self.img_width, 3))
        x = base_model(inputs, training=False)
        x = GlobalAveragePooling2D()(x)
        x = Dropout(0.3)(x)
        x = Dense(128, activation='relu')(x)
        x = Dropout(0.2)(x)
        outputs = Dense(1, activation='sigmoid')(x)
        
        self.model = Model(inputs, outputs)
        
        # Compile model
        self.model.compile(
            optimizer=Adam(learning_rate=0.001),
            loss='binary_crossentropy',
            metrics=['accuracy']
        )
        
        print(f"Model created with {self.model.count_params():,} parameters")
        return self.model
    
    def create_data_generators(self, train_dir, val_dir=None, test_dir=None):
        """
        Create data generators with basic augmentation
        """
        print("Creating data generators...")
        
        # Training data generator with augmentation
        train_datagen = ImageDataGenerator(
            rescale=1./255,
            rotation_range=20,
            width_shift_range=0.1,
            height_shift_range=0.1,
            horizontal_flip=True,
            zoom_range=0.1,
            fill_mode='nearest'
        )
        
        # Validation/test data generator (no augmentation)
        val_datagen = ImageDataGenerator(rescale=1./255)
        
        # Create generators
        train_generator = train_datagen.flow_from_directory(
            train_dir,
            target_size=(self.img_height, self.img_width),
            batch_size=self.batch_size,
            class_mode='binary',
            shuffle=True
        )
        
        val_generator = None
        if val_dir:
            val_generator = val_datagen.flow_from_directory(
                val_dir,
                target_size=(self.img_height, self.img_width),
                batch_size=self.batch_size,
                class_mode='binary',
                shuffle=False
            )
        
        test_generator = None
        if test_dir:
            test_generator = val_datagen.flow_from_directory(
                test_dir,
                target_size=(self.img_height, self.img_width),
                batch_size=self.batch_size,
                class_mode='binary',
                shuffle=False
            )
        
        print(f"Generators created:")
        print(f"  Training samples: {train_generator.samples}")
        if val_generator:
            print(f"  Validation samples: {val_generator.samples}")
        if test_generator:
            print(f"  Test samples: {test_generator.samples}")
        
        return train_generator, val_generator, test_generator
    
    def calculate_class_weights(self, train_generator):
        """
        Calculate class weights for imbalanced datasets
        """
        class_counts = {}
        for class_name, class_idx in train_generator.class_indices.items():
            class_counts[class_idx] = 0
        
        # Count samples in each class
        for i in range(len(train_generator)):
            _, labels = train_generator[i]
            for label in labels:
                class_counts[int(label)] += 1
        
        total_samples = sum(class_counts.values())
        n_classes = len(class_counts)
        
        class_weights = {}
        for class_idx, count in class_counts.items():
            class_weights[class_idx] = total_samples / (n_classes * count)
        
        print(f"Class weights calculated: {class_weights}")
        return class_weights
    
    def train(self, train_generator, val_generator=None, epochs=30, use_class_weights=True):
        """
        Train the model
        """
        print(f"Starting training for {epochs} epochs...")
        
        if self.model is None:
            raise ValueError("Model must be created before training")
        
        # Calculate class weights if requested
        class_weights = None
        if use_class_weights:
            class_weights = self.calculate_class_weights(train_generator)
        
        # Setup callbacks
        callbacks = [
            EarlyStopping(
                monitor='val_loss' if val_generator else 'loss',
                patience=10,
                restore_best_weights=True,
                verbose=1
            ),
            ReduceLROnPlateau(
                monitor='val_loss' if val_generator else 'loss',
                factor=0.5,
                patience=5,
                min_lr=1e-7,
                verbose=1
            )
        ]
        
        # Train the model
        self.history = self.model.fit(
            train_generator,
            epochs=epochs,
            validation_data=val_generator,
            callbacks=callbacks,
            class_weight=class_weights,
            verbose=1
        )
        
        print("Training completed!")
        return self.history
    
    def fine_tune(self, train_generator, val_generator=None, epochs=10):
        """
        Fine-tune the model by unfreezing some layers
        """
        print("Starting fine-tuning...")
        
        if self.model is None:
            raise ValueError("Model must be trained before fine-tuning")
        
        # Unfreeze the top layers of the base model
        base_model = self.model.layers[1]  # MobileNetV2 layer
        base_model.trainable = True
        
        # Fine-tune from this layer onwards
        fine_tune_at = 100
        for layer in base_model.layers[:fine_tune_at]:
            layer.trainable = False
        
        # Recompile with lower learning rate
        self.model.compile(
            optimizer=Adam(learning_rate=0.0001/10),
            loss='binary_crossentropy',
            metrics=['accuracy']
        )
        
        # Fine-tune
        fine_tune_history = self.model.fit(
            train_generator,
            epochs=epochs,
            validation_data=val_generator,
            verbose=1
        )
        
        # Combine histories
        if self.history:
            for key in self.history.history.keys():
                self.history.history[key].extend(fine_tune_history.history[key])
        
        print("Fine-tuning completed!")
        return fine_tune_history
    
    def evaluate(self, test_generator):
        """
        Evaluate the model and show results
        """
        print("Evaluating model...")
        
        if self.model is None:
            raise ValueError("Model must be trained before evaluation")
        
        # Make predictions
        predictions = self.model.predict(test_generator, verbose=1)
        y_pred = (predictions > 0.5).astype(int).flatten()
        
        # Get true labels
        y_true = test_generator.classes
        
        # Calculate metrics
        test_loss, test_accuracy = self.model.evaluate(test_generator, verbose=0)
        
        print(f"\nTest Results:")
        print(f"Test Loss: {test_loss:.4f}")
        print(f"Test Accuracy: {test_accuracy:.4f}")
        
        # Classification report
        class_names = list(test_generator.class_indices.keys())
        print(f"\nClassification Report:")
        print(classification_report(y_true, y_pred, target_names=class_names))
        
        # Confusion matrix
        cm = confusion_matrix(y_true, y_pred)
        print(f"\nConfusion Matrix:")
        print(cm)
        
        return {
            'test_loss': test_loss,
            'test_accuracy': test_accuracy,
            'predictions': predictions,
            'y_true': y_true,
            'y_pred': y_pred,
            'confusion_matrix': cm
        }
    
    def plot_training_history(self, save_path=None):
        """
        Plot training history
        """
        if self.history is None:
            print("No training history available")
            return
        
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 4))
        
        # Plot training & validation accuracy
        ax1.plot(self.history.history['accuracy'], label='Training Accuracy')
        if 'val_accuracy' in self.history.history:
            ax1.plot(self.history.history['val_accuracy'], label='Validation Accuracy')
        ax1.set_title('Model Accuracy')
        ax1.set_xlabel('Epoch')
        ax1.set_ylabel('Accuracy')
        ax1.legend()
        ax1.grid(True)
        
        # Plot training & validation loss
        ax2.plot(self.history.history['loss'], label='Training Loss')
        if 'val_loss' in self.history.history:
            ax2.plot(self.history.history['val_loss'], label='Validation Loss')
        ax2.set_title('Model Loss')
        ax2.set_xlabel('Epoch')
        ax2.set_ylabel('Loss')
        ax2.legend()
        ax2.grid(True)
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
        plt.show()
    
    def predict_image(self, image_path):
        """
        Predict on a single image
        """
        if self.model is None:
            raise ValueError("Model must be trained before making predictions")
        
        # Load and preprocess image
        img = cv2.imread(image_path)
        if img is None:
            raise ValueError(f"Could not load image: {image_path}")
        
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        img = cv2.resize(img, (self.img_width, self.img_height))
        img = img.astype(np.float32) / 255.0
        img = np.expand_dims(img, axis=0)
        
        # Make prediction
        prediction = self.model.predict(img, verbose=0)[0][0]
        predicted_class = int(prediction > 0.5)
        confidence = max(prediction, 1 - prediction)
        
        return {
            'probability': float(prediction),
            'predicted_class': predicted_class,
            'confidence': float(confidence),
            'label': 'Cancer' if predicted_class == 1 else 'Normal'
        }
    
    def save_model(self, filepath):
        """
        Save the trained model
        """
        if self.model is None:
            raise ValueError("No model to save")
        
        self.model.save(filepath)
        print(f"Model saved to: {filepath}")
    
    def load_model(self, filepath):
        """
        Load a saved model
        """
        self.model = tf.keras.models.load_model(filepath)
        print(f"Model loaded from: {filepath}")


if __name__ == "__main__":
    print("oral cancer classifier: 224px, class-weighted, two-stage fine-tune")
    

    classifier = OralCancerClassifier(img_height=224, img_width=224, batch_size=16)
    
    dataset_root = "data/split"
    train_dir = f"{dataset_root}/Train"
    val_dir = f"{dataset_root}/Validation"
    test_dir = f"{dataset_root}/Test"
    
    try:
        # 1. Analyze dataset
        print("\n[1] analyzing dataset")
        analysis = classifier.analyze_dataset(dataset_root)
        
        # 2. Create model
        print("\n[2] creating model")
        model = classifier.create_model()
        print("Model Architecture:")
        model.summary()
        
        # 3. Create data generators
        print("\n[3] creating data generators")
        train_gen, val_gen, test_gen = classifier.create_data_generators(
            train_dir=train_dir,
            val_dir=val_dir,
            test_dir=test_dir
        )
        
        print(f"Class indices: {train_gen.class_indices}")
        
        # 4. Train model
        print("\n[4] training model")
        history = classifier.train(train_gen, val_gen, epochs=30)
        
        # 5. Optional: Fine-tune
        print("\n5. FINE-TUNING MODEL...")
        classifier.fine_tune(train_gen, val_gen, epochs=10)
        
        # 6. Evaluate model
        print("\n[6] evaluating model")
        results = classifier.evaluate(test_gen)
        
        # 7. Plot training history
        print("\n[7] plotting training history")
        classifier.plot_training_history(save_path="training_history.png")
        
        # 8. Save model
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        model_path = f"oral_cancer_model_{timestamp}.h5"
        classifier.save_model(model_path)
        
        print(f"\n=== TRAINING COMPLETED SUCCESSFULLY ===")
        print(f"Final Test Accuracy: {results['test_accuracy']:.4f}")
        print(f"Model saved as: {model_path}")
        
        # Example prediction (replace with actual image path)
        print("\n[8] example prediction")
        print("To predict on a new image, use:")
        print("result = classifier.predict_image('path/to/your/image.jpg')")
        print("print(f\"Prediction: {result['label']} (Confidence: {result['confidence']:.3f})\")")
        
    except FileNotFoundError as e:
        print(f"Error: Could not find directory - {e}")
        print("Please make sure your dataset paths are correct:")
        print(f"  Train: {train_dir}")
        print(f"  Validation: {val_dir}")
        print(f"  Test: {test_dir}")
        
    except Exception as e:
        print(f"Error during execution: {e}")
        print("Check that:")
        print("1. All required packages are installed")
        print("2. Dataset directories exist and contain subdirectories for each class")
        print("3. Image files are in supported formats (.jpg, .jpeg, .png)")
    
    print("\nDependencies needed:")
    print("pip install tensorflow opencv-python matplotlib scikit-learn numpy")