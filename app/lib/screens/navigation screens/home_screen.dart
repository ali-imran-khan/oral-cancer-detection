import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../supabase/analysis_history_service.dart';
import '../navigation_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onOpenScan;
  const HomeScreen({super.key, required this.onOpenScan});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _showHealthTipsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.health_and_safety, color: Colors.green, size: 28),
            ),
            const SizedBox(width: 12),
            Text('Oral Health Tips', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green.shade700)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tipRow(Icons.brush, 'Brush your teeth twice daily with fluoride toothpaste (1000–1500 ppm).'),
              const SizedBox(height: 12),
              _tipRow(Icons.local_drink, 'Eat a well-balanced diet low in free sugars and high in fruits and vegetables; drink water as your main beverage.'),
              const SizedBox(height: 12),
              _tipRow(Icons.smoke_free, 'Stop all forms of tobacco use, including chewing areca nuts.'),
              const SizedBox(height: 12),
              _tipRow(Icons.no_drinks, 'Reduce alcohol consumption.'),
              const SizedBox(height: 12),
              _tipRow(Icons.cleaning_services, 'Remove plaque by regular toothbrushing and flossing.'),
              const SizedBox(height: 12),
              _tipRow(Icons.sports_martial_arts, 'Use protective equipment during sports and travel to prevent facial injuries.'),
              const SizedBox(height: 12),
              _tipRow(Icons.medical_services, 'Visit your dentist regularly for checkups and early treatment.'),
              const SizedBox(height: 12),
              _tipRow(Icons.water_drop, 'Ensure adequate exposure to fluoride (in water or oral hygiene products).'),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _tipRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.green.shade700, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
        ),
      ],
    );
  }
  String _formatDate(DateTime date) {
    final day = date.day;
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    String suffix;
    if (day >= 11 && day <= 13) {
      suffix = 'th';
    } else {
      switch (day % 10) {
        case 1:
          suffix = 'st';
          break;
        case 2:
          suffix = 'nd';
          break;
        case 3:
          suffix = 'rd';
          break;
        default:
          suffix = 'th';
      }
    }
    return '$day$suffix ${monthNames[date.month - 1]} ${date.year}';
  }
  late Future<List<Map<String, dynamic>>> _recentReportsFuture;

  @override
  void initState() {
    super.initState();
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final historyService = AnalysisHistoryService(supabase);
    if (user != null) {
      _recentReportsFuture = historyService.getUserAnalysisHistory(user.id);
    } else {
      _recentReportsFuture = Future.value([]);
    }
  }

  void _navigateToReportsTab(BuildContext context) {
    // Use the nearest NavigationScreen's state to switch tab
    final navState = context.findAncestorStateOfType<NavigationScreenState>();
    if (navState != null) {
      navState.onItemTapped(2); // 2 is the index for Reports tab
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ...existing code...
            Text('Oral Health Scanner', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('Early detection for better oral health', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),

            // ...existing code...
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.camera_alt, size: 48, color: Colors.blueAccent),
                  const SizedBox(height: 12),
                  Text('Start Examination', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Capture images for oral health analysis', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: widget.onOpenScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text('Open Camera'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ...existing code...
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: widget.onOpenScan,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.add, color: Colors.blueAccent),
                          const SizedBox(height: 8),
                          Text('New Scan', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Quick capture', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _showHealthTipsModal(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.health_and_safety, color: Colors.green),
                          const SizedBox(height: 8),
                          Text('Health Tips', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Prevention guide', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Reports
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Reports', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: () => _navigateToReportsTab(context),
                        child: Text('View All', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.blueAccent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _recentReportsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final reports = snapshot.data ?? [];
                      if (reports.isEmpty) {
                        return Text('No recent reports found.', style: Theme.of(context).textTheme.bodyMedium);
                      }
                      return Column(
                        children: List.generate(
                          reports.length > 2 ? 2 : reports.length,
                          (i) {
                            final item = reports[i];
                            final date = item['analysis_date'] != null
                                ? DateTime.parse(item['analysis_date']).toLocal()
                                : null;
                            final label = (item['results'] is List && item['results'].isNotEmpty)
                                ? item['results'][0]['label']?.toString() ?? 'Unknown'
                                : 'Unknown';
                            final confidence = (item['results'] is List && item['results'].isNotEmpty)
                                ? (item['results'][0]['confidence'] * 100).toStringAsFixed(1)
                                : '--';
                            final color = label.toLowerCase().contains('cancer')
                                ? Colors.red
                                : Colors.green;
                            return _reportCard(context,
                              date != null ? _formatDate(date) : 'Unknown',
                              label,
                              '$confidence%',
                              color,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ...existing code...
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Emergency Contact', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        Text('Call your doctor if you notice any concerning symptoms', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.redAccent, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportCard(BuildContext context, String date, String status, String risk, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(status, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
              ],
            ),
          ),
          Text(risk, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
