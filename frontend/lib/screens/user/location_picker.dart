import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final MapController _mapController = MapController();

  LatLng? selectedLocation;
  String selectedAddress = 'Fetching address...';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  /// 🔐 Permission + Location
  Future<void> _getCurrentLocation() async {
    try {
      // Check GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Please enable GPS');
        return;
      }

      // Permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _showSettingsDialog();
        return;
      }

      // Get position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final latLng = LatLng(position.latitude, position.longitude);

      setState(() => selectedLocation = latLng);
      _mapController.move(latLng, 16);

      await _reverseGeocode(latLng);
    } catch (e) {
      _showSnack('Location error: $e');
    }
  }

  /// 🌍 Reverse Geocode (OSM Nominatim)
  Future<void> _reverseGeocode(LatLng point) async {
    final url =
        'https://nominatim.openstreetmap.org/reverse?format=json'
        '&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1';

    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'QurbaniApp/1.0'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        selectedAddress = data['display_name'] ?? 'Address not found';
      });
    } else {
      setState(() => selectedAddress = 'Unable to fetch address');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Please enable location permission from settings to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Geolocator.openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _confirmLocation() {
    if (selectedLocation == null) return;

    Navigator.pop(context, {
      'latitude': selectedLocation!.latitude,
      'longitude': selectedLocation!.longitude,
      'address': selectedAddress,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Delivery Location'),
        backgroundColor: Color(0xff537D4F),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: selectedLocation ?? const LatLng(20.5937, 78.9629),
              initialZoom: 5,
              onTap: (_, point) async {
                setState(() => selectedLocation = point);
                await _reverseGeocode(point);
              },
            ),

            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.qurbani.app',
              ),
              if (selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selectedLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          /// 📍 Address Card
          Positioned(
            bottom: 90,
            left: 12,
            right: 12,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  selectedAddress,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

          /// 🔘 Buttons
          Positioned(
            bottom: 20,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.my_location),
                    label: const Text('Current Location'),
                    onPressed: _getCurrentLocation,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedLocation == null
                        ? null
                        : _confirmLocation,
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
