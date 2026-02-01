import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/print_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/route_service.dart';
import '../../../../core/database/sync_service.dart';
import '../../../../core/models/delivery_model.dart';

class DeliveryRoutePage extends StatefulWidget {
  @override
  _DeliveryRoutePageState createState() => _DeliveryRoutePageState();
}

class _DeliveryRoutePageState extends State<DeliveryRoutePage> {
  final ApiService _apiService = ApiService();
  final PrintService _printService = PrintService();
  final LocationService _locationService = LocationService();
  final RouteService _routeService = RouteService();
  List<Delivery> _deliveries = [];
  bool _isLoading = true;
  bool _showMap = false; // Toggle state
  final MapController _mapController = MapController();
  RouteResult? _optimizedRoute;
  LatLng? _currentPosition;
  bool _isCalculatingRoute = false;

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
    _getCurrentPosition();
  }
  
  Future<void> _getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _currentPosition = LatLng(position.latitude, position.longitude));
      }
    } catch (e) {
      print('Error getting position: $e');
    }
  }
  
  Future<void> _calculateOptimizedRoute() async {
    if (_deliveries.isEmpty) return;
    
    setState(() => _isCalculatingRoute = true);
    
    try {
      // Position de départ (position actuelle ou premier client)
      final start = _currentPosition ?? LatLng(
        _deliveries.first.order.cafeteria!.latitude!,
        _deliveries.first.order.cafeteria!.longitude!,
      );
      
      // Liste des destinations (clients avec coordonnées valides)
      final destinations = _deliveries
          .where((d) => d.order.cafeteria != null && d.order.cafeteria!.hasLocation)
          .map((d) => LatLng(
                d.order.cafeteria!.latitude!,
                d.order.cafeteria!.longitude!,
              ))
          .toList();
      
      if (destinations.isEmpty) {
        throw Exception('Aucune livraison avec coordonnées GPS');
      }
      
      // Calculer l'itinéraire optimisé
      final route = await _routeService.calculateOptimizedRoute(
        start: start,
        destinations: destinations,
      );
      
      if (route != null && mounted) {
        setState(() => _optimizedRoute = route);
        
        // Centrer la carte sur l'itinéraire
        if (route.routePoints.isNotEmpty) {
          _fitBounds(route.routePoints);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Itinéraire: ${route.formattedDistance}, ${route.formattedDuration}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur calcul itinéraire: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalculatingRoute = false);
    }
  }
  
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

  Future<void> _loadDeliveries() async {
    try {
      final response = await _apiService.getDeliveryRoute();
      if (response['success'] == true) {
        setState(() {
          _deliveries = (response['data'] as List<dynamic>).map((json) => Delivery.fromJson(json as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
    }
  }

  Future<void> _callClient(String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(phoneUri)) await launchUrl(phoneUri);
      else if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'appeler')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: Colors.orange));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _showMap = !_showMap),
        icon: Icon(_showMap ? Icons.list : Icons.map),
        label: Text(_showMap ? 'Liste' : 'Carte'),
        backgroundColor: Colors.orange,
      ),
      body: _showMap ? _buildMap() : _buildList(),
    );
  }

  Widget _buildMap() {
    if (_deliveries.isEmpty) return Center(child: Text("Aucune livraison à afficher"));

    // Filter valid locations
    final validDeliveries = _deliveries.where((d) => 
      d.order.cafeteria != null && d.order.cafeteria!.hasLocation
    ).toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: validDeliveries.isNotEmpty 
              ? LatLng(validDeliveries.first.order.cafeteria!.latitude!, validDeliveries.first.order.cafeteria!.longitude!)
              : LatLng(36.75, 3.05), // Default Algiers
            initialZoom: 13.0,
            interactionOptions: InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.awid.delivery',
            ),
            // Route optimisée
            if (_optimizedRoute != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _optimizedRoute!.routePoints,
                    strokeWidth: 4,
                    color: Colors.orange,
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
            // Marqueurs des livraisons
            MarkerLayer(
              markers: validDeliveries.asMap().entries.map((entry) {
                final index = entry.key;
                final d = entry.value;
                return Marker(
                  point: LatLng(d.order.cafeteria!.latitude!, d.order.cafeteria!.longitude!),
                  width: 60,
                  height: 60,
                  child: GestureDetector(
                    onTap: () => _confirmDelivery(d),
                    child: Column(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 2),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
                          ),
                          child: Text(
                            d.order.cafeteria!.name,
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        // Boutons de contrôle
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'gps',
                onPressed: () async {
                  await _getCurrentPosition();
                  if (_currentPosition != null) {
                    _mapController.move(_currentPosition!, 15);
                  }
                },
                backgroundColor: Colors.white,
                child: Icon(Icons.my_location, color: Colors.blue),
              ),
              SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'route',
                onPressed: _isCalculatingRoute ? null : _calculateOptimizedRoute,
                backgroundColor: Colors.white,
                child: _isCalculatingRoute
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.route, color: Colors.orange),
              ),
            ],
          ),
        ),
        // Info itinéraire
        if (_optimizedRoute != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.straighten, color: Colors.orange, size: 20),
                        SizedBox(height: 4),
                        Text(_optimizedRoute!.formattedDistance,
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, color: Colors.orange, size: 20),
                        SizedBox(height: 4),
                        Text(_optimizedRoute!.formattedDuration,
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, color: Colors.orange, size: 20),
                        SizedBox(height: 4),
                        Text('${validDeliveries.length} arrêts',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildList() {
    if (_deliveries.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey[400]),
        SizedBox(height: 16),
        Text('Aucune livraison', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
        SizedBox(height: 24),
        ElevatedButton.icon(onPressed: _loadDeliveries, icon: Icon(Icons.refresh), label: Text('Actualiser'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange)),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _loadDeliveries,
      color: Colors.orange,
      child: ListView.builder(
        padding: EdgeInsets.all(12),
        itemCount: _deliveries.length,
        itemBuilder: (context, index) {
          final delivery = _deliveries[index];
          // ... (existing card build logic stays here or extracted)
          return _buildDeliveryCard(delivery, index); // Refactored for cleanliness
        },
      ),
    );
  }

  Widget _buildDeliveryCard(Delivery delivery, int index) {
     final order = delivery.order;
     return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Theme.of(context).shadowColor.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        // Header
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.orange.shade600, Colors.orange.shade400]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.local_shipping, color: Colors.white, size: 28),
            ),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Livraison #${index + 1}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                if (delivery.attempts > 0) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                    child: Text('${delivery.attempts} tentative(s)', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ],
              ]),
              if (order.cafeteria != null) Text(order.cafeteria!.name, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
            ])),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20)),
              child: Text('${order.total.toStringAsFixed(0)} DA', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ]),
        ),
        // Contenu
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Boutons appel et navigation
            Row(children: [
              // Bouton appel
              if (order.cafeteria?.phone != null && order.cafeteria!.phone!.isNotEmpty)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _callClient(order.cafeteria!.phone!),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1), 
                        borderRadius: BorderRadius.circular(12), 
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3))
                      ),
                      child: Row(children: [
                        Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.phone, size: 20, color: Colors.white)),
                        SizedBox(width: 8),
                        Expanded(child: Text('Appeler', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade700))),
                      ]),
                    ),
                  ),
                ),
              if (order.cafeteria?.phone != null && order.cafeteria!.phone!.isNotEmpty) SizedBox(width: 8),
              // Bouton navigation GPS
              Expanded(
                child: GestureDetector(
                  onTap: () => _navigateToClient(delivery),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: order.cafeteria?.hasLocation == true ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1), 
                      borderRadius: BorderRadius.circular(12), 
                      border: Border.all(color: order.cafeteria?.hasLocation == true ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: EdgeInsets.all(8), 
                        decoration: BoxDecoration(
                          color: order.cafeteria?.hasLocation == true ? Colors.green : Colors.orange, 
                          borderRadius: BorderRadius.circular(8),
                        ), 
                        child: Icon(Icons.navigation, size: 20, color: Colors.white),
                      ),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        order.cafeteria?.hasLocation == true ? 'Naviguer' : 'Ajouter GPS', 
                        style: TextStyle(fontWeight: FontWeight.w600, color: order.cafeteria?.hasLocation == true ? Colors.green.shade700 : Colors.orange.shade700),
                      )),
                    ]),
                  ),
                ),
              ),
            ]),
            SizedBox(height: 12),
            // Adresse si disponible
            if (order.cafeteria?.address != null && order.cafeteria!.address!.isNotEmpty)
              Container(
                padding: EdgeInsets.all(10),
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(Icons.location_on, size: 18, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Expanded(child: Text(order.cafeteria!.address!, style: TextStyle(color: Colors.grey[700], fontSize: 13))),
                ]),
              ),
            // Articles
            Text('Articles:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800])),
            SizedBox(height: 8),
            ...order.items.map((item) => Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Center(child: Text('${item.quantity}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700)))),
                SizedBox(width: 12),
                Expanded(child: Text(item.productName)),
                Text('${item.totalPrice.toStringAsFixed(0)} DA', style: TextStyle(color: Colors.grey[600])),
              ]),
            )),
            Divider(height: 24),
            // Montant
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [Icon(Icons.payments, color: Colors.green.shade700), SizedBox(width: 8), Text('À collecter:', style: TextStyle(fontWeight: FontWeight.w500))]),
                Text('${order.remainingAmount.toStringAsFixed(0)} DA', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
              ]),
            ),
            SizedBox(height: 16),
            // Boutons actions
            Row(children: [
              // Bouton imprimer
              SizedBox(height: 48, child: ElevatedButton(
                onPressed: () => _showPrintOptions(delivery),
                child: Icon(Icons.print, size: 24),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: EdgeInsets.symmetric(horizontal: 16)),
              )),
              SizedBox(width: 8),
              Expanded(
                child: SizedBox(height: 48, child: ElevatedButton.icon(
                  onPressed: () => _confirmDelivery(delivery),
                  icon: Icon(Icons.check_circle, size: 20),
                  label: Text('LIVRÉ', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                )),
              ),
              SizedBox(width: 8),
              SizedBox(height: 48, child: ElevatedButton(
                onPressed: () => _reportFailure(delivery),
                child: Icon(Icons.warning_amber, size: 24),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: EdgeInsets.symmetric(horizontal: 16)),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }

  // Ouvrir la navigation vers le client (OpenStreetMap)
  Future<void> _navigateToClient(Delivery delivery) async {
    final cafeteria = delivery.order.cafeteria;
    if (cafeteria == null) return;
    
    // Si pas de coordonnées, demander l'adresse
    if (!cafeteria.hasLocation) {
      final address = await _showAddressDialog(cafeteria.name, cafeteria.address);
      if (address != null && address.isNotEmpty) {
        try {
          final response = await _apiService.updateUserAddress(cafeteria.id, address);
          if (response['success'] == true && response['data'] != null) {
            final lat = (response['data'] as Map<String, dynamic>)['latitude'] as double?;
            final lng = (response['data'] as Map<String, dynamic>)['longitude'] as double?;
            if (lat != null && lng != null) {
              _openNavigation(lat, lng, cafeteria.name);
              _loadDeliveries(); // Recharger pour avoir les nouvelles coordonnées
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Adresse non trouvée sur la carte'), backgroundColor: Colors.orange));
            }
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
        }
      }
      return;
    }
    
    _openNavigation(cafeteria.latitude!, cafeteria.longitude!, cafeteria.name);
  }

  void _openNavigation(double lat, double lng, String name) async {
    // Essayer d'ouvrir avec l'app de navigation par défaut (Google Maps, OsmAnd, etc.)
    final Uri osmUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($name)');
    final Uri googleMapsUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    
    try {
      if (await canLaunchUrl(osmUri)) {
        await launchUrl(osmUri);
      } else if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: ouvrir OpenStreetMap dans le navigateur
        final Uri webUri = Uri.parse('https://www.openstreetmap.org/directions?from=&to=$lat,$lng');
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir la navigation')));
    }
  }

  Future<String?> _showAddressDialog(String clientName, String? currentAddress) async {
    final controller = TextEditingController(text: currentAddress ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.location_on, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(child: Text('Adresse de $clientName', style: TextStyle(fontSize: 16))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Entrez l\'adresse pour activer la navigation GPS', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Ex: Rue Didouche Mourad, Alger',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.words,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelivery(Delivery delivery) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => _DeliveryConfirmSheet(delivery: delivery),
    );
    if (result != null) {
      final syncService = SyncService();
      if (!syncService.isOnline) {
         final offlinePayload = {
           'deliveryId': delivery.id,
           'status': 'delivered',
           ...result,
         };
         await syncService.addOfflineAction('UPDATE_DELIVERY', offlinePayload);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hors ligne : Livraison validée'), backgroundColor: Colors.orange));
         return;
      }

      try {
        // Confirmer la livraison
        await _apiService.updateDeliveryStatus(delivery.id, {
          'status': 'delivered',
          'paymentStatus': result['paymentStatus'],
          'amountCollected': result['amountCollected'],
          'comment': result['comment'],
        });
        
        // Si le client n'a pas d'adresse enregistrée, capturer la position GPS actuelle
        final cafeteria = delivery.order.cafeteria;
        if (cafeteria != null && !cafeteria.hasLocation) {
          try {
            final position = await _locationService.getCurrentPosition();
            if (position != null) {
              await _apiService.updateUserAddress(
                cafeteria.id, 
                'Position GPS capturée',
                latitude: position.latitude,
                longitude: position.longitude,
              );
            }
          } catch (e) {
            print('GPS capture failed: $e');
          }
        }
        
        _loadDeliveries();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Livraison confirmée!'), backgroundColor: Colors.green));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  Future<void> _reportFailure(Delivery delivery) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => _FailureReportSheet(delivery: delivery),
    );
    if (result != null) {
      try {
        await _apiService.updateDeliveryStatus(delivery.id, result);
        _loadDeliveries();
        final msg = result['status'] == 'failed' ? 'Échec signalé' : 'Livraison reportée';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  void _showPrintOptions(Delivery delivery) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Imprimer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.description, color: Colors.blue),
              ),
              title: Text('Bon de livraison A5'),
              subtitle: Text('Format standard'),
              onTap: () {
                Navigator.pop(context);
                _printService.printDeliverySlip(delivery);
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.receipt_long, color: Colors.orange),
              ),
              title: Text('Ticket thermique'),
              subtitle: Text('Format 80mm'),
              onTap: () {
                Navigator.pop(context);
                _printService.printThermalReceipt(delivery);
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.receipt, color: Colors.green),
              ),
              title: Text('Facture client'),
              subtitle: Text('PDF avec TVA'),
              onTap: () {
                Navigator.pop(context);
                _printService.printInvoice(delivery);
              },
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }


}


// Sheet de confirmation de livraison
class _DeliveryConfirmSheet extends StatefulWidget {
  final Delivery delivery;
  const _DeliveryConfirmSheet({required this.delivery});

  @override
  State<_DeliveryConfirmSheet> createState() => _DeliveryConfirmSheetState();
}

class _DeliveryConfirmSheetState extends State<_DeliveryConfirmSheet> {
  String _paymentStatus = 'paid';
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.delivery.order.remainingAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + bottomPadding),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.check_circle, color: Colors.green, size: 28),
              ),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Confirmer la livraison', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(widget.delivery.order.cafeteria?.name ?? '', style: TextStyle(color: Colors.grey[600])),
              ])),
              IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            SizedBox(height: 20),
            
            // Statut paiement
            Text('Statut du paiement', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Row(children: [
              Expanded(child: _PaymentOption(
                label: 'Payé', icon: Icons.check_circle, color: Colors.green,
                selected: _paymentStatus == 'paid',
                onTap: () => setState(() => _paymentStatus = 'paid'),
              )),
              SizedBox(width: 12),
              Expanded(child: _PaymentOption(
                label: 'Partiel', icon: Icons.pie_chart, color: Colors.orange,
                selected: _paymentStatus == 'partial',
                onTap: () => setState(() => _paymentStatus = 'partial'),
              )),
              SizedBox(width: 12),
              Expanded(child: _PaymentOption(
                label: 'Crédit', icon: Icons.schedule, color: Colors.red,
                selected: _paymentStatus == 'unpaid',
                onTap: () => setState(() => _paymentStatus = 'unpaid'),
              )),
            ]),
            SizedBox(height: 16),
            
            // Montant collecté
            Text('Montant collecté (DA)', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '0',
                prefixIcon: Icon(Icons.payments, color: Colors.green),
                suffixText: 'DA',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.green, width: 2)),
              ),
            ),
            SizedBox(height: 16),
            
            // Commentaire
            Text('Commentaire (optionnel)', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ajouter une note...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 20),
            
            // Bouton confirmer
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context, {
                    'paymentStatus': _paymentStatus,
                    'amountCollected': double.tryParse(_amountController.text) ?? 0,
                    'comment': _commentController.text.isEmpty ? null : _commentController.text,
                  });
                },
                icon: Icon(Icons.check),
                label: Text('CONFIRMER LA LIVRAISON', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({required this.label, required this.icon, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.transparent, width: 2),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? color : Colors.grey, size: 24),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? color : Colors.grey)),
        ]),
      ),
    );
  }
}

