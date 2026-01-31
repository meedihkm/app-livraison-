import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/services/location_service.dart';
import 'delivery_route_page.dart';
import 'delivery_history_page.dart';
import 'debt_collection_page.dart';
import '../../../../core/widgets/sync_indicator.dart';

class DelivererDashboard extends StatefulWidget {
  @override
  _DelivererDashboardState createState() => _DelivererDashboardState();
}

class _DelivererDashboardState extends State<DelivererDashboard> {
  final LocationService _locationService = LocationService();
  bool _isTracking = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    super.dispose();
  }

  Future<void> _startTracking() async {
    final hasPermission = await _locationService.checkPermission();
    if (hasPermission) {
      await _locationService.startTracking();
      setState(() => _isTracking = true);
    }
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await _locationService.stopTracking();
      setState(() => _isTracking = false);
    } else {
      await _startTracking();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Awid', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),

                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Livreur', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        actions: [
          SyncIndicator(),
          // Bouton GPS
          IconButton(
            icon: Icon(_isTracking ? Icons.gps_fixed : Icons.gps_off),
            tooltip: _isTracking ? 'GPS actif' : 'GPS inactif',
            onPressed: _toggleTracking,
          ),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return PopupMenuButton<String>(
                icon: Icon(Icons.account_circle),
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'name',
                    enabled: false,
                    child: Text('${authProvider.user?['name']}'),
                  ),
                  PopupMenuItem<String>(
                    value: 'org',
                    enabled: false,
                    child: Text('${authProvider.user?['organization']['name']}'),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'gps',
                    child: Row(
                      children: [
                        Icon(_isTracking ? Icons.gps_fixed : Icons.gps_off, size: 20, color: _isTracking ? Colors.green : Colors.grey),
                        SizedBox(width: 8),
                        Text(_isTracking ? 'GPS actif' : 'Activer GPS'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20),
                        SizedBox(width: 8),
                        Text('Déconnexion'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'logout') {
                    context.read<AuthProvider>().logout();
                  } else if (value == 'gps') {
                    _toggleTracking();
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de statut GPS
          if (_isTracking)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.green.shade100,
              child: Row(
                children: [
                  Icon(Icons.gps_fixed, size: 16, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Position partagée avec l\'admin', style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
                  Spacer(),
                  GestureDetector(
                    onTap: _toggleTracking,
                    child: Text('Désactiver', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                DeliveryRoutePage(),
                DeliveryHistoryPage(),
                DebtCollectionPage(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.orange.shade600,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'À livrer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historique',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Dettes',
          ),
        ],
      ),
    );
  }
}
