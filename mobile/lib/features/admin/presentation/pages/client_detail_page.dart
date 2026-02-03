import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/debt_model.dart';
import '../../../../core/models/packaging_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/financial_service.dart';
import '../../../../core/services/settings_service.dart';

class ClientDetailPage extends StatefulWidget {
  const ClientDetailPage({
    required this.client,
    this.apiService,
    this.cacheService,
    this.settingsService,
    super.key,
  });
  final Map<String, dynamic> client;
  final ApiService? apiService;
  final CacheService? cacheService;
  final SettingsService? settingsService;

  @override
  _ClientDetailPageState createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> with SingleTickerProviderStateMixin {
  late final ApiService _apiService;
  late final CacheService _cacheService;
  late final SettingsService _settings;
  late final FinancialService _financialService;
  late TabController _tabController;

  List<dynamic> _orders = [];
  List<dynamic> _deliveries = [];
  List<dynamic> _debtHistory = [];
  bool _isLoading = true;
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();
  final _creditLimitController = TextEditingController();
  CustomerDebt? _customerDebt;
  double? _creditLimit;
  List<PackagingBalance> _packagingBalance = [];
  List<PackagingTransaction> _packagingHistory = [];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _cacheService = widget.cacheService ?? CacheService();
    _settings = widget.settingsService ?? SettingsService();
    _financialService = FinancialService();
    _tabController = TabController(length: 4, vsync: this);
    _notesController.text = (widget.client['notes'] as String?) ?? '';
    _addressController.text = (widget.client['address'] as String?) ?? '';
    if (widget.client['credit_limit'] != null) {
      _creditLimit = (widget.client['credit_limit'] as num).toDouble();
      _creditLimitController.text = _creditLimit!.toStringAsFixed(0);
    }
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    _addressController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _settings.loadSettings();

    // Essayer le cache d'abord
    final cachedHistory = await _cacheService.getCachedClientHistory(widget.client['id'] as String);
    if (cachedHistory != null) {
      setState(() {
        _orders = cachedHistory.where((o) => o['type'] == 'order').toList();
        _deliveries = cachedHistory.where((o) => o['type'] == 'delivery').toList();
      });
    }

    await _loadClientData();
  }

