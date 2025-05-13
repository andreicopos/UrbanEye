import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../report.dart';

class AdminReportDetail extends StatefulWidget {
  final Report report;
  const AdminReportDetail({Key? key, required this.report}) : super(key: key);

  @override
  _AdminReportDetailState createState() => _AdminReportDetailState();
}

class _AdminReportDetailState extends State<AdminReportDetail> {
  // These are the only valid statuses (keys are lowercase)
  static const _statusKeys = ['pending', 'solving', 'done'];

  // Holds the current chosen key, always lowercase
  late String _statusKey;

  @override
  void initState() {
    super.initState();
    // Normalize whatever the server gave us to lowercase
    _statusKey = widget.report.status.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    // Build a nice label from the key: capitalize the first letter
    String _label(String key) =>
        key[0].toUpperCase() + key.substring(1);

    return Scaffold(
      appBar: AppBar(title: const Text('Report Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // your image, description, etc.
            if (widget.report.imagePath?.isNotEmpty ?? false)
              Image.network('http://192.168.1.103:5000${widget.report.imagePath}'),
            const SizedBox(height: 12),
            Text(widget.report.issues.isNotEmpty
                ? widget.report.issues.first
                : 'No issue',
              style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(widget.report.details),
            const SizedBox(height: 16),

            // **Normalized** dropdown
            DropdownButton<String>(
              value: _statusKey,
              items: _statusKeys.map((key) {
                return DropdownMenuItem(
                  value: key,
                  child: Text(_label(key)),
                );
              }).toList(),
              onChanged: (key) {
                if (key != null) setState(() => _statusKey = key);
              },
            ),

            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                // send the lowercase key to the server
                await ApiService.updateReportStatus(
                  widget.report.id, _statusKey);
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}