import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalysisService {
  final SupabaseClient client;
  final String bucketName = 'oral-cancer-images';
  final String tableName = 'oral_cancer_analysis_history';

  AnalysisService(this.client);

  Future<String> uploadImageToStorage(File imageFile, String userId) async {
    final String fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final response = await client.storage.from(bucketName).upload(
      fileName,
      imageFile,
      fileOptions: const FileOptions(upsert: true),
    );
    if (response.isEmpty) {
      throw Exception('Image upload failed: Empty response from Supabase Storage');
    }
    // Get public URL
    final publicUrl = client.storage.from(bucketName).getPublicUrl(fileName);
    return publicUrl;
  }

  Future<void> saveAnalysisResult({
    required String userId,
    required String imageUrl,
    required List<Map<String, dynamic>> results,
    required double oralTissuePercentage,
    String? errorMessage,
  }) async {
    final response = await client.from(tableName).insert({
      'user_id': userId,
      'image_url': imageUrl,
      'results': results,
      'oral_tissue_percentage': oralTissuePercentage,
      'error_message': errorMessage,
    }).select().single();
    if (response['id'] == null) {
      throw Exception('Failed to save analysis result: No ID returned');
    }
  }
}
