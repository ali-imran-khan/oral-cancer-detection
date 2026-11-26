import 'package:supabase_flutter/supabase_flutter.dart';

class AnalysisHistoryService {
  final SupabaseClient client;
  final String tableName = 'oral_cancer_analysis_history';

  AnalysisHistoryService(this.client);

  Future<List<Map<String, dynamic>>> getUserAnalysisHistory(String userId) async {
  final response = await client
    .from(tableName)
    .select()
    .eq('user_id', userId)
    .order('analysis_date', ascending: false);
  return List<Map<String, dynamic>>.from(response);
  }
}
