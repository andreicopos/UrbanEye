import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';  // <-- adjust import to your actual login screen path

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyReports();
  }

  Future<void> _fetchMyReports() async {
    try {
      final res = await http.get(
        Uri.parse(
          'http://192.168.1.103:5000/my_reports?user_id=${widget.user['id']}',
        ),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        setState(() {
          _reports = data.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        throw Exception('Failed to load reports (${res.statusCode})');
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching reports: $e')),
      );
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    // Navigate to login screen and remove this one from the stack
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '${widget.user['name']} ${widget.user['surname']}',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                    ? Center(child: Text('You have no reports yet.'))
                    : ListView.builder(
                        itemCount: _reports.length,
                        itemBuilder: (_, i) {
                          final rpt = _reports[i];
                          final issues = (rpt['issues'] as List).join(', ');
                          return ListTile(
                            leading: Icon(Icons.report_problem),
                            title: Text(issues),
                            subtitle: Text('On ${rpt['created_at']}'),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
