import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model_inference.dart';
import '../supabase/analysis_service.dart';

// Function to detect oral tissue percentage (moved from model_inference.dart for access)
double _detectOralTissuePercentage(img.Image image) {
  int oralTissuePixelCount = 0;
  int totalPixelCount = image.width * image.height;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final r = pixel.r;
      final g = pixel.g;
      final b = pixel.b;

      final hsv = _rgbToHsv(r.toInt(), g.toInt(), b.toInt());
      final h = hsv[0], s = hsv[1], v = hsv[2];

      final ycrcb = _rgbToYCrCb(r.toInt(), g.toInt(), b.toInt());
      final cr = ycrcb[1], cb = ycrcb[2];

      // Adapted for oral tissue detection (pinkish/red tones)
      bool hsvCond = ((h >= 330 && h <= 360) || (h >= 0 && h <= 30)) && (s >= 0.04 && s <= 1.0) && (v >= 0.12);
      bool ycrcbCond = (cr >= 120 && cr <= 180) && (cb >= 70 && cb <= 150);

      if (hsvCond && ycrcbCond) {
        oralTissuePixelCount++;
      }
    }
  }

  return (oralTissuePixelCount / totalPixelCount) * 100;
}

List<double> _rgbToHsv(int r, int g, int b) {
  double rP = r / 255.0;
  double gP = g / 255.0;
  double bP = b / 255.0;

  double max = [rP, gP, bP].reduce((a, b) => a > b ? a : b).toDouble();
  double min = [rP, gP, bP].reduce((a, b) => a < b ? a : b).toDouble();
  double delta = max - min;

  double h = 0;
  if (delta != 0) {
    if (max == rP) {
      h = (60 * ((gP - bP) / delta) + 360) % 360;
    } else if (max == gP) {
      h = (60 * ((bP - rP) / delta) + 120) % 360;
    } else {
      h = (60 * ((rP - gP) / delta) + 240) % 360;
    }
  }

  double s = max == 0 ? 0 : delta / max;
  double v = max;

  return [h, s, v];
}

List<double> _rgbToYCrCb(int r, int g, int b) {
  double rD = r.toDouble();
  double gD = g.toDouble();
  double bD = b.toDouble();

  double y = 0.299 * rD + 0.587 * gD + 0.114 * bD;
  double cr = (rD - y) * 0.713 + 128;
  double cb = (bD - y) * 0.564 + 128;

  return [y, cr, cb];
}

class OralCancerAnalysisResultScreen extends StatefulWidget {
  final String imagePath;
  final List<Map<String, dynamic>>? results;
  final double? oralTissuePercentage;
  final String? errorMessage;
  final bool fromHistory;

  const OralCancerAnalysisResultScreen({
    super.key,
    required this.imagePath,
    this.results,
    this.oralTissuePercentage,
    this.errorMessage,
    this.fromHistory = false,
  });

  @override
  State<OralCancerAnalysisResultScreen> createState() => _OralCancerAnalysisResultScreenState();
}

