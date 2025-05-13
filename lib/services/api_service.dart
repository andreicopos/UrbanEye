// lib/services/api_service.dart

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../report.dart';

class ApiService {
  // If you're on Android emulator, use 10.0.2.2 instead of localhost:
  static const _baseUrl = 'http://192.168.1.103:5000';

  /// User-side method stays the same:
  static Future<List<Report>> fetchReports({String? status}) async {
    final uri = Uri.parse('$_baseUrl/reports');
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Failed to load reports');
    final data = json.decode(res.body) as List;
    var list = data.map((j) => Report.fromJson(j)).toList();
    if (status != null) {
      list = list.where((r) => r.status.toLowerCase() == status.toLowerCase()).toList();
    }
    return list;
  }

  /// New admin fetch: client-side paging + sorting + filtering
  static Future<List<Report>> fetchReportsAdmin({
    required int page,
    int perPage = 10,
    String sortBy = 'date',    // 'date' or 'likes'
    String order  = 'desc',    // 'asc' or 'desc'
    String? issue,             // e.g. 'Pothole'
    String? status,            // 'pending','solving','done'
  }) async {
    // 1. Grab everything
    final uri = Uri.parse('$_baseUrl/reports');
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Failed to load admin reports');
    final data = json.decode(res.body) as List;
    var list = data.map((j) => Report.fromJson(j)).toList();

    // 2. Apply issue filter
    if (issue != null) {
      list = list.where((r) => r.issues.contains(issue)).toList();
    }

    // 3. Apply status filter
    if (status != null) {
      list = list.where((r) => r.status.toLowerCase() == status.toLowerCase()).toList();
    }

    // 4. Sort
    int cmp(Report a, Report b) {
      if (sortBy == 'likes') {
        return a.likes.compareTo(b.likes);
      } else {
        return a.createdAt.compareTo(b.createdAt);
      }
    }
    list.sort(cmp);
    if (order == 'desc') {
      list = list.reversed.toList();
    }

    // 5. Paginate
    final start = (page - 1) * perPage;
    if (start >= list.length) return [];
    final end = min(start + perPage, list.length);
    return list.sublist(start, end);
  }

  /// (unchanged) status-update endpoint
  static Future<void> updateReportStatus(int id, String status) async {
    final uri = Uri.parse('$_baseUrl/reports/$id/status');
    final res = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'status': status.toLowerCase()}),
    );
    if (res.statusCode != 200) throw Exception('Failed to update status');
  }
}
