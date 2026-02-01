import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/models/order_model.dart';
import '../../../../core/models/product_model.dart';

import '../../../../core/widgets/infinite_scroll_list.dart';
import '../../../../core/widgets/skeleton_loader.dart';

class OrderHistoryPage extends StatefulWidget {
  @override
  _OrderHistoryPageState createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final ApiService _apiService = ApiService();
  final List<Order> _orders = [];
  bool _isLoading = true;
  int _currentPage = 1;
  static const int _limit = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadOrders(refresh: true);
  }

  Future<void> _loadOrders({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _orders.clear();
        _isLoading = true;
      });
    }

    try {
      final response = await _apiService.getMyOrders(page: _currentPage, limit: _limit);
      
      if (response['success'] as bool) {
        final List<Order> newOrders = (response['data'] as List)
            .map((json) => Order.fromJson(json as Map<String, dynamic>))
            .toList();
            
        setState(() {
          if (refresh) _orders.clear();
          _orders.addAll(newOrders);
          _isLoading = false;
          
          // Check pagination metadata if available, otherwise check list length
          if (response['pagination'] != null) {
            _hasMore = (response['pagination'] as Map<String, dynamic>)['hasMore'] as bool? ?? false;
          } else {
            _hasMore = newOrders.length >= _limit;
          }
          
          if (_hasMore) _currentPage++;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'locked': return Colors.blue;
      case 'in_delivery': return Colors.purple;
      case 'delivered': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.hourglass_empty;
      case 'locked': return Icons.lock;
      case 'in_delivery': return Icons.local_shipping;
      case 'delivered': return Icons.check_circle;
      default: return Icons.help;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'En attente';
      case 'locked': return 'Validée';
      case 'in_delivery': return 'En livraison';
      case 'delivered': return 'Livrée';
      default: return status;
    }
  }

  Future<void> _editOrder(Order order) async {
    try {
      final response = await _apiService.getProducts();
      if (!(response['success'] as bool)) return;

      final products = (response['data'] as List)
          .where((json) => (json as Map<String, dynamic>)['active'] as bool? ?? false)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();

      Map<String, int> cart = {};
      for (var item in order.items) {
        cart[item.productId] = item.quantity;
      }

      if (!mounted) return;
      final result = await showModalBottomSheet<Map<String, int>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _EditOrderSheet(products: products, initialCart: cart),
      );

      if (result != null && result.isNotEmpty) {
        final items = result.entries.map((e) => {'productId': e.key, 'quantity': e.value}).toList();
        await _apiService.updateOrder(order.id, {'items': items});
        _loadOrders(refresh: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Commande modifiée!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _orders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: List.generate(5, (_) => const OrderCardSkeleton()),
        ),
      );
    }

    return InfiniteScrollList<Order>(
      items: _orders,
      isLoading: _isLoading,
      hasMore: _hasMore,
      onRefresh: () async => _loadOrders(refresh: true),
      onLoadMore: () => _loadOrders(refresh: false),
      emptyState: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text('Aucune commande', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            SizedBox(height: 8),
            Text('Vos commandes apparaîtront ici', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      ),
      itemBuilder: (context, order) => Card(
        margin: EdgeInsets.only(bottom: 12),
        elevation: 3,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            // Header avec statut
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(order.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getStatusIcon(order.status), color: Colors.white, size: 24),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getStatusText(order.status),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _getStatusColor(order.status),
                          ),
                        ),
                        Text(
                          'Commande #${order.id.substring(0, 8)}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${order.total.toStringAsFixed(0)} DA',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green.shade700),
                  ),
                ],
              ),
            ),
            
            // Liste des articles
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...order.items.map((item) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '${item.quantity}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(child: Text(item.productName)),
                        Text('${item.totalPrice.toStringAsFixed(0)} DA', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )),
                  
                  // Paiement
                  if (order.amountPaid > 0 || order.remainingAmount > 0) ...[
                    Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Payé', style: TextStyle(color: Colors.grey[600])),
                        Text('${order.amountPaid.toStringAsFixed(0)} DA', style: TextStyle(color: Colors.green)),
                      ],
                    ),
                    if (order.remainingAmount > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Reste à payer', style: TextStyle(color: Colors.grey[600])),
                          Text(
                            '${order.remainingAmount.toStringAsFixed(0)} DA',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                  ],
                  
                  // Boutons d'action si commande en attente
                  if (order.isPending) ...[
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _editOrder(order),
                            icon: Icon(Icons.edit, size: 18),
                            label: Text('Modifier'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: BorderSide(color: Colors.blue),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditOrderSheet extends StatefulWidget {
  final List<Product> products;
  final Map<String, int> initialCart;

  const _EditOrderSheet({required this.products, required this.initialCart});

  @override
  _EditOrderSheetState createState() => _EditOrderSheetState();
}

class _EditOrderSheetState extends State<_EditOrderSheet> {
  late Map<String, int> _cart;

  @override
  void initState() {
    super.initState();
    _cart = Map.from(widget.initialCart);
  }

  void _updateQuantity(String productId, int change) {
    setState(() {
      final currentQty = _cart[productId] ?? 0;
      final newQty = currentQty + change;
      if (newQty <= 0) {
        _cart.remove(productId);
      } else {
        _cart[productId] = newQty;
      }
    });
  }

  double get _total {
    double total = 0;
    _cart.forEach((id, qty) {
      final product = widget.products.firstWhere((p) => p.id == id, orElse: () => widget.products.first);
      total += product.price * qty;
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          
          // Header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Modifier la commande', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close)),
              ],
            ),
          ),
          
          // Products
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.products.length,
              itemBuilder: (context, index) {
                final product = widget.products[index];
                final qty = _cart[product.id] ?? 0;
                
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(product.name, style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${product.price.toStringAsFixed(0)} DA'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: qty > 0 ? () => _updateQuantity(product.id, -1) : null,
                          icon: Icon(Icons.remove_circle, color: qty > 0 ? Colors.red : Colors.grey),
                        ),
                        SizedBox(width: 24, child: Text('$qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                        IconButton(
                          onPressed: () => _updateQuantity(product.id, 1),
                          icon: Icon(Icons.add_circle, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Footer
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _cart.isEmpty ? null : () => Navigator.pop(context, _cart),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('SAUVEGARDER  •  ${_total.toStringAsFixed(0)} DA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
