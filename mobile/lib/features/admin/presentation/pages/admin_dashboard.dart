// Admin Dashboard - Main navigation
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/services/financial_service.dart';
import '../../../auth/providers/auth_provider.dart';
import 'deliverers_map_page.dart';
import 'deliveries_page.dart';
import 'financial_page.dart';
import '../../../finance/presentation/pages/finance_dashboard_page.dart';
import '../../../finance/presentation/pages/statistics_page.dart';
import 'orders_page.dart';
import 'products_page.dart';
import 'settings_page.dart';
import 'users_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _DashboardHomePage(onNavigate: (index) => setState(() => _currentIndex = index)),
      OrdersPage(),
      ProductsPage(),
      UsersPage(),
      DeliveriesPage(),
      FinanceDashboardPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Awid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            SizedBox(width: 8),
            if (_currentIndex == 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Admin', style: TextStyle(fontSize: 11)),
              )
            else
              Text('• ${_getTitle()}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.map),
            tooltip: 'Carte des livreurs',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeliverersMapPage())),
          ),
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: 'Paramètres',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage())),
          ),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return PopupMenuButton<String>(
                icon: Icon(Icons.account_circle),
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'name', enabled: false, child: Text('${authProvider.user?['name']}')),
                  PopupMenuItem<String>(
                      value: 'org', enabled: false, child: Text('${authProvider.user?['organization']['name']}')),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                      value: 'logout',
                      child:
                          Row(children: const [Icon(Icons.logout, size: 20), SizedBox(width: 8), Text('Déconnexion')])),
                ],
                onSelected: (value) {
                  if (value == 'logout') authProvider.logout();
                },
              );
            },
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Color(0xFF2E7D32),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Commandes'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Produits'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Utilisateurs'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Livraisons'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Finances'),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 1:
        return 'Commandes';
      case 2:
        return 'Produits';
      case 3:
        return 'Utilisateurs';
      case 4:
        return 'Livraisons';
      case 5:
        return 'Finances';
      default:
        return 'Admin';
    }
  }
}

class _DashboardHomePage extends StatefulWidget {
  const _DashboardHomePage({required this.onNavigate});
  final Function(int) onNavigate;

  @override
  _DashboardHomePageState createState() => _DashboardHomePageState();
}

class _DashboardHomePageState extends State<_DashboardHomePage> {
  final ApiService _apiService = ApiService();
  final FinancialService _financialService = FinancialService();
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _allOrders = [];
  List<dynamic> _debts = [];

  // Stats calculées
  Map<String, dynamic> _todayStats = {};
  Map<String, dynamic> _weekStats = {};
  Map<String, dynamic> _monthStats = {};
  List<Map<String, dynamic>> _weeklyData = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final ordersRes = await _apiService.getOrders();
      final debtsRes = await _financialService.getDebts();

      if (mounted) {
        _allOrders = ordersRes['data'] ?? [];
        _debts = debtsRes['data'] ?? [];
        _calculateStats();
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _calculateStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month);

    // Stats aujourd'hui
    final todayOrders = _filterOrdersByDate(_allOrders, today, today);
    _todayStats = _computeStats(todayOrders);

    // Stats semaine
    final weekOrders = _filterOrdersByDate(_allOrders, weekStart, today);
    _weekStats = _computeStats(weekOrders);

    // Stats mois
    final monthOrders = _filterOrdersByDate(_allOrders, monthStart, today);
    _monthStats = _computeStats(monthOrders);

