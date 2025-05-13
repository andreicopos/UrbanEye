import 'package:flutter/material.dart';
import 'admin_report_list.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({Key? key}) : super(key: key);

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;

  // Four tabs: All, Pending, Solving, Done
  final _tabs = [
  AdminReportList(status: null),
  AdminReportList(status: 'Pending'),
  AdminReportList(status: 'Solving'),
  AdminReportList(status: 'Done'),
];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UrbanEye Admin')),
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list), label: 'All'),
          BottomNavigationBarItem(
            icon: Icon(Icons.hourglass_empty), label: 'Pending'),
          BottomNavigationBarItem(
            icon: Icon(Icons.build), label: 'Solving'),
          BottomNavigationBarItem(
            icon: Icon(Icons.check), label: 'Done'),
        ],
      ),
    );
  }
}
