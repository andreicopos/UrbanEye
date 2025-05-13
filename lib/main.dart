import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'main_screen.dart';

void main() {
  runApp(UrbanEyeApp());
}

class UrbanEyeApp extends StatelessWidget {
  Future<Widget> getStartScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    final lastLogin = prefs.getString('lastLogin');

    if (userJson != null && lastLogin != null) {
      final lastLoginTime = DateTime.parse(lastLogin);
      final now = DateTime.now();

      // If within 3 months
      if (now.difference(lastLoginTime).inDays <= 90) {
        final user = json.decode(userJson);
        return MainScreen(user: user);
      }
    }

    return LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UrbanEye',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: FutureBuilder<Widget>(
        future: getStartScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return snapshot.data!;
          } else {
            return Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
        },
      ),
    );
  }
}
