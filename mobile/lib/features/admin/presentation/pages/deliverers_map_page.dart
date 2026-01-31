import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/route_service.dart';
import '../../../../features/auth/providers/auth_provider.dart';

class DeliverersMapPage extends StatefulWidget {
  @override
  _DeliverersMapPageState createState() => _DeliverersMapPageState();
}

class _DeliverersMapPageState extends State<DeliverersMapPage> {
  final ApiService _apiService = ApiService();
  final RouteService _routeService = RouteService();
  final MapController _mapController = MapController();
  
  // Data
  List<Map<String, dynamic>> _deliverers = [];
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _routePoints = []; // For deliverers
  RouteResult? _optimizedRoute;
  
  // State
  bool _isLoading = true;
  bool _isCalculatingRoute = false;
  Timer? _refreshTimer;
  bool _showClients = true;
  bool _showDeliverers = true;
  bool _showRoute = false;
  String? _userRole;
  bool _isSatellite = false;
  LatLng? _currentPosition;

  // Defaults
  final LatLng _defaultCenter = LatLng(36.7538, 3.0588); // Algiers

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _userRole = authProvider.user?['role'];
    
    // Initial configuration based on role
    if (_userRole == 'deliverer') {
      _showClients = false; // Deliverer sees route points, not generic clients
      _showDeliverers = false; // Deliverer usually sees their own route
    }

