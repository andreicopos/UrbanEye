// lib/admin_main.dart
import 'package:flutter/material.dart';
import 'admin_screens/admin_home_screen.dart';

void main() => runApp(const AdminApp());

class AdminApp extends StatelessWidget {
  const AdminApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UrbanEye Admin',
      home: const AdminHomeScreen(),
    );
  }
}
