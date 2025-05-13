import 'package:flutter/material.dart';
import '../report.dart';
import '../services/api_service.dart';
import 'admin_report_detail.dart';

// Capitalize helper
extension StringCap on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}

class AdminReportList extends StatefulWidget {
  final String? status; // optional initial status filter
  const AdminReportList({Key? key, this.status}) : super(key: key);

  @override
  _AdminReportListState createState() => _AdminReportListState();
}

class _AdminReportListState extends State<AdminReportList> {
  // paging & filter state
  int    _page         = 1;
  String _sortBy       = 'date';
  String _order        = 'desc';
  String? _filterIssue;
  String? _filterStatus;
  late Future<List<Report>> _futureReports;

  // dropdown options
  final _issueOptions  = [
    'Pothole', 'Overgrown Grass', 'Graffiti',
    'Faded Road Lines','Trash','Trashcan Overflow','Other'
  ];
  final _statusOptions = ['pending','solving','done'];

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.status;
    _loadReports();
  }

  void _loadReports() {
    setState(() {
      _futureReports = ApiService.fetchReportsAdmin(
        page:    _page,
        perPage: 10,
        sortBy:  _sortBy,
        order:   _order,
        issue:   _filterIssue,
        status:  _filterStatus,
      );
    });
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          // Sort by
          DropdownButton<String>(
            value: _sortBy,
            items: const [
              DropdownMenuItem(value: 'date', child: Text('Date')),
              DropdownMenuItem(value: 'likes', child: Text('Likes')),
            ],
            onChanged: (v) { _sortBy = v!; _loadReports(); },
          ),

          // Asc / Desc
          IconButton(
            icon: Icon(_order=='asc' ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () {
              _order = _order=='asc' ? 'desc' : 'asc';
              _loadReports();
            },
          ),

          const SizedBox(width: 16),

          // Issue filter
          DropdownButton<String>(
            hint: const Text('Issue'),
            value: _filterIssue,
            items: [null, ..._issueOptions].map((s) {
              return DropdownMenuItem(value: s, child: Text(s ?? 'All'));
            }).toList(),
            onChanged: (v) {
              _filterIssue = v;
              _page = 1;
              _loadReports();
            },
          ),

          const SizedBox(width: 16),

          // Status filter
          DropdownButton<String>(
            hint: const Text('Status'),
            value: _filterStatus,
            items: [null, ..._statusOptions].map((s) {
              return DropdownMenuItem(
                value: s,
                child: Text(s==null ? 'All' : s.capitalize()),
              );
            }).toList(),
            onChanged: (v) {
              _filterStatus = v;
              _page = 1;
              _loadReports();
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildFilterBar(),
      const Divider(height: 1),
      Expanded(
        child: FutureBuilder<List<Report>>(
          future: _futureReports,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            final list = snap.data!;
            if (list.isEmpty) {
              return const Center(child: Text('No reports found.'));
            }
            return Column(children: [
              // the paged list
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final rpt = list[i];
                    final imageUrl = rpt.imagePath != null
                      ? 'http://192.168.1.103:5000${rpt.imagePath}'
                      : null;
                    return ListTile(
                      leading: imageUrl != null
                        ? Image.network(imageUrl, width:56, height:56, fit:BoxFit.cover)
                        : const Icon(Icons.report),
                      title: Text(rpt.issues.first),
                      subtitle: Text('Status: ${rpt.status.capitalize()}'),
                      onTap: () async {
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminReportDetail(report: rpt),
                          ),
                        );
                        if (changed == true) _loadReports();
                      },
                    );
                  },
                ),
              ),

              // Prev / Next
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _page>1
                          ? () { _page--; _loadReports(); }
                          : null,
                      child: const Text('◀ Prev'),
                    ),

                    Text('Page $_page'),

                    TextButton(
                      onPressed: list.length==10
                          ? () { _page++; _loadReports(); }
                          : null,
                      child: const Text('Next ▶'),
                    ),
                  ],
                ),
              ),
            ]);
          },
        ),
      ),
    ]);
  }
}
