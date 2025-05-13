import 'package:flutter/material.dart';
import 'report.dart';



class ReportDetailScreen extends StatelessWidget {
  final Report report;
  const ReportDetailScreen({Key? key, required this.report}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Safely check for a non-null, non-empty imagePath
    final hasImage = report.imagePath != null && report.imagePath!.isNotEmpty;
    
    return Scaffold(
      appBar: AppBar(title: Text('Report Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
    if (hasImage) ...[
  ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.network(
      'http://192.168.1.103:5000${report.imagePath}',
      errorBuilder: (_, __, ___) => SizedBox.shrink(),
      width: double.infinity,
      fit: BoxFit.cover,
    ),
  ),
  SizedBox(height: 16),
],

            Text('Reported by: ${report.userName}', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),

            Text('Issues:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...report.issues.map((i) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 2.0),
  child: Text('• $i'),
)).toList(),

            Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(report.details.isNotEmpty ? report.details : '—'),
            SizedBox(height: 16),

            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Expanded(child: Text(report.location)),
              ],
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Chip(label: Text(report.status)),
                Spacer(),
                Text(
                  '${DateTime.now().difference(report.createdAt).inHours}h ago',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