// Sheet de rapport d'échec/report
class _FailureReportSheet extends StatefulWidget {
  final Delivery delivery;
  const _FailureReportSheet({required this.delivery});

  @override
  State<_FailureReportSheet> createState() => _FailureReportSheetState();
}

class _FailureReportSheetState extends State<_FailureReportSheet> {
  String _action = 'failed'; // 'failed' ou 'postponed'
  String _failureReason = 'closed';
  DateTime? _postponedDate;
  final _commentController = TextEditingController();

  final List<Map<String, dynamic>> _reasons = [
    {'value': 'closed', 'label': 'Client fermé', 'icon': Icons.store_outlined},
    {'value': 'absent', 'label': 'Client absent', 'icon': Icons.person_off},
    {'value': 'address_not_found', 'label': 'Adresse introuvable', 'icon': Icons.location_off},
    {'value': 'refused', 'label': 'Commande refusée', 'icon': Icons.cancel_outlined},
    {'value': 'other', 'label': 'Autre raison', 'icon': Icons.help_outline},
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 30)),
      builder: (context, child) => Theme(data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: Colors.orange)), child: child!),
    );
    if (date != null) setState(() => _postponedDate = date);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + bottomPadding),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.warning_amber, color: Colors.red, size: 28),
              ),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Signaler un problème', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(widget.delivery.order.cafeteria?.name ?? '', style: TextStyle(color: Colors.grey[600])),
              ])),
              IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
            SizedBox(height: 20),
            
            // Type d'action
            Text('Action', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Row(children: [
              Expanded(child: _ActionOption(
                label: 'Échec', icon: Icons.cancel, color: Colors.red,
                selected: _action == 'failed',
                onTap: () => setState(() => _action = 'failed'),
              )),
              SizedBox(width: 12),
              Expanded(child: _ActionOption(
                label: 'Reporter', icon: Icons.schedule, color: Colors.orange,
                selected: _action == 'postponed',
                onTap: () => setState(() => _action = 'postponed'),
              )),
            ]),
            SizedBox(height: 16),
            
            // Raison
            Text('Raison', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reasons.map((r) => GestureDetector(
                onTap: () => setState(() => _failureReason = r['value'] as String),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _failureReason == r['value'] as String ? Colors.red.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _failureReason == r['value'] as String ? Colors.red : Colors.transparent),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(r['icon'] as IconData?, size: 18, color: _failureReason == r['value'] as String ? Colors.red : Colors.grey),
                    SizedBox(width: 6),
                    Text(r['label'] as String, style: TextStyle(fontSize: 13, color: _failureReason == r['value'] as String ? Colors.red : Colors.grey[700])),
                  ]),
                ),
              )).toList(),
            ),
            
            // Date de report (si action = postponed)
            if (_action == 'postponed') ...[
              SizedBox(height: 16),
              Text('Reporter à', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today, color: Colors.orange),
                    SizedBox(width: 12),
                    Text(
                      _postponedDate != null 
                        ? '${_postponedDate!.day}/${_postponedDate!.month}/${_postponedDate!.year}'
                        : 'Sélectionner une date',
                      style: TextStyle(fontSize: 16, color: _postponedDate != null ? Colors.black : Colors.grey),
                    ),
                  ]),
                ),
              ),
            ],
            SizedBox(height: 16),
            
            // Commentaire
            Text('Commentaire', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Détails supplémentaires...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 20),
            
            // Bouton envoyer
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_action == 'postponed' && _postponedDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Veuillez sélectionner une date'), backgroundColor: Colors.orange));
                    return;
                  }
                  // Format date as YYYY-MM-DD for API
                  String? postponedDateStr;
                  if (_postponedDate != null) {
                    postponedDateStr = '${_postponedDate!.year}-${_postponedDate!.month.toString().padLeft(2, '0')}-${_postponedDate!.day.toString().padLeft(2, '0')}';
                  }
                  Navigator.pop(context, {
                    'status': _action,
                    'failureReason': _failureReason,
                    'postponedTo': postponedDateStr,
                    'comment': _commentController.text.isEmpty ? null : _commentController.text,
                  });
                },
                icon: Icon(_action == 'failed' ? Icons.report : Icons.schedule),
                label: Text(_action == 'failed' ? 'SIGNALER L\'ÉCHEC' : 'REPORTER LA LIVRAISON', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _action == 'failed' ? Colors.red : Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ActionOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ActionOption({required this.label, required this.icon, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.transparent, width: 2),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? color : Colors.grey, size: 28),
          SizedBox(height: 6),
          Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? color : Colors.grey)),
        ]),
      ),
    );
  }
}
