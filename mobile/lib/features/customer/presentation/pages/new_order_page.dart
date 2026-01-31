import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/favorite_service.dart';
import '../../../../core/database/sync_service.dart';
import '../../../../core/models/product_model.dart';
import '../../../../core/models/favorite_order_model.dart';
// ... (skip lines)

enum ViewMode { grid, list, compact }

class NewOrderPage extends StatefulWidget {
  @override
  _NewOrderPageState createState() => _NewOrderPageState();
}

class _NewOrderPageState extends State<NewOrderPage> {
  final ApiService _apiService = ApiService();
  final FavoriteService _favoriteService = FavoriteService();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<FavoriteOrder> _favorites = [];
  UserPreferences? _preferences;
  Map<String, int> _cart = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  ViewMode _viewMode = ViewMode.grid;
  String? _selectedCategory;
  bool _groupByCategory = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadFavorites();
    _loadPreferences();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _apiService.getProducts();
      if (response['success']) {
        setState(() {
          _products = (response['data'] as List)
              .where((json) => json['active'] == true)
              .map((json) => Product.fromJson(json))
              .toList();
          _filteredProducts = _products;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final response = await _favoriteService.getMyFavorites();
      if (response['success'] && response['data'] != null) {
        setState(() {
          _favorites = (response['data'] as List)
              .map((json) => FavoriteOrder.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      // Silencieux - les favoris sont optionnels
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final response = await _favoriteService.getPreferences();
      if (response['success'] && response['data'] != null) {
        setState(() {
          _preferences = UserPreferences.fromJson(response['data']);
        });
      }
    } catch (e) {
      // Silencieux
    }
  }

  List<String> get _categories {
    return _products
        .map((p) => p.category ?? 'Autre')
        .toSet()
        .toList()
      ..sort();
  }

  Map<String, List<Product>> get _groupedProducts {
    Map<String, List<Product>> grouped = {};
    for (var product in _filteredProducts) {
      final cat = product.category ?? 'Autre';
      grouped.putIfAbsent(cat, () => []).add(product);
    }
    return grouped;
  }

  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    var filtered = _products.toList();
    
    // Filtre par recherche
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) => 
        p.name.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    // Filtre par catégorie
    if (_selectedCategory != null) {
      filtered = filtered.where((p) => 
        (p.category ?? 'Autre') == _selectedCategory
      ).toList();
    }
    
    _filteredProducts = filtered;
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

  double get _totalAmount {
    double total = 0;
    _cart.forEach((productId, quantity) {
      final product = _products.firstWhere((p) => p.id == productId, orElse: () => _products.first);
      total += product.price * quantity;
    });
    return total;
  }

  int get _totalItems {
    return _cart.values.fold(0, (sum, qty) => sum + qty);
  }

  Future<void> _submitOrder() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Votre panier est vide')),
      );
      return;
    }

    final items = _cart.entries.map((entry) => {
      'productId': entry.key,
      'quantity': entry.value,
    }).toList();
    final orderData = {'items': items};

    final syncService = SyncService();

    // Offline Mode
    if (!syncService.isOnline) {
      await syncService.addOfflineAction('CREATE_ORDER', orderData);
      setState(() {
        _cart.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hors ligne : Commande sauvegardée localement'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    try {
      await _apiService.createOrder(orderData);
      
      // Détecter pattern si préférences activées
      if (_preferences?.favoriteOrdersEnabled == true && _preferences?.autoSuggestEnabled == true) {
        _detectPattern(items);
      }
      
      setState(() {
        _cart.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Commande créée avec succès!'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'VOIR',
            textColor: Colors.white,
            onPressed: () {
              // Navigation vers historique
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  Future<void> _detectPattern(List<Map<String, dynamic>> items) async {
    try {
      final response = await _favoriteService.detectPattern(items: items);
      if (response['success'] && response['data']?['should_suggest'] == true) {
        final occurrences = response['data']['occurrences'] ?? 0;
        _showPatternSuggestion(items, occurrences);
      }
    } catch (e) {
      // Silencieux
    }
  }

  void _showPatternSuggestion(List<Map<String, dynamic>> items, int occurrences) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lightbulb, color: Colors.amber),
            SizedBox(width: 12),
            Expanded(child: Text('Commande habituelle détectée')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vous avez commandé ces articles $occurrences fois.'),
            SizedBox(height: 8),
            Text('Voulez-vous sauvegarder cette commande comme favori pour commander plus rapidement la prochaine fois ?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Non merci'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showCreateFavoriteDialog(items);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  void _showCreateFavoriteDialog(List<Map<String, dynamic>> items) {
    final controller = TextEditingController(text: 'Ma commande habituelle');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nommer votre favori'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Nom',
            hintText: 'Ex: Commande du lundi',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                try {
                  await _favoriteService.createFavorite(
                    name: name,
                    items: items,
                    fromPattern: true,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Favori "$name" créé!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadFavorites();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: ${e.toString()}')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _showFavoritesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.green),
                  SizedBox(width: 12),
                  Text('Mes favoris', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Liste
            Expanded(
              child: _favorites.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_border, size: 60, color: Colors.grey[400]),
                          SizedBox(height: 12),
                          Text('Aucun favori', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _favorites.length,
                      itemBuilder: (context, index) {
                        final favorite = _favorites[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        favorite.name,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    if (favorite.isAutoDetected)
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text('Auto', style: TextStyle(fontSize: 10, color: Colors.amber.shade700)),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text('${favorite.items.length} articles • ${favorite.total.toStringAsFixed(0)} DA',
                                    style: TextStyle(color: Colors.grey[600])),
                                if (favorite.orderCount > 0)
                                  Text('Utilisé ${favorite.orderCount} fois', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () async {
                                        try {
                                          await _favoriteService.deleteFavorite(favorite.id);
                                          _loadFavorites();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Favori supprimé')),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Erreur: ${e.toString()}')),
                                          );
                                        }
                                      },
                                      icon: Icon(Icons.delete, size: 18, color: Colors.red),
                                      label: Text('Supprimer', style: TextStyle(color: Colors.red)),
                                    ),
                                    SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _loadFavoriteToCart(favorite);
                                      },
                                      icon: Icon(Icons.shopping_cart, size: 18),
                                      label: Text('Utiliser'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _loadFavoriteToCart(FavoriteOrder favorite) async {
    try {
      // Enregistrer l'utilisation
      await _favoriteService.useFavorite(favorite.id);
      
      // Charger dans le panier
      setState(() {
        _cart.clear();
        for (var item in favorite.items) {
          _cart[item.productId] = item.quantity;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Favori "${favorite.name}" chargé!'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'COMMANDER',
            textColor: Colors.white,
            onPressed: _submitOrder,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.green));
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text('Aucun produit disponible', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Barre de recherche et options
        Container(
          padding: EdgeInsets.all(12),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              // Recherche
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterProducts,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un produit...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _filterProducts('');
                          },
                        )
                      : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              SizedBox(height: 10),
              
              // Options d'affichage
              Row(
                children: [
                  // Bouton Favoris (si activé et favoris existent)
                  if (_preferences?.favoriteOrdersEnabled == true && _favorites.isNotEmpty) ...[
                    GestureDetector(
                      onTap: _showFavoritesSheet,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 18, color: Colors.amber.shade700),
                            SizedBox(width: 6),
                            Text('Favoris', style: TextStyle(fontSize: 13, color: Colors.amber.shade700, fontWeight: FontWeight.w600)),
                            SizedBox(width: 4),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('${_favorites.length}', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                  ],
                  // Mode d'affichage
                  _buildViewModeButton(ViewMode.grid, Icons.grid_view, 'Grille'),
                  SizedBox(width: 8),
                  _buildViewModeButton(ViewMode.list, Icons.view_list, 'Liste'),
                  SizedBox(width: 8),
                  _buildViewModeButton(ViewMode.compact, Icons.view_headline, 'Compact'),
                  Spacer(),
                  // Grouper par catégorie
                  GestureDetector(
                    onTap: () => setState(() => _groupByCategory = !_groupByCategory),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _groupByCategory ? Colors.green : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.category, size: 16, color: _groupByCategory ? Colors.white : Colors.green),
                          SizedBox(width: 4),
                          Text('Catégories', style: TextStyle(fontSize: 12, color: _groupByCategory ? Colors.white : Colors.green, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // Filtres catégories (si pas groupé)
              if (!_groupByCategory && _categories.length > 1) ...[
                SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip('Tous', null),
                      SizedBox(width: 8),
                      ..._categories.map((cat) => Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: _buildCategoryChip(cat, cat),
                      )),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Résumé panier
        if (_cart.isNotEmpty)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.green.shade600, Colors.green.shade400]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 8, offset: Offset(0, 4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.shopping_cart, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text('$_totalItems article${_totalItems > 1 ? 's' : ''}', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                  ],
                ),
                Text('${_totalAmount.toStringAsFixed(0)} DA', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        
        // Résultat recherche
        if (_searchQuery.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('${_filteredProducts.length} résultat${_filteredProducts.length > 1 ? 's' : ''}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
        
        // Liste des produits
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadProducts,
            color: Colors.green,
            child: _filteredProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                      SizedBox(height: 12),
                      Text('Aucun produit trouvé', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : _groupByCategory ? _buildGroupedList() : _buildProductList(),
          ),
        ),
        
        // Bouton commander
        if (_cart.isNotEmpty)
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
                  onPressed: _submitOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 24),
                      SizedBox(width: 12),
                      Text('COMMANDER  •  ${_totalAmount.toStringAsFixed(0)} DA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildViewModeButton(ViewMode mode, IconData icon, String tooltip) {
    final isSelected = _viewMode == mode;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => setState(() => _viewMode = mode),
        child: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green),
          ),
          child: Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.green),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? value) {
    final isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedCategory = value;
        _applyFilters();
      }),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.green, fontWeight: FontWeight.w500, fontSize: 13)),
      ),
    );
  }

  Widget _buildGroupedList() {
    final grouped = _groupedProducts;
    return ListView(
      padding: EdgeInsets.all(12),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header catégorie
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.category, size: 18, color: Colors.green.shade700),
                  SizedBox(width: 8),
                  Text(entry.key, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 16)),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
                    child: Text('${entry.value.length}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
            // Produits de la catégorie
            ..._buildProductsForCategory(entry.value),
            SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  List<Widget> _buildProductsForCategory(List<Product> products) {
    switch (_viewMode) {
      case ViewMode.grid:
        return [
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) => _buildGridCard(products[index]),
          ),
        ];
      case ViewMode.list:
        return products.map((p) => _buildListCard(p)).toList();
      case ViewMode.compact:
        return products.map((p) => _buildCompactCard(p)).toList();
    }
  }

  Widget _buildProductList() {
    switch (_viewMode) {
      case ViewMode.grid:
        return GridView.builder(
          padding: EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _filteredProducts.length,
          itemBuilder: (context, index) => _buildGridCard(_filteredProducts[index]),
        );
      case ViewMode.list:
        return ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: _filteredProducts.length,
          itemBuilder: (context, index) => _buildListCard(_filteredProducts[index]),
        );
      case ViewMode.compact:
        return ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: _filteredProducts.length,
          itemBuilder: (context, index) => _buildCompactCard(_filteredProducts[index]),
        );
    }
  }

  // Mode Grille (original)
  Widget _buildGridCard(Product product) {
    final quantity = _cart[product.id] ?? 0;
    
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: _buildProductImage(product, 40),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(product.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  Text('${product.price.toStringAsFixed(0)} DA', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 16)),
                  _buildQuantityControls(product, quantity),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mode Liste
  Widget _buildListCard(Product product) {
    final quantity = _cart[product.id] ?? 0;
    
    return Card(
      margin: EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            // Image
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildProductImage(product, 30),
              ),
            ),
            SizedBox(width: 12),
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 4),
                  if (product.category != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                      child: Text(product.category!, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    ),
                  SizedBox(height: 4),
                  Text('${product.price.toStringAsFixed(0)} DA', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            // Contrôles
            _buildQuantityControls(product, quantity),
          ],
        ),
      ),
    );
  }

  // Mode Compact
  Widget _buildCompactCard(Product product) {
    final quantity = _cart[product.id] ?? 0;
    
    return Container(
      margin: EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: quantity > 0 ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: quantity > 0 ? Colors.green.shade200 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(product.name, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14), overflow: TextOverflow.ellipsis),
                if (product.category != null) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                    child: Text(product.category!, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8),
          Text('${product.price.toStringAsFixed(0)} DA', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
          SizedBox(width: 12),
          _buildCompactQuantityControls(product, quantity),
        ],
      ),
    );
  }

  Widget _buildProductImage(Product product, double iconSize) {
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return product.imageUrl!.startsWith('data:')
          ? Image.memory(
              base64Decode(product.imageUrl!.split(',').last),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          : Image.network(
              product.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(child: Icon(Icons.fastfood, size: iconSize, color: Colors.grey[400])),
            );
    }
    return Center(child: Icon(Icons.fastfood, size: iconSize, color: Colors.grey[400]));
  }

  Widget _buildQuantityControls(Product product, int quantity) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildQuantityButton(
          icon: Icons.remove,
          color: Colors.red,
          onPressed: quantity > 0 ? () => _updateQuantity(product.id, -1) : null,
        ),
        Container(
          width: 40,
          child: Text('$quantity', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        _buildQuantityButton(
          icon: Icons.add,
          color: Colors.green,
          onPressed: () => _updateQuantity(product.id, 1),
        ),
      ],
    );
  }

  Widget _buildCompactQuantityControls(Product product, int quantity) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: quantity > 0 ? () => _updateQuantity(product.id, -1) : null,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: quantity > 0 ? Colors.red.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.remove, size: 16, color: quantity > 0 ? Colors.red : Colors.grey),
          ),
        ),
        Container(
          width: 32,
          child: Text('$quantity', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ),
        GestureDetector(
          onTap: () => _updateQuantity(product.id, 1),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(6)),
            child: Icon(Icons.add, size: 16, color: Colors.green),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityButton({required IconData icon, required Color color, VoidCallback? onPressed}) {
    return Material(
      color: onPressed != null ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          child: Icon(icon, color: onPressed != null ? color : Colors.grey, size: 20),
        ),
      ),
    );
  }
}
