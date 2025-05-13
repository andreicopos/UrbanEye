import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'result_screen.dart';

Future<Map<String, dynamic>?> sendImageToServer(File imageFile) async {
  print('Sending image to server...');
  var request = http.MultipartRequest('POST', Uri.parse('http://192.168.1.103:5000/analyze'));

  request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

  var response = await request.send();
  print('Got response status: ${response.statusCode}');

  if (response.statusCode == 200) {
    var responseData = await response.stream.bytesToString();
    print('Response data: $responseData');
    return json.decode(responseData);
  } else {
    print('Server error: ${response.statusCode}');
    return null;
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Gallery'),
                onTap: () async {
                  final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                  Navigator.pop(context);
                  _goToResultScreen(pickedFile);
                }),
            ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Camera'),
                onTap: () async {
                  final pickedFile = await _picker.pickImage(source: ImageSource.camera);
                  Navigator.pop(context);
                  _goToResultScreen(pickedFile);
                }),
          ],
        ),
      );
    },
  );
}

void _goToResultScreen(XFile? pickedFile) async {
  if (pickedFile != null) {
    File file = File(pickedFile.path);

    // Show a loading indicator while waiting for server
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    var result = await sendImageToServer(file);

    Navigator.pop(context); // Close loading spinner

    if (result != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            detectedIssue: result['detected_issue'],
            suggestion: result['suggestion'],
            imageFile: file,
            boxes: result['boxes'],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to analyze image')),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No image selected')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('UrbanEye - Home'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, size: 100, color: Colors.blueAccent),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Take/Upload a Photo'),
            ),
          ],
        ),
      ),
    );
  }
}
