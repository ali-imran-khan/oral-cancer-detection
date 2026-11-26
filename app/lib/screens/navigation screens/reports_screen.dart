import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../supabase/analysis_history_service.dart';
import '../analysis_result_screen.dart';
import '../navigation_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _historyFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final historyService = AnalysisHistoryService(supabase);
    if (user != null) {
      _historyFuture = historyService.getUserAnalysisHistory(user.id);
    } else {
      _historyFuture = Future.value([]);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blueAccent,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'All Reports'),
                Tab(text: 'Recent'),
                Tab(text: 'Concerns'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildReportsView('all'),
                _buildReportsView('recent'),
                _buildReportsView('concerns'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsView(String filter) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }
        
        List<Map<String, dynamic>> history = snapshot.data ?? [];
        
        // Apply filters
        if (filter == 'recent') {
          final now = DateTime.now();
          history = history.where((item) {
            if (item['analysis_date'] == null) return false;
            final date = DateTime.parse(item['analysis_date']);
            return now.difference(date).inDays <= 7;
          }).toList();
        } else if (filter == 'concerns') {
          history = history.where((item) {
            final label = (item['results'] is List && item['results'].isNotEmpty)
                ? item['results'][0]['label']?.toString().toLowerCase() ?? ''
                : '';
            return label.contains('cancer') || label.contains('concern') || label.contains('abnormal');
          }).toList();
        }
        
        if (history.isEmpty) {
          return _buildEmptyState(filter);
        }
        
        return _buildReportsList(history);
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: Colors.blueAccent,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your reports...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load your reports. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  final supabase = Supabase.instance.client;
                  final user = supabase.auth.currentUser;
                  final historyService = AnalysisHistoryService(supabase);
                  if (user != null) {
                    _historyFuture = historyService.getUserAnalysisHistory(user.id);
                  }
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String filter) {
    String title, subtitle;
    IconData icon;
    
    switch (filter) {
      case 'recent':
        title = 'No Recent Reports';
        subtitle = 'You haven\'t had any scans in the past 7 days.';
        icon = Icons.schedule;
        break;
      case 'concerns':
        title = 'No Concerns Found';
        subtitle = 'Great news! No concerning results in your reports.';
        icon = Icons.check_circle_outline;
        break;
      default:
        title = 'No Reports Yet';
        subtitle = 'Start your first oral health scan to see reports here.';
        icon = Icons.assessment_outlined;
    }
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 80,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                height: 1.5,
              ),
            ),
            if (filter == 'all') ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // Switch to Scan tab via PageView
                  final navState = context.findAncestorStateOfType<NavigationScreenState>();
                  if (navState != null) {
                    navState.onItemTapped(1); // 1 is the index for Scan tab
                  }
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('Start First Scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportsList(List<Map<String, dynamic>> history) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];
        final date = item['analysis_date'] != null
            ? DateTime.parse(item['analysis_date']).toLocal()
            : null;
        final label = (item['results'] is List && item['results'].isNotEmpty)
            ? item['results'][0]['label']?.toString() ?? 'Unknown'
            : 'Unknown';
        final confidence = (item['results'] is List && item['results'].isNotEmpty)
            ? (item['results'][0]['confidence'] * 100).toStringAsFixed(1)
            : '--';
        
        final isConcern = label.toLowerCase().contains('cancer') || 
                         label.toLowerCase().contains('abnormal') ||
                         label.toLowerCase().contains('concern');
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                // Open analysis result screen, passing all relevant history fields
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OralCancerAnalysisResultScreen(
                      imagePath: item['image_url'] ?? '',
                      results: item['results'] is List ? List<Map<String, dynamic>>.from(item['results']) : null,
                      oralTissuePercentage: item['oral_tissue_percentage'] is num ? (item['oral_tissue_percentage'] as num).toDouble() : null,
                      errorMessage: item['error_message'] as String?,
                      fromHistory: true,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Image Container
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[100],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item['image_url'] != null
                            ? Image.network(
                                item['image_url'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey[400],
                                      size: 30,
                                    ),
                                  );
                                },
                              )
                            : Icon(
                                Icons.image,
                                color: Colors.grey[400],
                                size: 30,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _formatLabel(label),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isConcern 
                                    ? Colors.red.withValues(alpha: 0.1)
                                    : Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isConcern ? Icons.warning_amber : Icons.check_circle,
                                      color: isConcern ? Colors.red : Colors.green,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$confidence%',
                                      style: TextStyle(
                                        color: isConcern ? Colors.red : Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (date != null) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(date),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            'Tap to view detailed analysis',
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Arrow Icon
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[400],
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatLabel(String label) {
    // Capitalize and format the label nicely
    if (label.toLowerCase() == 'unknown') return 'Analysis Complete';
    return label.split('_').map((word) => 
        word[0].toUpperCase() + word.substring(1).toLowerCase()).join(' ');
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today, ${_formatTime(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${_formatTime(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    int hour = date.hour % 12;
    if (hour == 0) hour = 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}