// =====================================================
// PAGE: Finance Dashboard - Gestion financière complète
// Filtres par date, client, statut. Impression intégrée.
// Utilise FinancialServiceV2 (pas de duplication)
// =====================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/financial_models.dart';
import '../../../../core/services/financial_service_v2.dart';
import '../../../../core/utils/print_utils.dart';
import '../widgets/debt_payment_dialog.dart';
import '../widgets/finance_filters.dart';
import '../widgets/finance_summary_cards.dart';

class FinanceDashboardPage extends StatefulWidget {
  const FinanceDashboardPage({super.key});

  @override
  State<FinanceDashboardPage> createState() => _FinanceDashboardPageState();
}

class _FinanceDashboardPageState extends State<FinanceDashboardPage> with SingleTickerProviderStateMixin {
  final _service = FinancialServiceV2();
  final _printService = PrintService();
  final currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 0);
  
  late TabController _tabController;
  
  // État
  bool _isLoading = true;
  String? _error;
  
  // Données
  FinancialOverview? _overview;
  List<CustomerDebt> _debts = [];
  List<CustomerDebt> _filteredDebts = [];
  
  // Filtres
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dateTo = DateTime.now();
  String? _selectedCustomerId;
  double _minDebt = 0;
  String _searchQuery = '';
  SortOption _sortOption = SortOption.debtDesc;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final overview = await _service.getOverview(dateFrom: _dateFrom, dateTo: _dateTo);
      final debts = await _service.getDebts(minDebt: _minDebt, limit: 500);
      
      setState(() {
        _overview = overview;
        _debts = debts.data;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    _filteredDebts = _debts.where((debt) {
      // Filtre client
      if (_selectedCustomerId != null && debt.customerId != _selectedCustomerId) {
        return false;
      }
      // Filtre recherche
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return debt.name.toLowerCase().contains(query) ||
               (debt.phone?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();
    
    // Tri
    _filteredDebts.sort((a, b) {
      switch (_sortOption) {
        case SortOption.nameAsc:
          return a.name.compareTo(b.name);
        case SortOption.nameDesc:
          return b.name.compareTo(a.name);
        case SortOption.debtAsc:
          return a.totalDebt.compareTo(b.totalDebt);
        case SortOption.debtDesc:
          return b.totalDebt.compareTo(a.totalDebt);
        case SortOption.ordersDesc:
          return b.unpaidOrders.compareTo(a.unpaidOrders);
      }
    });
  }

  Future<void> _onPrintReport() async {
    if (_overview == null) return;
    
    // Afficher le dialog de configuration d'impression
    final config = await _showPrintConfigDialog();
    if (config == null) return; // Annulé
    
    // Filtrer les dettes selon la configuration
    final debtsToPrint = _filterDebtsForPrint(config);
    
    await _printService.printFinancialReport(
      context: context,
      overview: _overview!,
      debts: debtsToPrint,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      selectedCustomerIds: config.selectedCustomerIds,
      minDebt: config.minDebt,
      maxDebt: config.maxDebt,
      includeZeroDebt: config.includeZeroDebt,
    );
  }
  
  Future<PrintConfig?> _showPrintConfigDialog() async {
    final selectedCustomers = <String>{};
    double minDebt = 0;
    double? maxDebt;
    bool includeZeroDebt = false;
    
    return await showDialog<PrintConfig>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Configuration d\'impression'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section: Sélection des clients
                    const Text('Clients à inclure:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _filteredDebts.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Aucun client disponible'),
                            )
                          : ListView(
                              shrinkWrap: true,
                              children: [
                                CheckboxListTile(
                                  title: const Text('Tous les clients', style: TextStyle(fontWeight: FontWeight.bold)),
                                  value: selectedCustomers.length == _filteredDebts.length,
                                  tristate: selectedCustomers.isNotEmpty && selectedCustomers.length < _filteredDebts.length,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        selectedCustomers.addAll(_filteredDebts.map((d) => d.customerId));
                                      } else {
                                        selectedCustomers.clear();
                                      }
                                    });
                                  },
                                ),
                                const Divider(height: 1),
                                ..._filteredDebts.map((debt) => CheckboxListTile(
                                  dense: true,
                                  title: Text(debt.name),
                                  subtitle: Text(currencyFormat.format(debt.totalDebt)),
                                  value: selectedCustomers.contains(debt.customerId),
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        selectedCustomers.add(debt.customerId);
                                      } else {
                                        selectedCustomers.remove(debt.customerId);
                                      }
                                    });
                                  },
                                )),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Section: Filtres par montant
                    const Text('Filtres par montant de dette:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Minimum (DA)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              minDebt = double.tryParse(value) ?? 0;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Maximum (DA)',
                              hintText: 'Illimité',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              maxDebt = value.isEmpty ? null : double.tryParse(value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Option: Inclure clients sans dette
                    CheckboxListTile(
                      title: const Text('Inclure clients sans dette'),
                      subtitle: const Text('Afficher aussi les clients avec dette = 0 DA'),
                      value: includeZeroDebt,
                      onChanged: (value) {
                        setState(() {
                          includeZeroDebt = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context, PrintConfig(
                    selectedCustomerIds: selectedCustomers.isEmpty ? null : selectedCustomers,
                    minDebt: minDebt,
                    maxDebt: maxDebt,
                    includeZeroDebt: includeZeroDebt,
                  ));
                },
                icon: const Icon(Icons.print),
                label: const Text('Imprimer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  List<CustomerDebt> _filterDebtsForPrint(PrintConfig config) {
    return _filteredDebts.where((debt) {
      // Filtre par client sélectionné
      if (config.selectedCustomerIds != null && 
          !config.selectedCustomerIds!.contains(debt.customerId)) {
        return false;
      }
      
      // Filtre par montant minimum
      if (debt.totalDebt < config.minDebt) {
        return false;
      }
      
      // Filtre par montant maximum
      if (config.maxDebt != null && debt.totalDebt > config.maxDebt!) {
        return false;
      }
      
      // Filtre dette = 0
      if (!config.includeZeroDebt && debt.totalDebt == 0) {
        return false;
      }
      
      return true;
    }).toList();
  }

  Future<void> _onCollectPayment(CustomerDebt debt) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DebtPaymentDialog(
        customerId: debt.customerId,
        customerName: debt.name,
        totalDebt: debt.totalDebt,
      ),
    );
    
    if (result == true) {
      _loadData(); // Rafraîchir après paiement
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion Financière'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Imprimer le rapport',
            onPressed: _overview != null ? _onPrintReport : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Tableau de bord'),
            Tab(icon: Icon(Icons.people), text: 'Clients & Dettes'),
            Tab(icon: Icon(Icons.motorcycle), text: 'Stats Livreurs'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboardTab(),
                    _buildDebtsTab(),
                    _buildDelivererStatsTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Erreur: $_error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    if (_overview == null) return const SizedBox.shrink();
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filtres de période
            FinanceFilters(
              dateFrom: _dateFrom,
              dateTo: _dateTo,
              onDateChanged: (from, to) {
                setState(() {
                  _dateFrom = from;
                  _dateTo = to;
                });
                _loadData();
              },
            ),
            const SizedBox(height: 16),
            
            // Résumé
            FinanceSummaryCards(summary: _overview!.summary),
            const SizedBox(height: 24),
            
            // Top clients
            _buildTopClientsSection(),
            const SizedBox(height: 24),
            
            // Graphique de répartition (simplifié)
            _buildPaymentDistributionChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtsTab() {
    return Column(
      children: [
        // Barre de recherche et filtres
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher un client...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _applyFilters();
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<SortOption>(
                      value: _sortOption,
                      hint: const Text('Trier par'),
                      decoration: const InputDecoration(
                        labelText: 'Trier par',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: SortOption.debtDesc, child: Text('Dette (élevée → faible)')),
                        DropdownMenuItem(value: SortOption.debtAsc, child: Text('Dette (faible → élevée)')),
                        DropdownMenuItem(value: SortOption.nameAsc, child: Text('Nom (A → Z)')),
                        DropdownMenuItem(value: SortOption.nameDesc, child: Text('Nom (Z → A)')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _sortOption = value;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Chip(
                    label: Text('${_filteredDebts.length} clients'),
                    backgroundColor: Colors.blue[50],
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Liste des dettes
        Expanded(
          child: _filteredDebts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text('Aucune dette trouvée', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredDebts.length,
                  itemBuilder: (context, index) {
                    final debt = _filteredDebts[index];
                    return _DebtListTile(
                      debt: debt,
                      onCollect: () => _onCollectPayment(debt),
                      onViewDetails: () => _showDebtDetails(debt),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDelivererStatsTab() {
    if (_overview == null) return const SizedBox.shrink();
    
    final stats = _overview!.delivererStats;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Statistiques par Livreur',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ElevatedButton.icon(
                onPressed: () => _printService.printDelivererStats(
                  context: context,
                  stats: stats,
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                ),
                icon: const Icon(Icons.print),
                label: const Text('Imprimer'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: stats.length,
            itemBuilder: (context, index) {
              final stat = stats[index];
              return _DelivererStatCard(stat: stat);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopClientsSection() {
    final clients = _overview!.topClients;
    if (clients.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top 5 Clients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...clients.map((client) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green[100],
                child: Text(client.name.substring(0, 1).toUpperCase()),
              ),
              title: Text(client.name),
              subtitle: Text('${client.orderCount} commandes'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormat.currency(symbol: 'DA', decimalDigits: 0).format(client.totalRevenue),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (client.totalDebt > 0)
                    Text(
                      'Dette: ${NumberFormat.currency(symbol: 'DA', decimalDigits: 0).format(client.totalDebt)}',
                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDistributionChart() {
    final summary = _overview!.summary;
    final total = summary.totalOrders;
    if (total == 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Répartition des Paiements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildProgressBar('Payées', summary.paidOrders, total, Colors.green),
            const SizedBox(height: 8),
            _buildProgressBar('Partielles', summary.partialOrders, total, Colors.orange),
            const SizedBox(height: 8),
            _buildProgressBar('Non payées', summary.unpaidOrders, total, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(String label, int value, int total, Color color) {
    final percentage = total > 0 ? (value / total * 100) : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('$value (${percentage.toStringAsFixed(1)}%)'),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: total > 0 ? value / total : 0,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  void _showDebtDetails(CustomerDebt debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(debt.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                if (debt.phone != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(debt.phone!),
                    ],
                  ),
                ],
                const Divider(height: 32),
                
                // Détails de la dette
                Card(
                  color: Colors.orange[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('DETTE TOTALE', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(
                          NumberFormat.currency(symbol: 'DA', decimalDigits: 0).format(debt.totalDebt),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                        const SizedBox(height: 8),
                        Text('${debt.unpaidOrders} commandes impayées'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Bouton d'action
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _onCollectPayment(debt);
                    },
                    icon: const Icon(Icons.payments),
                    label: const Text('Enregistrer un paiement'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum SortOption {
  nameAsc,
  nameDesc,
  debtAsc,
  debtDesc,
  ordersDesc,
}

class _DebtListTile extends StatelessWidget {
  final CustomerDebt debt;
  final VoidCallback onCollect;
  final VoidCallback onViewDetails;

  const _DebtListTile({
    required this.debt,
    required this.onCollect,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 0);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: debt.totalDebt > 50000 ? Colors.red[100] : Colors.orange[100],
          child: Icon(Icons.person, color: debt.totalDebt > 50000 ? Colors.red : Colors.orange),
        ),
        title: Text(debt.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${debt.unpaidOrders} commandes impayées'),
            if (debt.phone != null)
              Text(debt.phone!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              currencyFormat.format(debt.totalDebt),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: debt.totalDebt > 50000 ? Colors.red : Colors.orange,
                fontSize: 16,
              ),
            ),
            TextButton(
              onPressed: onCollect,
              child: const Text('Encaisser', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        onTap: onViewDetails,
      ),
    );
  }
}

class _DelivererStatCard extends StatelessWidget {
  final DelivererStat stat;

  const _DelivererStatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 0);
    final successRate = stat.totalDeliveries > 0
        ? (stat.deliveredCount / stat.totalDeliveries * 100).toStringAsFixed(1)
        : '0';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(stat.name.substring(0, 1).toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stat.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: double.parse(successRate) >= 90 ? Colors.green[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$successRate%',
                    style: TextStyle(
                      color: double.parse(successRate) >= 90 ? Colors.green[800] : Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(label: 'Livraisons', value: '${stat.totalDeliveries}'),
                _StatItem(label: 'Délivrées', value: '${stat.deliveredCount}'),
                _StatItem(
                  label: 'Collecté',
                  value: currencyFormat.format(stat.amountCollected),
                  valueColor: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatItem({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ============================================
// CONFIGURATION D'IMPRESSION
// ============================================

class PrintConfig {
  final Set<String>? selectedCustomerIds;
  final double minDebt;
  final double? maxDebt;
  final bool includeZeroDebt;

  PrintConfig({
    this.selectedCustomerIds,
    this.minDebt = 0,
    this.maxDebt,
    this.includeZeroDebt = false,
  });
}