    _loadData();
    // Refresh every 30s
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (_) => _refreshData());
    _locateUser(); // Trigger location
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    await _loadData(isRefresh: true);
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    if (!isRefresh) setState(() => _isLoading = true);

    try {
      if (_userRole == 'admin' || _userRole == 'super_admin') {
        await Future.wait([
          if (_showDeliverers) _loadDeliverers(),
          if (_showClients) _loadClients(),
        ]);
      } else if (_userRole == 'deliverer') {
        await _loadRoute();
      }
    } catch (e) {
      debugPrint('Error loading map data: $e');
    } finally {
      if (mounted && !isRefresh) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDeliverers() async {
    final response = await _apiService.getDeliverersLocations();
    if (response['success'] == true && mounted) {
      setState(() {
        _deliverers = List<Map<String, dynamic>>.from(response['data']);
      });
    }
  }

  Future<void> _loadClients() async {
    final response = await _apiService.getClientsLocations();
    if (response['success'] == true && mounted) {
      setState(() {
        _clients = List<Map<String, dynamic>>.from(response['data']);
      });
    }
  }

  Future<void> _loadRoute() async {
    // For deliverers, load their assigned route
    final response = await _apiService.getDeliveryRoute();
    if (response['success'] == true && mounted) {
      final deliveries = List<Map<String, dynamic>>.from(response['data']);
      
      List<Map<String, dynamic>> points = [];
      for (var d in deliveries) {
        final order = d['order'];
        if (order != null && order['customer'] != null) {
          final cafeteria = order['customer'];
          final lat = double.tryParse(cafeteria['latitude']?.toString() ?? '0') ?? 0;
          final lng = double.tryParse(cafeteria['longitude']?.toString() ?? '0') ?? 0;
          
          if (lat != 0 && lng != 0) {
            points.add({
              ...cafeteria, // name, phone, etc.
              'latitude': lat,
              'longitude': lng,
              'delivery_id': d['id'],
              'status': d['status'],
              'order_total': order['total'],
            });
          }
        }
      }
      setState(() {
        _routePoints = points;
        // Also update _clients list for the map markers logic if we are in Deliverer mode
        // For Deliverer mode, markers logic uses _clients if !isAdmin.
        _clients = points; 
      });    }
  }

  Future<void> _locateUser() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() => _currentPosition = LatLng(position.latitude, position.longitude));
      _mapController.move(LatLng(position.latitude, position.longitude), 15);
    }
  }
  
  /// Calcule l'itinéraire optimisé pour visiter tous les clients
  Future<void> _calculateOptimizedRoute() async {
    if (_clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucun client à visiter'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    setState(() => _isCalculatingRoute = true);
    
    try {
      // Position de départ (position actuelle ou premier client)
      final start = _currentPosition ?? LatLng(
        double.parse(_clients.first['latitude'].toString()),
        double.parse(_clients.first['longitude'].toString()),
      );
      
      // Liste des destinations (clients avec coordonnées valides)
      final destinations = _clients
          .where((c) {
            final lat = double.tryParse(c['latitude']?.toString() ?? '0') ?? 0;
            final lng = double.tryParse(c['longitude']?.toString() ?? '0') ?? 0;
            return lat != 0 && lng != 0;
          })
          .map((c) => LatLng(
                double.parse(c['latitude'].toString()),
                double.parse(c['longitude'].toString()),
              ))
          .toList();
      
      if (destinations.isEmpty) {
        throw Exception('Aucun client avec coordonnées GPS valides');
      }
      
      // Calculer l'itinéraire optimisé
      final route = await _routeService.calculateOptimizedRoute(
        start: start,
        destinations: destinations,
      );
      
      if (route != null && mounted) {
        setState(() {
          _optimizedRoute = route;
          _showRoute = true;
        });
        
        // Centrer la carte sur l'itinéraire
        if (route.routePoints.isNotEmpty) {
          _fitBounds(route.routePoints);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Itinéraire optimisé: ${route.formattedDistance}, ${route.formattedDuration}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Impossible de calculer l\'itinéraire');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalculatingRoute = false);
    }
  }
  
  /// Ajuste la vue de la carte pour afficher tous les points
  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    
    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapController.move(center, 12);
  }

  // --- Helpers ---

  String _getTimeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}j';
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final uri = Uri.parse('google.navigation:q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
      if (await canLaunchUrl(webUri)) await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = _userRole == 'admin' || _userRole == 'super_admin';

    // Collect markers
    List<Marker> markers = [];

    // 1. Deliverers Markers (Admin only)
    if (_showDeliverers && isAdmin) {
      markers.addAll(_deliverers.map((d) {
        final lat = double.tryParse(d['latitude']?.toString() ?? '0') ?? 0;
        final lng = double.tryParse(d['longitude']?.toString() ?? '0') ?? 0;
        if (lat == 0 && lng == 0) return null;

        return Marker(
          point: LatLng(lat, lng),
          width: 80,
          height: 80,
          child: GestureDetector(
            onTap: () => _showDelivererInfo(d),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                  child: Text(d['name'] ?? 'Livreur', style: TextStyle(color: Colors.white, fontSize: 10), overflow: TextOverflow.ellipsis),
                ),
                Icon(Icons.local_shipping, color: Colors.orange, size: 30),
              ],
            ),
          ),
        );
      }).whereType<Marker>());
    }

    // 2. Clients Markers
    if (_showClients || !isAdmin) { 
      // If deliverer, we might want to show assigned clients effectively using _routePoints logic later
      // For now using _clients list which Admin loads.
      // If Deliverer, we need to load relevant clients.
      
      markers.addAll(_clients.map((c) {
        final lat = double.tryParse(c['latitude']?.toString() ?? '0') ?? 0;
        final lng = double.tryParse(c['longitude']?.toString() ?? '0') ?? 0;
        if (lat == 0 && lng == 0) return null;

        return Marker(
          point: LatLng(lat, lng),
          width: 80,
          height: 80,
          child: GestureDetector(
            onTap: () => _showClientInfo(c),
            child: Column(
              children: [
                if (!isAdmin) // Deliverer might need names always visible? Or small dot?
                 Container(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                    child: Text(c['name'] ?? 'Client', style: TextStyle(color: Colors.white, fontSize: 10), overflow: TextOverflow.ellipsis),
                  ),
                Icon(Icons.store, color: Colors.green, size: 30),
              ],
            ),
          ),
        );
      }).whereType<Marker>());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Carte Globale' : 'Mon Itinéraire'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: () => _refreshData()),
        ],
      ),
      body: Stack(
        children: [
          // MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 12,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatellite
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.awid.delivery',
              ),
              // Route optimisée
              if (_showRoute && _optimizedRoute != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _optimizedRoute!.routePoints,
                      strokeWidth: 4,
                      color: Colors.blue,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    ),
                  ],
                ),
              // Position actuelle
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(Icons.navigation, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              MarkerLayer(markers: markers),
            ],
          ),

          // LOADING OVERLAY
          if (_isLoading)
            Positioned(
              top: 0, left: 0, right: 0,
              child: LinearProgressIndicator(color: theme.primaryColor),
            ),

          // CONTROLS LAYER (Satellite & Location)
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'layer',
                  onPressed: () => setState(() => _isSatellite = !_isSatellite),
                  backgroundColor: Colors.white,
                  child: Icon(_isSatellite ? Icons.map : Icons.satellite_alt, color: Colors.blue),
                  tooltip: _isSatellite ? 'Mode Plan' : 'Mode Satellite',
                ),
                SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'gps',
                  onPressed: _locateUser,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.my_location, color: Colors.blue),
                  tooltip: 'Ma position',
                ),
              ],
            ),
          ),

          // ADMIN CONTROLS (Bottom Sheet inside Stack or Floating Card)
          if (isAdmin)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Filtres
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildFilterChip('Clients', _showClients, Colors.green, (v) {
                            setState(() => _showClients = v);
                            if(v && _clients.isEmpty) _loadClients();
                          }),
                          _buildFilterChip('Livreurs', _showDeliverers, Colors.orange, (v) {
                            setState(() => _showDeliverers = v);
                            if(v && _deliverers.isEmpty) _loadDeliverers();
                          }),
                          if (_optimizedRoute != null)
                            _buildFilterChip('Route', _showRoute, Colors.blue, (v) {
                              setState(() => _showRoute = v);
                            }),
                        ],
                      ),
                      // Bouton calcul itinéraire
                      if (_clients.isNotEmpty) ...[
                        SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isCalculatingRoute ? null : _calculateOptimizedRoute,
                            icon: _isCalculatingRoute
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Icon(Icons.route),
                            label: Text(_isCalculatingRoute ? 'Calcul...' : 'Calculer itinéraire optimisé'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                      // Info itinéraire
                      if (_optimizedRoute != null) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Icon(Icons.straighten, color: Colors.blue, size: 20),
                                  SizedBox(height: 4),
                                  Text(_optimizedRoute!.formattedDistance,
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                ],
                              ),
                              Column(
                                children: [
                                  Icon(Icons.access_time, color: Colors.blue, size: 20),
                                  SizedBox(height: 4),
                                  Text(_optimizedRoute!.formattedDuration,
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                ],
                              ),
                              Column(
                                children: [
                                  Icon(Icons.location_on, color: Colors.blue, size: 20),
                                  SizedBox(height: 4),
                                  Text('${_clients.length} arrêts',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            
           // DELIVERER CONTROLS (Navigation Button)
           if (!isAdmin && _routePoints.isNotEmpty) 
             Positioned(
               bottom: 20, right: 20,
               child: FloatingActionButton.extended(
                 onPressed: () {
                    // Start navigation to first point
                 },
                 label: Text('Démarrer'),
                 icon: Icon(Icons.navigation),
               ),
             ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool value, Color color, Function(bool) onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      selectedColor: color.withValues(alpha: 0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(color: value ? color : Colors.grey, fontWeight: FontWeight.bold),
    );
  }

  void _showDelivererInfo(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(data['name'] ?? 'Livreur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Dernière MAJ: ${_getTimeAgo(data['location_updated_at'])}', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(Icons.phone),
              label: Text('Appeler'),
              onPressed: () => launchUrl(Uri.parse('tel:${data['phone']}')),
            ),
          ],
        ),
      ),
    );
  }

  void _showClientInfo(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(data['name'] ?? 'Client', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (data['address'] != null) Text(data['address'], style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            SizedBox(height: 12),
            if ((data['active_orders_count'] ?? 0) > 0)
              Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text('${data['active_orders_count']} commande(s) en cours', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                    SizedBox(width: 8),
                    Text('•', style: TextStyle(color: Colors.grey)),
                    SizedBox(width: 8),
                    Text('${data['active_orders_total']} DA', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.phone),
                  label: Text('Appeler'),
                  onPressed: () => launchUrl(Uri.parse('tel:${data['phone']}')),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.directions),
                  label: Text('Naviguer'),
                  onPressed: () {
                    final lat = double.tryParse(data['latitude']?.toString() ?? '0') ?? 0;
                    final lng = double.tryParse(data['longitude']?.toString() ?? '0') ?? 0;
                    if (lat != 0 && lng != 0) _launchMaps(lat, lng);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