    // Données pour graphique (7 derniers jours)
    _weeklyData = [];
    for (var i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final dayOrders = _filterOrdersByDate(_allOrders, day, day);
      final stats = _computeStats(dayOrders);
      _weeklyData.add({
        'day': _getDayName(day.weekday),
        'ca': stats['totalCA'],
        'orders': stats['orderCount'],
      });
    }
  }

  List<dynamic> _filterOrdersByDate(List<dynamic> orders, DateTime start, DateTime end) {
    return orders.where((o) {
      final date = DateTime.tryParse(o['createdAt'] ?? '');
      if (date == null) return false;
      final orderDay = DateTime(date.year, date.month, date.day);
      return !orderDay.isBefore(start) && !orderDay.isAfter(end);
    }).toList();
  }

  Map<String, dynamic> _computeStats(List<dynamic> orders) {
    double totalCA = 0;
    double collected = 0;
    var pending = 0, delivered = 0;

    for (final o in orders) {
      totalCA += _parseDouble(o['total']);
      collected += _parseDouble(o['amountPaid']);
      if (o['status'] == 'pending') pending++;
      if (o['status'] == 'delivered') delivered++;
    }

    return {
      'totalCA': totalCA,
      'collected': collected,
      'unpaid': totalCA - collected,
      'orderCount': orders.length,
      'pending': pending,
      'delivered': delivered,
    };
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  String _getDayName(int weekday) {
    const days = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[weekday];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.blue));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red),
            SizedBox(height: 16),
            Text('Erreur de chargement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadDashboardData();
              },
              icon: Icon(Icons.refresh),
              label: Text('Réessayer'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            )
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats temps réel - Aujourd'hui
            _buildSectionTitle('Aujourd\'hui', Icons.today, Colors.blue),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _buildStatCard(
                        'CA', '${_todayStats['totalCA']?.toStringAsFixed(0) ?? 0} DA', Icons.trending_up, Colors.blue)),
                SizedBox(width: 10),
                Expanded(
                    child: _buildStatCard(
                        'Commandes', '${_todayStats['orderCount'] ?? 0}', Icons.shopping_bag, Colors.purple)),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _buildStatCard(
                        'En attente', '${_todayStats['pending'] ?? 0}', Icons.hourglass_empty, Colors.orange)),
                SizedBox(width: 10),
                Expanded(
                    child: _buildStatCard(
                        'Livrées', '${_todayStats['delivered'] ?? 0}', Icons.check_circle, Colors.green)),
              ],
            ),

            SizedBox(height: 24),

            // Graphique CA 7 jours
            _buildSectionTitle('Évolution CA (7 jours)', Icons.show_chart, Colors.purple),
            SizedBox(height: 12),
            _buildWeeklyChart(),

            SizedBox(height: 24),

            // Comparaison périodes
            _buildSectionTitle('Comparaison', Icons.compare_arrows, Colors.teal),
            SizedBox(height: 12),
            _buildComparisonCards(),

            SizedBox(height: 24),

            // Commandes en attente
            _buildSectionTitle('Actions requises', Icons.warning_amber, Colors.orange),
            SizedBox(height: 12),
            _buildPendingOrdersPreview(),

            SizedBox(height: 24),

            // Dettes
            if (_debts.isNotEmpty) ...[
              _buildSectionTitle('Dettes clients', Icons.account_balance_wallet, Colors.red),
              SizedBox(height: 12),
              _buildDebtsPreview(),
            ],

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 24),
          SizedBox(height: 8),
          Text(value, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    if (_weeklyData.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
        child: Center(child: Text('Aucune donnée', style: TextStyle(color: Colors.grey))),
      );
    }

    final maxCA = _weeklyData.map((d) => d['ca'] as double).reduce((a, b) => a > b ? a : b);
    final maxY = maxCA > 0 ? maxCA * 1.2 : 1000.0;

    return Container(
      height: 220,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                    '${rod.toY.toStringAsFixed(0)} DA', TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < _weeklyData.length) {
                    return Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(_weeklyData[index]['day'], style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                    );
                  }
                  return Text('');
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles()),
            topTitles: AxisTitles(sideTitles: SideTitles()),
            rightTitles: AxisTitles(sideTitles: SideTitles()),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: false),
          barGroups: _weeklyData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final isToday = index == _weeklyData.length - 1;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: data['ca'],
                  color: isToday ? Colors.blue : Colors.blue.withValues(alpha: 0.5),
                  width: 28,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildComparisonCards() {
    return Row(
      children: [
        Expanded(child: _buildPeriodCard('Semaine', _weekStats, Colors.teal)),
        SizedBox(width: 10),
        Expanded(child: _buildPeriodCard('Mois', _monthStats, Colors.indigo)),
      ],
    );
  }

  Widget _buildPeriodCard(String title, Map<String, dynamic> stats, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: color),
              SizedBox(width: 6),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 12),
          Text('${stats['totalCA']?.toStringAsFixed(0) ?? 0} DA',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text('${stats['orderCount'] ?? 0} commandes', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          SizedBox(height: 8),
          Row(
            children: [
              _buildMiniStat('Collecté', ((stats['collected'] ?? 0) as double).toStringAsFixed(0), Colors.green),
              SizedBox(width: 8),
              _buildMiniStat('Impayé', ((stats['unpaid'] ?? 0) as double).toStringAsFixed(0), Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingOrdersPreview() {
    final pendingOrders = _allOrders.where((o) => o['status'] == 'pending').take(3).toList();

    if (pendingOrders.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text('Aucune commande en attente', style: TextStyle(color: Colors.green.shade700)),
          ],
        ),
      );
    }

    return Column(
      children: [
        ...pendingOrders.map((order) => Card(
              margin: EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Icon(Icons.shopping_bag, color: Colors.orange),
                ),
                title: Text(order['customer']?['name'] ?? 'Client', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${(order['items'] as List?)?.length ?? 0} articles'),
                trailing: Text('${_parseDouble(order['total']).toStringAsFixed(0)} DA',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                onTap: () => widget.onNavigate(1),
              ),
            )),
        if (_allOrders.where((o) => o['status'] == 'pending').length > 3)
          TextButton(
            onPressed: () => widget.onNavigate(1),
            child: Text('Voir toutes les commandes →'),
          ),
      ],
    );
  }

  Widget _buildDebtsPreview() {
    final totalDebt = _debts.fold<double>(0, (sum, d) => sum + _parseDouble(d['total_debt']));

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.red.shade400, Colors.red.shade600]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total des dettes', style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
                    Text('${totalDebt.toStringAsFixed(0)} DA',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration:
                    BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: Text('${_debts.length} clients', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...(_debts.take(2).map((d) => Container(
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.all(12),
                decoration:
                    BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      radius: 16,
                      child: Text((d['name'] ?? 'C')[0],
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(width: 10),
                    Expanded(child: Text(d['name'] ?? 'Client', style: TextStyle(color: Colors.white))),
                    Text('${_parseDouble(d['total_debt']).toStringAsFixed(0)} DA',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ))),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => widget.onNavigate(5),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white)),
              child: Text('Voir les détails'),
            ),
          ),
        ],
      ),
    );
  }
}
