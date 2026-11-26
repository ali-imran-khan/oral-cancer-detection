import 'dart:math' as math show exp;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class OralCancerModel {
  late Interpreter _interpreter;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('models/oral_cancer.tflite');
    
    if (_interpreter.getInputTensors().isNotEmpty) {
      _interpreter.getInputTensor(0);
    }
    
    if (_interpreter.getOutputTensors().isNotEmpty) {
      _interpreter.getOutputTensor(0);
    }
  }

  Future<List<Map<String, dynamic>>> predict(List input, List<String> labels) async {
    _interpreter.getOutputTensor(0).shape;
    _interpreter.getInputTensor(0).shape;

    // Output buffer for [1, 1] output
    final outputBuffer = List<List<double>>.filled(1, List<double>.filled(1, 0));
    _interpreter.run(input, outputBuffer);

    final rawOutput = outputBuffer[0][0];
    double probability;
    
    // Check if the output is already a probability (between 0 and 1)
    // or if it's a logit that needs sigmoid activation
    if (rawOutput >= 0.0 && rawOutput <= 1.0) {
      // Output is already a probability
      probability = rawOutput;
    } else {
      // Output is a logit, apply sigmoid
      double sigmoid(double x) => 1 / (1 + math.exp(-x));
      probability = sigmoid(rawOutput);
    }

    // Ensure we have exactly 2 labels for binary classification
    List<String> binaryLabels;
    if (labels.length >= 2) {
      binaryLabels = [labels[0].trim(), labels[1].trim()];
    } else if (labels.length == 1) {
      // If only one label, assume it's "Normal" and add "Oral Cancer"
      binaryLabels = [labels[0].trim(), 'Oral Cancer'];
    } else {
      // Default labels
      binaryLabels = ['Normal', 'Oral Cancer'];
    }
    
    // For binary classification:
    // probability > 0.5 means positive class (usually index 1)
    // probability <= 0.5 means negative class (usually index 0)
    
    List<Map<String, dynamic>> results = [];
    
    if (probability > 0.5) {
      // Positive prediction (second class)
      results.add({
        'label': binaryLabels[1],
        'confidence': probability,
      });
      results.add({
        'label': binaryLabels[0],
        'confidence': 1.0 - probability,
      });
    } else {
      // Negative prediction (first class)
      results.add({
        'label': binaryLabels[0],
        'confidence': 1.0 - probability,
      });
      results.add({
        'label': binaryLabels[1],
        'confidence': probability,
      });
    }
    
    return results;
  }

  List<List<List<List<double>>>> imageToByteBuffer(img.Image originalImage) {
    
    // Get expected input dimensions from the model
    final inputTensor = _interpreter.getInputTensor(0);
    final inputShape = inputTensor.shape;
    final expectedHeight = inputShape[1];
    final expectedWidth = inputShape[2];
        
    // Resize image to match model's expected input size
    img.Image resizedImage = img.copyResize(
      originalImage,
      width: expectedWidth,
      height: expectedHeight,
      interpolation: img.Interpolation.linear,
    );
    
    
    // Convert to the expected format
    final buffer = List.generate(
      1, // batch size
      (_) => List.generate(
        expectedHeight,
        (y) => List.generate(
          expectedWidth,
          (x) {
            final pixel = resizedImage.getPixel(x, y);

            // Access RGB channels directly
            final r = pixel.r;
            final g = pixel.g;
            final b = pixel.b;
            
            // Normalize to [0, 1] range
            return [
              r / 255.0,
              g / 255.0,
              b / 255.0,
            ];
          },
        ),
      ),
    );
        
    return buffer;
  }

  void dispose() {
    _interpreter.close();
  }
}