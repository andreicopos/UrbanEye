import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';             // ← new
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'report.dart';
import 'report_card.dart';
import 'report_detail_screen.dart';

class HomePageScreen extends StatefulWidget {
  @override
  _HomePageScreenState createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> {
  int _tabIndex = 0;
  List<Report> _reports = [];
  bool _loading = true;
  late Map<String, dynamic> _user;

  @override
  void initState() {
    super.initState();
    _loadUserAndReports();
  }

  Future<void> _loadUserAndReports() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson == null) return;
    _user = json.decode(userJson) as Map<String, dynamic>;
    await fetchReports();
  }

  Future<void> fetchReports() async {
    setState(() => _loading = true);

    // 1) Grab all reports
    final url = Uri.parse('http://192.168.1.103:5000/reports');
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('Failed to load reports');
    }
    var list = (json.decode(res.body) as List)
        .map((j) => Report.fromJson(j))
        .toList();

    // 2) Nearby: sort by distance
    if (_tabIndex == 0) {
      try {
        // Ask permission if needed
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.always ||
            perm == LocationPermission.whileInUse) {
          // Get user location
          final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high);

          // Helper to parse "Lat: x, Lon: y" into a LatLng
          LatLng? parseLoc(String loc) {
            final parts = loc.replaceAll('Lat:', '')
                              .replaceAll('Lon:', '')
                              .split(',');
            if (parts.length != 2) return null;
            final lat = double.tryParse(parts[0].trim());
            final lon = double.tryParse(parts[1].trim());
            if (lat == null || lon == null) return null;
            return LatLng(lat, lon);
          }

          // Compute and attach distances
          final userLat = pos.latitude;
          final userLon = pos.longitude;
          final distances = <Report, double>{};
          for (var rpt in list) {
            final ll = parseLoc(rpt.location);
            if (ll != null) {
              distances[rpt] = Geolocator.distanceBetween(
                userLat, userLon, ll.latitude, ll.longitude
              );
            } else {
              distances[rpt] = double.infinity;
            }
          }

          // Sort ascending by distance
          list.sort((a, b) =>
            distances[a]!.compareTo(distances[b]!)
          );
        }
      } catch (e) {
        // If location fails, silently leave in server order
        debugPrint('Location error: $e');
      }
    }

    // 3) Trending tab: sort by likes
    if (_tabIndex == 1) {
      list.sort((a, b) => b.likes.compareTo(a.likes));
    }

    // 4) My Reports tab: filter by user
    if (_tabIndex == 2) {
      list = list.where((r) => r.userId == _user['id']).toList();
    }

    setState(() {
      _reports = list;
      _loading = false;
    });
  }

  String get _title {
    switch (_tabIndex) {
      case 1:
        return 'Trending Issues';
      case 2:
        return 'My Reports';
      default:
        return 'Nearby Issues';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? Center(
                  child: Text(
                    _tabIndex == 2
                        ? 'You have no reports yet.'
                        : 'No reports found.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.builder(
                  itemCount: _reports.length,
                  itemBuilder: (ctx, i) {
                    final rpt = _reports[i];
                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReportDetailScreen(report: rpt),
                        ),
                      ),
                      child: ReportCard(report: rpt),
                    );
                  },
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.place), label: 'Nearby'),
          BottomNavigationBarItem(
              icon: Icon(Icons.trending_up), label: 'Trending'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'My Reports'),
        ],
        onTap: (i) {
          setState(() => _tabIndex = i);
          fetchReports();
        },
      ),
    );
  }
}
