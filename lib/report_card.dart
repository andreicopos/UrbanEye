import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';      // <-- add this
import 'report.dart';
import 'report_detail_screen.dart';

class ReportCard extends StatefulWidget {
  final Report report;
  const ReportCard({Key? key, required this.report}) : super(key: key);

  @override
  _ReportCardState createState() => _ReportCardState();
}

class _ReportCardState extends State<ReportCard> {
  late int likes;

  @override
  void initState() {
    super.initState();
    likes = widget.report.likes;
  }

  Future<void> _likeReport() async {
    // 1) Get stored user from prefs
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson == null) {
      // not logged in
      return;
    }
    final user = json.decode(userJson) as Map<String, dynamic>;
    final userId = user['id'];

    // 2) Send POST with JSON { user_id }
    final url = Uri.parse(
      'http://192.168.1.103:5000/reports/${widget.report.id}/like'
    );
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId}),
    );

    // 3) Handle response
    if (res.statusCode == 200 || res.statusCode == 201) {
      final newLikes = json.decode(res.body)['likes'] as int;
      setState(() => likes = newLikes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('👍 $newLikes likes')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to like report')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportDetailScreen(report: widget.report),
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.report.imagePath?.isNotEmpty ?? false)
              Image.network(
                'http://192.168.1.103:5000${widget.report.imagePath}',
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.report.issues.first,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Chip(
                    label: Text(
    widget.report.status.isNotEmpty
      ? widget.report.status[0].toUpperCase() + widget.report.status.substring(1)
      : widget.report.status
  ),
                    backgroundColor: widget.report.status == 'In Progress'
                        ? Colors.blue[100]
                        : Colors.orange[100],
                  ),
                  const SizedBox(height: 8),
                  Text(widget.report.details,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(widget.report.location,
                            style: const TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${DateTime.now().difference(widget.report.createdAt).inHours - 3}h ago',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // like‐button row
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('$likes'),
                  IconButton(
                    icon: const Icon(Icons.thumb_up_alt_outlined),
                    onPressed: _likeReport,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
