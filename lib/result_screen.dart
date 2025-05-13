import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResultScreen extends StatefulWidget {
  final File imageFile;
  final String detectedIssue;
  final String suggestion;
  final List<dynamic> boxes;
  
  const ResultScreen({
    Key? key,
    required this.imageFile,
    required this.detectedIssue,
    required this.suggestion,
    required this.boxes,
  }) : super(key: key);

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Size? _originalImageSize;
  final Set<String> _selectedCategories = {};
  bool _useCurrentLocation = false;
  String _locationText = '';
  String _otherText = '';
  LatLng? _selectedLatLng;
  final MapController _mapController = MapController();
  final TextEditingController _detailsCtrl = TextEditingController();

  final List<_Category> _categories = [
    _Category('Pothole', Icons.warning),
    _Category('Overgrown Grass', Icons.grass),
    _Category('Graffiti', Icons.brush),
    _Category('Faded Road Lines', Icons.linear_scale),
    _Category('Trash', Icons.delete),
    _Category('Trashcan Overflow', Icons.delete_sweep),
    _Category('Other', Icons.help_outline),
  ];

  @override
  void initState() {
    super.initState();
    _getImageSize();
    _autoSelect();
  }

  void _getImageSize() {
    final img = Image.file(widget.imageFile);
    img.image
        .resolve(const ImageConfiguration())
        .addListener(ImageStreamListener((info, _) {
      setState(() {
        _originalImageSize = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
      });
    }));
  }

  String _normalize(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();

  void _autoSelect() {
    final detectedList = widget.detectedIssue.split(',').map((s) => s.trim());
    for (final p in detectedList) {
      if (p.isEmpty) continue;
      final idx = _categories.indexWhere(
          (c) => _normalize(c.name) == _normalize(p));
      if (idx != -1 && _categories[idx].name != 'Other') {
        _selectedCategories.add(_categories[idx].name);
      } else {
        _selectedCategories.add('Other');
        _otherText = p;
      }
    }
  }

  Future<void> _toggleLocation(bool on) async {
    if (!on) {
      setState(() {
        _useCurrentLocation = false;
        // keep last marker or clear:
        // _selectedLatLng = null;
        // _locationText = '';
      });
      return;
    }

    // 1) permissions
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Location permissions are permanently denied. Enable them in settings.'
        )),
      );
      return;
    }

    // 2) fetch position
    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    final latlng = LatLng(pos.latitude, pos.longitude);

    // 3) update state & move map
    setState(() {
      _useCurrentLocation = true;
      _selectedLatLng = latlng;
      _locationText = 'Lat: ${latlng.latitude}, Lon: ${latlng.longitude}';
      _mapController.move(latlng, 15);
    });
  }

  Future<void> _submitReport() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson == null) return;
    final user = json.decode(userJson);

    final issues = _selectedCategories.map((cat) {
      if (cat == 'Other' && _otherText.isNotEmpty) return _otherText;
      return cat;
    }).toList();

    final uri = Uri.parse('http://192.168.1.103:5000/submit_report');
    final req = http.MultipartRequest('POST', uri)
      ..fields['user_id'] = user['id'].toString()
      ..fields['issues'] = json.encode(issues)
      ..fields['details'] = _detailsCtrl.text
      ..fields['location'] = _locationText
      ..fields['latitude'] = _selectedLatLng?.latitude.toString() ?? ''
      ..fields['longitude'] = _selectedLatLng?.longitude.toString() ?? '';

    req.files.add(
      await http.MultipartFile.fromPath(
        'image',
        widget.imageFile.path,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    await req.send();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ThankYouScreen()),
    );
  }

  void _onSubmitPressed() {
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one issue')),
      );
      return;
    }
    if (_selectedLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please tap the map to pick a location')),
      );
      return;
    }
    _submitReport();
  }

  @override
  Widget build(BuildContext context) {
    final uniqueIssues = widget.detectedIssue
        .split(',').map((s) => s.trim()).toSet().join(', ');
    final mapCenter = _selectedLatLng ?? LatLng(46.7712, 23.6236);

    return Scaffold(
      appBar: AppBar(title: const Text('Review & Submit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image + bounding boxes
          if (_originalImageSize != null)
            LayoutBuilder(builder: (_, bc) {
              final maxW = bc.maxWidth;
              final scale = maxW / _originalImageSize!.width;
              return SizedBox(
                width: maxW,
                height: _originalImageSize!.height * scale,
                child: Stack(children: [
                  Image.file(widget.imageFile,
                      width: maxW, fit: BoxFit.fill),
                  ...widget.boxes.map((b) {
                    final x = (b['x'] as num?)?.toDouble() ?? 0;
                    final y = (b['y'] as num?)?.toDouble() ?? 0;
                    final w = (b['w'] as num?)?.toDouble() ?? 0;
                    final h = (b['h'] as num?)?.toDouble() ?? 0;
                    return Positioned(
                      left: x * scale,
                      top: y * scale,
                      width: w * scale,
                      height: h * scale,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                      ),
                    );
                  }),
                ]),
              );
            }),
          const SizedBox(height: 16),

          // Detected & suggestion
          Text('Detected: $uniqueIssues',
              style: const TextStyle(fontSize: 18)),
          if (widget.suggestion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Suggestion: ${widget.suggestion}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey)),
            ),
          const SizedBox(height: 16),

          // Category grid
          const Text('Select one or more issues:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.1,
            children: _categories.map((cat) {
              final selected = _selectedCategories.contains(cat.name);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _selectedCategories.remove(cat.name);
                    if (cat.name == 'Other') _otherText = '';
                  } else {
                    _selectedCategories.add(cat.name);
                  }
                }),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        selected ? Colors.blue.shade100 : Colors.grey.shade100,
                    border: Border.all(
                        color:
                            selected ? Colors.blue : Colors.grey.shade300,
                        width: selected ? 2 : 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(cat.icon,
                          size: 28,
                          color: selected ? Colors.blue : Colors.grey[700]),
                      const SizedBox(height: 4),
                      Text(cat.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color:
                                  selected ? Colors.blue : Colors.black)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedCategories.contains('Other')) ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _otherText,
              decoration: const InputDecoration(
                labelText: 'Please specify other issue',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _otherText = v,
            ),
          ],
          const SizedBox(height: 16),

          // Details field
          TextFormField(
            controller: _detailsCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Additional details',
              border: OutlineInputBorder(),
            ),
          ),

          const Divider(height: 32),

          // Use current location switch
          SwitchListTile(
            title: const Text('Use Current Location'),
            value: _useCurrentLocation,
            onChanged: _toggleLocation,
          ),
          if (_locationText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_locationText,
                  style: const TextStyle(color: Colors.grey)),
            ),

          // Interactive map
          const SizedBox(height: 8),
          SizedBox(
            height: 250,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: mapCenter,
                zoom: _useCurrentLocation ? 15 : 13,
                onTap: _useCurrentLocation
                    ? null
                    : (_, latlng) {
                        setState(() {
                          _selectedLatLng = latlng;
                          _locationText =
                              'Lat: ${latlng.latitude}, Lon: ${latlng.longitude}';
                        });
                      },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                if (_selectedLatLng != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLatLng!,
                        width: 40,
                        height: 40,
                        builder: (_) => const Icon(Icons.location_on,
                            size: 40, color: Colors.red),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onSubmitPressed,
              child: const Text('Submit Report'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Category {
  final String name;
  final IconData icon;
  _Category(this.name, this.icon);
}

class ThankYouScreen extends StatelessWidget {
  const ThankYouScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thank You')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 100, color: Colors.green),
            const SizedBox(height: 24),
            Text(
              'Thank you for your report!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