  Future<void> _loadClientData() async {
    try {
      print('🔍 Loading data for client: ${widget.client['id']}');

      final results = await Future.wait<Map<String, dynamic>>([
        _apiService.getOrders(customerId: widget.client['id'] as String, limit: 100),
        _apiService.getDeliveries(customerId: widget.client['id'] as String, limit: 100),
        _apiService.getCustomerDebt(widget.client['id'] as String),
      ]);

      print('📦 Orders response: ${results[0]}');
      print('🚚 Deliveries response: ${results[1]}');
      print('💰 Debt response: ${results[2]}');

      final clientOrders = (results[0]['data'] as List?) ?? [];
      final clientDeliveries = (results[1]['data'] as List?) ?? [];
      final debtInfo = results[2];

      print('✅ Parsed: ${clientOrders.length} orders, ${clientDeliveries.length} deliveries');

      // Mettre en cache
      final history = [
        ...clientOrders.map((o) => {...(o as Map<String, dynamic>), 'type': 'order'}),
        ...clientDeliveries.map((d) => {...(d as Map<String, dynamic>), 'type': 'delivery'}),
      ];
      await _cacheService.cacheClientHistory(widget.client['id'] as String, history);

      setState(() {
        _orders = clientOrders;
        _deliveries = clientDeliveries;
        _customerDebt = CustomerDebt.fromJson(debtInfo);
        _debtHistory = [];
        _isLoading = false;
      });
      await _loadPackaging();
    } catch (e) {
      print('❌ Error loading client data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPackaging() async {
    try {
      final balanceResult = await _apiService.getCustomerPackagingBalance(widget.client['id'] as String);
      final historyResult = await _apiService.getCustomerPackagingHistory(widget.client['id'] as String);

      if (mounted) {
        setState(() {
          if (balanceResult['success'] == true && balanceResult['data'] != null) {
            _packagingBalance = (balanceResult['data'] is List<dynamic> ? balanceResult['data'] as List<dynamic> : []).map((e) => PackagingBalance.fromJson(e as Map<String, dynamic>)).toList();
          }
          if (historyResult['success'] == true && historyResult['data'] != null) {
            _packagingHistory = (historyResult['data'] is List<dynamic> ? historyResult['data'] as List<dynamic> : []).map((e) => PackagingTransaction.fromJson(e as Map<String, dynamic>)).toList();
          }
        });
      }
    } catch (e) {
      // Ignore packaging errors
    }
  }

  double get _totalDebt {
    double debt = 0;
    for (final o in _orders) {
      final total = _parseDouble(o['total']);
      final paid = _parseDouble(o['amountPaid']);
      debt += total - paid;
    }
    return debt < 0 ? 0 : debt;
  }

  double get _totalOrders => _orders.fold(0, (sum, o) => sum + _parseDouble(o['total']));

  // ignore: unused_element
  int get _deliveredCount => _deliveries.where((d) => d['status'] == 'delivered').length;
  // ignore: unused_element
  int get _failedCount => _deliveries.where((d) => d['status'] == 'failed').length;

  double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  Future<void> _callClient() async {
    final phone = widget.client['phone'];
    if (phone != null && phone.toString().isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  Future<void> _openMaps() async {
    final lat = widget.client['address_lat'];
    final lng = widget.client['address_lng'];
    if (lat != null && lng != null) {
      final uri = Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lng&zoom=17');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _updateAddress() async {
    final newAddress = _addressController.text.trim();
    if (newAddress.isEmpty) return;

    try {
      await _apiService.updateUserAddress(widget.client['id'] as String, newAddress);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Adresse mise à jour'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _updateCreditLimit() async {
    final text = _creditLimitController.text.trim();
    if (text.isEmpty) {
      if (_creditLimit != null) {
        // Supprimer la limite
        await _performLimitUpdate(null);
      }
      return;
    }

    final limit = double.tryParse(text);
    if (limit == null || limit < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Montant invalide'), backgroundColor: Colors.red),
      );
      return;
    }

    await _performLimitUpdate(limit);
  }

  Future<void> _performLimitUpdate(double? limit) async {
    try {
      await _apiService.updateCreditLimit(widget.client['id'] as String, limit);
      setState(() {
        _creditLimit = limit;
        widget.client['credit_limit'] = limit; // Update local reference
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Limite de crédit mise à jour'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showPaymentModal() {
    if (_customerDebt == null || !_customerDebt!.hasDebt) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ce client n\'a pas de dette'), backgroundColor: Colors.orange),
      );
      return;
    }

    final amountController = TextEditingController();
    final notesController = TextEditingController();
    amountController.text = _customerDebt!.totalDebt.toStringAsFixed(0);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enregistrer un paiement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dette actuelle: ${_customerDebt!.totalDebt.toStringAsFixed(0)} DA',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant (DA)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Note (optionnel)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Montant invalide'), backgroundColor: Colors.red),
                );
                return;
              }

              try {
                await _financialService.recordPayment(
                  customerId: widget.client['id'] as String,
                  amount: amount,
                  notes: notesController.text.isNotEmpty ? notesController.text : null,
                );
                Navigator.pop(context);
                await _loadClientData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Paiement enregistré'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF2E7D32)),
            child: Text('Enregistrer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final isBlocked = client['active'] == false;
    final hasLocation = client['address_lat'] != null && client['address_lng'] != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Fiche client'),
        backgroundColor: Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          if (client['phone'] != null) IconButton(icon: Icon(Icons.phone), onPressed: _callClient, tooltip: 'Appeler'),
          IconButton(
            icon: Icon(isBlocked ? Icons.lock : Icons.lock_open),
            tooltip: isBlocked ? 'Débloquer' : 'Bloquer',
            onPressed: () => _toggleBlock(client),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : RefreshIndicator(
              onRefresh: _loadClientData,
              color: Color(0xFF2E7D32),
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Header client
                    _buildHeader(client, isBlocked),

                    // Infos détaillées
                    _buildInfoSection(client, hasLocation),

                    // Stats
                    _buildStatsSection(),

                    // Credit Limit
                    _buildCreditLimitCard(),

                    // Alerte dette
                    if (_totalDebt > _settings.debtAlertThreshold) _buildDebtAlert(isBlocked),

                    // Tabs historique
                    _buildHistoryTabs(),
                  ],
                ),
              ),
            ),
      floatingActionButton: (_customerDebt?.hasDebt ?? false)
          ? FloatingActionButton.extended(
              onPressed: _showPaymentModal,
              label: Text('Recouvrer'),
              icon: Icon(Icons.attach_money),
              backgroundColor: Color(0xFF2E7D32),
            )
          : null,
    );
  }

  Widget _buildHeader(Map<String, dynamic> client, bool isBlocked) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isBlocked ? [Colors.red.shade400, Colors.red.shade600] : [Color(0xFF2E7D32), Color(0xFF1B5E20)],
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              ((client['name'] as String?) ?? 'C')[0].toUpperCase(),
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                (client['name'] as String?) ?? 'Client',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (isBlocked) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Text('BLOQUÉ', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          if (client['email'] != null)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(client['email'] as String, style: TextStyle(color: Colors.white70, fontSize: 14)),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> client, bool hasLocation) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 16),

          // Téléphone
          _buildInfoRow(Icons.phone, 'Téléphone', (client['phone'] as String?) ?? 'Non renseigné',
              onTap: client['phone'] != null ? _callClient : null),
          Divider(height: 24),

          // Email
          _buildInfoRow(Icons.email, 'Email', (client['email'] as String?) ?? 'Non renseigné'),
          Divider(height: 24),

          // Adresse
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, color: Color(0xFF2E7D32), size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Adresse', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    SizedBox(height: 4),
                    TextField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        hintText: 'Entrer l\'adresse...',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.save, size: 20),
                          onPressed: _updateAddress,
                        ),
                      ),
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Bouton carte si coordonnées disponibles
          if (hasLocation) ...[
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openMaps,
                icon: Icon(Icons.map),
                label: Text('Voir sur la carte'),
                style: OutlinedButton.styleFrom(foregroundColor: Color(0xFF2E7D32)),
              ),
            ),
          ],

          Divider(height: 24),

          // Date d'inscription
          _buildInfoRow(
              Icons.calendar_today, 'Client depuis', _formatDate((client['createdAt'] as String?) ?? (client['created_at'] as String?))),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF2E7D32), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildCreditLimitCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.credit_card, color: Color(0xFF2E7D32), size: 20),
              SizedBox(width: 8),
              Text('Plafond de crédit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _creditLimitController,
                  decoration: InputDecoration(
                    labelText: 'Limite (DA)',
                    hintText: 'Vide = Illimité',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixText: 'DA',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton(
                onPressed: _updateCreditLimit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
                child: Text('OK'),
              ),
            ],
          ),
          if (_creditLimit != null) ...[
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_totalDebt / _creditLimit!).clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              color: _totalDebt > _creditLimit!
                  ? Colors.red
                  : (_totalDebt > (_creditLimit! * 0.8) ? Colors.orange : Colors.green),
            ),
            SizedBox(height: 4),
            Text(
              'Utilisé: ${_totalDebt.toStringAsFixed(0)} / ${_creditLimit!.toStringAsFixed(0)} DA (${((_totalDebt / _creditLimit!) * 100).toStringAsFixed(1)}%)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard('Commandes', '${_orders.length}', Icons.shopping_bag, Colors.blue),
          SizedBox(width: 8),
          _buildStatCard('Total CA', '${_totalOrders.toStringAsFixed(0)} DA', Icons.trending_up, Color(0xFF2E7D32)),
          SizedBox(width: 8),
          _buildStatCard(
              'Dette', '${_totalDebt.toStringAsFixed(0)} DA', Icons.warning, _totalDebt > 0 ? Colors.red : Colors.grey),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(height: 6),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtAlert(bool isBlocked) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alerte dette élevée', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                Text('Dette de ${_totalDebt.toStringAsFixed(0)} DA',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
              ],
            ),
          ),
          if (!isBlocked)
            TextButton(
              onPressed: () => _toggleBlock(widget.client),
              child: Text('Bloquer', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTabs() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Color(0xFF2E7D32),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF2E7D32),
            tabs: [
              Tab(text: 'Commandes (${_orders.length})'),
              Tab(text: 'Livraisons (${_deliveries.length})'),
              Tab(text: 'Dette'),
              Tab(text: 'Consignes'),
            ],
          ),
          SizedBox(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList(),
                _buildDeliveriesList(),
                _buildDebtHistoryTab(),
                _buildPackagingTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.grey[400]),
            SizedBox(height: 8),
            Text('Aucune commande', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    // Trier par date décroissante
    final sortedOrders = List<dynamic>.from(_orders)..sort((a, b) => ((b as Map<String, dynamic>)['createdAt'] as String? ?? '').compareTo((a as Map<String, dynamic>)['createdAt'] as String? ?? ''));

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: sortedOrders.length,
      itemBuilder: (context, index) {
        final order = sortedOrders[index] as Map<String, dynamic>;
        return _buildOrderCard(order, index + 1);
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, int index) {
    final date = DateTime.tryParse((order['createdAt'] as String?) ?? '');
    final total = _parseDouble(order['total']);
    final paid = _parseDouble(order['amountPaid']);
    final remaining = total - paid;
    final status = (order['status'] as String?) ?? 'pending';
    final orderNumber = order['orderNumber']?.toString() ?? order['order_number']?.toString();

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(status as String?).withValues(alpha: 0.2),
          child: Text(
            orderNumber != null ? '#$orderNumber' : '#$index',
            style: TextStyle(color: _getStatusColor(status as String?), fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        title: Row(
          children: [
            Text('${total.toStringAsFixed(0)} DA', style: TextStyle(fontWeight: FontWeight.bold)),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status as String?),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_getStatusLabel(status as String?),
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Icon(Icons.calendar_today, size: 12, color: Colors.grey),
            SizedBox(width: 4),
            Text(
                date != null
                    ? '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}'
                    : '',
                style: TextStyle(fontSize: 12)),
            if (remaining > 0) ...[
              Spacer(),
              Text('Reste: ${remaining.toStringAsFixed(0)} DA',
                  style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
        children: [
          // Détails des produits
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Produits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(height: 8),
                ...(order['items'] as List? ?? []).map((item) {
                  final quantity = item['quantity'] is int
                      ? item['quantity']
                      : int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text('${quantity}x ', style: TextStyle(fontWeight: FontWeight.w500)),
                        Expanded(child: Text((item['productName'] as String?) ?? 'Produit')),
                        Text('${_parseDouble(item['unitPrice']).toStringAsFixed(0)} DA',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }),
                Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${total.toStringAsFixed(0)} DA', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                if (paid > 0) ...[
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Payé', style: TextStyle(color: Colors.green)),
                      Text('${paid.toStringAsFixed(0)} DA', style: TextStyle(color: Colors.green)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveriesList() {
    if (_deliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delivery_dining, size: 48, color: Colors.grey[400]),
            SizedBox(height: 8),
            Text('Aucune livraison', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    // Trier par date décroissante
    final sortedDeliveries = List<Map<String, dynamic>>.from(_deliveries.cast<Map<String, dynamic>>())
      ..sort((a, b) => ((b['createdAt'] as String?) ?? '').compareTo((a['createdAt'] as String?) ?? ''));

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: sortedDeliveries.length,
      itemBuilder: (context, index) {
        final delivery = sortedDeliveries[index];
        return _buildDeliveryCard(delivery);
      },
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery) {
    final status = (delivery['status'] as String?) ?? 'assigned';
    final delivererName = (delivery['deliverer'] as Map<String, dynamic>?)?['name'] as String? ?? 'Livreur';
    final collected = _parseDouble(delivery['amountCollected']);
    final comment = delivery['comment'] as String?;
    final failureReason = delivery['failureReason'] as String?;
    final deliveredAt = delivery['deliveredAt'] != null ? DateTime.tryParse(delivery['deliveredAt'] as String) : null;
    final attempts =
        delivery['attempts'] is int ? delivery['attempts'] as int : int.tryParse(delivery['attempts']?.toString() ?? '0') ?? 0;

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _getDeliveryStatusColor(status as String?).withValues(alpha: 0.2),
                  child: Icon(_getDeliveryStatusIcon(status as String?), color: _getDeliveryStatusColor(status as String?), size: 18),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getDeliveryStatusLabel(status as String?), style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Par $delivererName', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                if (collected > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${collected.toStringAsFixed(0)} DA',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
              ],
            ),
            if (deliveredAt != null) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                      'Livrée le ${deliveredAt.day}/${deliveredAt.month}/${deliveredAt.year} à ${deliveredAt.hour}:${deliveredAt.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
            if (attempts > 1) ...[
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.refresh, size: 14, color: Colors.orange),
                  SizedBox(width: 4),
                  Text('$attempts tentatives', style: TextStyle(fontSize: 12, color: Colors.orange)),
                ],
              ),
            ],
            if (failureReason is String && failureReason.isNotEmpty) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(child: Text(failureReason, style: TextStyle(fontSize: 12, color: Colors.red))),
                  ],
                ),
              ),
            ],
            if (comment is String && comment.isNotEmpty) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.comment, size: 16, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(child: Text(comment, style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'locked':
      case 'validated':
        return Colors.blue;
      case 'in_delivery':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'locked':
        return 'Verrouillée';
      case 'validated':
        return 'Validée';
      case 'preparing':
        return 'En préparation';
      case 'ready':
        return 'Prête';
      case 'in_delivery':
        return 'En livraison';
      case 'delivered':
        return 'Livrée';
      case 'failed':
        return 'Échouée';
      default:
        return status ?? 'Inconnu';
    }
  }

  Color _getDeliveryStatusColor(String? status) {
    switch (status) {
      case 'assigned':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'postponed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getDeliveryStatusIcon(String? status) {
    switch (status) {
      case 'assigned':
        return Icons.assignment;
      case 'in_progress':
        return Icons.delivery_dining;
      case 'delivered':
        return Icons.check_circle;
      case 'failed':
        return Icons.cancel;
      case 'postponed':
        return Icons.schedule;
      default:
        return Icons.help;
    }
  }

  String _getDeliveryStatusLabel(String? status) {
    switch (status) {
      case 'assigned':
        return 'Assignée';
      case 'in_progress':
        return 'En cours';
      case 'delivered':
        return 'Livrée';
      case 'failed':
        return 'Échouée';
      case 'postponed':
        return 'Reportée';
      default:
        return status ?? 'Inconnu';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return 'N/A';
    final months = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${months[date.month]} ${date.year}';
  }

  Future<void> _toggleBlock(Map<String, dynamic> client) async {
    final isBlocked = client['active'] == false;
    final action = isBlocked ? 'débloquer' : 'bloquer';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${isBlocked ? 'Débloquer' : 'Bloquer'} ce client?'),
        content: Text(isBlocked
            ? 'Ce client pourra à nouveau passer des commandes.'
            : 'Ce client ne pourra plus passer de commandes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: isBlocked ? Colors.green : Colors.red),
            child: Text(action.toUpperCase(), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.toggleUser(client['id'] as String);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Client ${isBlocked ? 'débloqué' : 'bloqué'}'),
              backgroundColor: isBlocked ? Colors.green : Colors.orange),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildDebtHistoryTab() {
    if (_debtHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[400]),
            SizedBox(height: 8),
            Text('Aucun historique de paiement', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: _debtHistory.length,
      itemBuilder: (context, index) {
        final payment = _debtHistory[index] as Map<String, dynamic>;
        final date = DateTime.tryParse((payment['created_at'] as String?) ?? '');
        final amount = _parseDouble(payment['amount']);
        final collectorName = (payment['collector_name'] as String?) ?? 'Inconnu';
        final type = (payment['payment_type'] as String?) ?? 'cash';

        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade50,
              child: Icon(Icons.payment, color: Colors.green),
            ),
            title: Text('${amount.toStringAsFixed(0)} DA',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Par $collectorName le ${_dateFormat(date)}'),
                if (payment['note'] != null)
                  Text('Note: ${payment['note']}', style: TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
            trailing: Chip(
              label: Text(_paymentTypeLabel(type)),
              backgroundColor: Colors.grey[100],
            ),
          ),
        );
      },
    );
  }

  String _dateFormat(DateTime? d) {
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _paymentTypeLabel(String type) {
    switch (type) {
      case 'cash':
        return 'Espèces';
      case 'check':
        return 'Chèque';
      case 'transfer':
        return 'Virement';
      default:
        return 'Autre';
    }
  }

  Widget _buildPackagingTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance Summary
          if (_packagingBalance.isNotEmpty) ...[
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.inventory_2, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Solde Consignes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 12),
                    ..._packagingBalance.map((balance) => Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(balance.typeName)),
                              Row(
                                children: [
                                  Text('Donné: ${balance.totalGiven}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  SizedBox(width: 8),
                                  Text('Retour: ${balance.totalReturned}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  SizedBox(width: 12),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: balance.outstanding > 0 ? Colors.orange : Colors.green,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${balance.outstanding}',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
          ],

          // History
          Text('Historique', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          if (_packagingHistory.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                    SizedBox(height: 8),
                    Text('Aucune transaction', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            )
          else
            ..._packagingHistory.map((tx) => Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: tx.isReturned ? Colors.green.shade50 : Colors.orange.shade50,
                      child: Icon(
                        tx.isReturned ? Icons.arrow_downward : Icons.arrow_upward,
                        color: tx.isReturned ? Colors.green : Colors.orange,
                      ),
                    ),
                    title: Text(
                      '${tx.absoluteQuantity} x ${tx.typeName ?? "Consigne"}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.isReturned ? 'Retourné' : 'Donné',
                          style: TextStyle(
                            color: tx.isReturned ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(_dateFormat(tx.createdAt), style: TextStyle(fontSize: 12)),
                        if (tx.note != null && tx.note!.isNotEmpty)
                          Text('Note: ${tx.note}', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