class _OralCancerAnalysisResultScreenState extends State<OralCancerAnalysisResultScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>>? _results;
  String? _errorMessage;
  final List<String> _labels = [];
  String? _uploadedFileId;
  bool _uploadCompleted = false;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.imagePath.startsWith('http')) {
      // Network image: use passed results and error message
      setState(() {
        _imageUrl = widget.imagePath;
        _results = widget.results;
        _errorMessage = widget.errorMessage;
        _isLoading = false;
      });
    } else {
      _loadModel();
    }
  }

  Future<void> _loadModel() async {
    try {
      final labelData = await rootBundle.loadString('assets/labels.txt');
      setState(() {
        // Fix label parsing - properly split and clean labels
        _labels.addAll(
          labelData.split('\n')
              .map((label) => label.trim())
              .where((label) => label.isNotEmpty)
              .toList()
        );
      });

      await _runInference();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load model: ${e.toString()}';
        _isLoading = false;
      });
    }
  }



  Future<void> _runInference() async {
    try {
      final imageFile = File(widget.imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception("Failed to decode image");

      final oralTissuePercentage = _detectOralTissuePercentage(image);

      if (oralTissuePercentage < 2) {
        setState(() {
          _errorMessage = 'No visible oral tissue detected in image. Please retake the photo.';
          _isLoading = false;
        });
        return;
      }

      List<String> binaryLabels;
      if (_labels.length >= 2) {
        binaryLabels = [_labels[0], _labels[1]];
      } else if (_labels.length == 1) {
        binaryLabels = [_labels[0], 'Oral Cancer'];
      } else {
        binaryLabels = ['Normal', 'Oral Cancer'];
      }

      final model = OralCancerModel();
      await model.loadModel();
      final inputBuffer = model.imageToByteBuffer(image);
      final results = await model.predict(inputBuffer, binaryLabels);
      model.dispose();

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Analysis failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oral Cancer Analysis Results'),
        actions: [
          // Show upload status icon
          if (_uploadCompleted)
            IconButton(
              icon: const Icon(Icons.cloud_done),
              color: Colors.green,
              onPressed: () => _showUploadInfo(context),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingUI()
          : _errorMessage != null
          ? _buildErrorUI()
          : _buildResultsUI(),
    );
  }

  Widget _buildLoadingUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Analyzing oral tissue image...',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'This may take a moment',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 80),
            const SizedBox(height: 24),
            Text(
              'Error',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.red.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.red.shade700),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsUI() {
    final topResult = _results?.isNotEmpty == true ? _results![0] : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image section with overlay gradient
          Stack(
            children: [
              SizedBox(
                height: 240,
                width: double.infinity,
                child: widget.imagePath.startsWith('http')
                  ? Image.network(
                      widget.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Image not available', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Image not available', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: Row(
                  children: [
                    Text(
                      'Oral Cancer Analysis',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_uploadCompleted) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.cloud_done,
                        color: Colors.green,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Upload status section
          if (_uploadCompleted)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_upload, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Image uploaded to server successfully',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Primary result section
          if (topResult != null)
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Primary Assessment',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      topResult['label'],
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: topResult['label'].toString().toLowerCase().contains('cancer') 
                            ? Colors.red.shade700 
                            : Colors.green.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _buildConfidenceIndicator(topResult['confidence']),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This is an AI assessment and not a medical diagnosis. '
                                  'Please consult a healthcare professional immediately if you have concerns.',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Detailed results section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detailed Results',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._buildResultsList(),
                  ],
                ),
              ),
            ),
          ),

          // Add space below detailed results if fromHistory
          if (widget.fromHistory)
            const SizedBox(height: 32),

          // Action buttons section (hide if fromHistory)
          if (!widget.fromHistory)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('New Capture'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _uploadCompleted
                          ? const Icon(Icons.check_circle, color: Colors.white)
                          : const Icon(Icons.save_alt),
                      label: _uploadCompleted
                          ? const Text('Saved')
                          : const Text('Save Results'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _uploadCompleted ? null : _saveResults,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConfidenceIndicator(double confidence) {
    final percentage = (confidence * 100).round();
    final color = _getConfidenceColor(confidence);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Confidence: ',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            FractionallySizedBox(
              widthFactor: confidence,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.7) return Colors.green.shade600;
    if (confidence >= 0.4) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  List<Widget> _buildResultsList() {
    if (_results == null || _results!.isEmpty) {
      return [const Text('No results available')];
    }

    return _results!.map((result) {
      final confidence = result['confidence'];
      final percentage = (confidence * 100).round();
      final color = _getConfidenceColor(confidence);
      final isTopResult = result == _results![0];

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isTopResult ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isTopResult ? Border.all(color: color.withValues(alpha: 0.3)) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      result['label'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isTopResult ? FontWeight.bold : FontWeight.w500,
                        color: isTopResult ? color : null,
                      ),
                    ),
                  ),
                  if (isTopResult) 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Primary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Stack(
                children: [
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: confidence,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Future<void> _saveResults() async {
    try {
      if (_results == null || _results!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No results to save.'),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final imageFile = File(widget.imagePath);
      final supabase = Supabase.instance.client;
      final analysisService = AnalysisService(supabase);
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Upload image to Supabase Storage
      final imageUrl = await analysisService.uploadImageToStorage(imageFile, user.id);
      setState(() {
        _imageUrl = imageUrl;
      });

      // Save analysis result to Supabase table
      await analysisService.saveAnalysisResult(
        userId: user.id,
        imageUrl: imageUrl,
        results: _results!,
        oralTissuePercentage: _detectOralTissuePercentage(img.decodeImage(await imageFile.readAsBytes())!),
        errorMessage: _errorMessage,
      );

      setState(() {
        _uploadCompleted = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Results saved to Supabase successfully'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save results: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showUploadInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud_done, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Text('Upload Status'),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Image successfully uploaded to server!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_uploadedFileId != null) ...[
              const Text('File ID:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              SelectableText(
                _uploadedFileId!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('Disclaimer'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This app provides an AI-powered oral cancer screening tool with the following limitations:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('• The analysis is performed using machine learning trained on specific datasets'),
              Text('• Results may vary and are not 100% accurate'),
              Text('• This is NOT a substitute for professional medical examination'),
              Text('• Do not use this app in emergency situations'),
              Text('• Images may be uploaded to server for research purposes'),
              SizedBox(height: 16),
              Text(
                'IMPORTANT: Always consult with a qualified healthcare provider or dentist for proper diagnosis and treatment of any oral health concerns.',
                style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }
}