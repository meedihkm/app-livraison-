import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final ApiService _apiService = ApiService();
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  Position? _lastPosition;

  bool get isTracking => _isTracking;
  Position? get lastPosition => _lastPosition;

  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<Position?> getCurrentPosition() async {
    if (!await checkPermission()) return null;
    try {
      _lastPosition = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      );
      return _lastPosition;
    } catch (e) {
      return null;
    }
  }

  Future<void> startTracking({int intervalSeconds = 30}) async {
    if (_isTracking) return;
    if (!await checkPermission()) return;

    _isTracking = true;
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // Mise à jour tous les 50m
      ),
    ).listen((Position position) async {
      _lastPosition = position;
      await _sendLocationToServer(position);
    });
  }

  Future<void> stopTracking() async {
    _isTracking = false;
    await _positionStream?.cancel();
    _positionStream = null;
  }

  Future<void> _sendLocationToServer(Position position) async {
    try {
      await _apiService.updateDelivererLocation(position.latitude, position.longitude);
    } catch (e) {
      // Silently fail
    }
  }
}
