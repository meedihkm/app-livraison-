// Products Page - Admin avec catégories et réorganisation
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/models/product_model.dart';

class ProductsPage extends StatefulWidget {
  @override
  _ProductsPageState createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  List<Product> _products = [];
  List<String> _categories = [];
  bool _isLoading = true;
  String? _selectedCategory;
  bool _isReorderMode = false;

  // Catégories prédéfinies
  final List<String> _defaultCategories = [
    'Boissons',
    'Plats',
    'Desserts',
    'Entrées',
    'Pizzas',
    'Sandwichs',
    'Salades',
    'Accompagnements',
    'Petit-déjeuner',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _apiService.getProducts();
      if (response['success']) {
        // Filtrer uniquement les produits actifs
        final allProducts = (response['data'] as List).map((json) => Product.fromJson(json)).toList();
        final products = allProducts.where((p) => p.active).toList();
        
        // Extraire les catégories uniques
        final cats = products.map((p) => p.category).where((c) => c != null && c.isNotEmpty).toSet().toList();
        setState(() {
          _products = products;
          _categories = cats.cast<String>();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
    }
  }

  List<Product> get _filteredProducts {
    if (_selectedCategory == null) return _products;
    return _products.where((p) => p.category == _selectedCategory).toList();
  }

  Map<String, List<Product>> get _groupedProducts {
    Map<String, List<Product>> grouped = {};
    for (var product in _products) {
      final cat = product.category ?? 'Sans catégorie';
      grouped.putIfAbsent(cat, () => []).add(product);
    }
    return grouped;
  }

  Future<String?> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 20),
            Text('Ajouter une photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageOption(Icons.camera_alt, 'Camera', Colors.blue, () => Navigator.pop(context, ImageSource.camera)),
                _buildImageOption(Icons.photo_library, 'Galerie', Colors.green, () => Navigator.pop(context, ImageSource.gallery)),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
    if (source == null) return null;
    try {
      final XFile? image = await _picker.pickImage(source: source, maxWidth: 300, maxHeight: 300, imageQuality: 70);
      if (image == null) return null;
      final bytes = await image.readAsBytes();
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur photo: ${e.toString()}')));
      return null;
    }
  }

  Widget _buildImageOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color, size: 32)),
          SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _reorderProduct(Product product, String direction) async {
    try {
      await _apiService.reorderProduct(product.id, direction);
      _loadProducts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
    }
  }

  Future<void> _showProductDialog([Product? product]) async {
    final nameController = TextEditingController(text: product?.name ?? '');
    final priceController = TextEditingController(text: product?.price.toStringAsFixed(0) ?? '');
    final promoPriceController = TextEditingController(text: product?.promoPrice?.toStringAsFixed(0) ?? '');
    String? imageUrl = product?.imageUrl;
    String? selectedCategory = product?.category;
    bool isNew = product?.isNew ?? false;
    bool isPromo = product?.isPromo ?? false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              children: [
                Container(margin: EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(product == null ? 'Nouveau produit' : 'Modifier produit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image
                        Center(
                          child: GestureDetector(
                            onTap: () async {
                              final newImage = await _pickImage();
                              if (newImage != null) setModalState(() => imageUrl = newImage);
                            },
                            child: Container(
                              width: 150, height: 150,
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[300]!, width: 2)),
                              child: imageUrl != null && imageUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: imageUrl!.startsWith('data:')
                                          ? Image.memory(base64Decode(imageUrl!.split(',').last), fit: BoxFit.cover, width: 150, height: 150)
                                          : Image.network(imageUrl!, fit: BoxFit.cover, width: 150, height: 150),
                                    )
                                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Icon(Icons.add_a_photo, size: 40, color: Colors.grey[400]),
                                      SizedBox(height: 8),
                                      Text('Ajouter photo', style: TextStyle(color: Colors.grey[500])),
                                    ]),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        
                        // Nom
                        Text('Nom du produit', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                        SizedBox(height: 8),
                        TextField(controller: nameController, decoration: InputDecoration(hintText: 'Ex: Pizza Margherita', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), prefixIcon: Icon(Icons.fastfood))),
                        SizedBox(height: 20),
                        
                        // Prix
                        Text('Prix (DA)', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                        SizedBox(height: 8),
                        TextField(controller: priceController, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'Ex: 500', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), prefixIcon: Icon(Icons.attach_money), suffixText: 'DA')),
                        SizedBox(height: 20),
                        
                        // Labels Nouveau / Promo
                        Text('Labels', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => isNew = !isNew),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isNew ? Colors.green : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isNew ? Colors.green : Colors.grey[300]!),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(isNew ? Icons.check_circle : Icons.fiber_new, color: isNew ? Colors.white : Colors.grey[600], size: 20),
                                      SizedBox(width: 8),
                                      Text('Nouveau', style: TextStyle(color: isNew ? Colors.white : Colors.grey[600], fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => isPromo = !isPromo),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isPromo ? Colors.red : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isPromo ? Colors.red : Colors.grey[300]!),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(isPromo ? Icons.check_circle : Icons.local_offer, color: isPromo ? Colors.white : Colors.grey[600], size: 20),
                                      SizedBox(width: 8),
                                      Text('Promo', style: TextStyle(color: isPromo ? Colors.white : Colors.grey[600], fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // Prix promo (visible si isPromo)
                        if (isPromo) ...[
                          SizedBox(height: 16),
                          Text('Prix promo (DA)', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red[700])),
                          SizedBox(height: 8),
                          TextField(controller: promoPriceController, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'Ex: 400', filled: true, fillColor: Colors.red[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), prefixIcon: Icon(Icons.local_offer, color: Colors.red), suffixText: 'DA')),
                        ],
                        SizedBox(height: 20),
                        
                        // Catégorie
                        Text('Catégorie', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ..._defaultCategories.map((cat) => GestureDetector(
                              onTap: () => setModalState(() => selectedCategory = cat),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selectedCategory == cat ? Colors.blue : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(cat, style: TextStyle(color: selectedCategory == cat ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w500)),
                              ),
                            )),
                            // Catégories personnalisées existantes
                            ..._categories.where((c) => !_defaultCategories.contains(c)).map((cat) => GestureDetector(
                              onTap: () => setModalState(() => selectedCategory = cat),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selectedCategory == cat ? Colors.blue : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(cat, style: TextStyle(color: selectedCategory == cat ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w500)),
                              ),
                            )),
                          ],
                        ),
                        SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
                _buildSaveButton(nameController, priceController, promoPriceController, imageUrl, selectedCategory, isNew, isPromo, product),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(TextEditingController nameController, TextEditingController priceController, TextEditingController promoPriceController, String? imageUrl, String? category, bool isNew, bool isPromo, Product? product) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || priceController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Remplir tous les champs')));
                return;
              }
              final data = {
                'name': nameController.text, 
                'price': double.tryParse(priceController.text) ?? 0, 
                'imageUrl': imageUrl,
                'category': category,
                'isNew': isNew,
                'isPromo': isPromo,
                'promoPrice': isPromo ? (double.tryParse(promoPriceController.text)) : null,
              };
              try {
                if (product == null) await _apiService.createProduct(data);
                else await _apiService.updateProduct(product.id, data);
                Navigator.pop(context);
                _loadProducts();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Produit sauvegardé!'), backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: Text('SAUVEGARDER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: Colors.blue));
    if (_products.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
        SizedBox(height: 16),
        Text('Aucun produit', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
        SizedBox(height: 24),
        ElevatedButton.icon(onPressed: () => _showProductDialog(), icon: Icon(Icons.add), label: Text('Ajouter un produit')),
      ]));
    }
    
    return Scaffold(
      body: Column(
        children: [
          // Barre de filtres et mode réorganisation
          Container(
            padding: EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Filtres catégories
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip('Tous', null),
                      SizedBox(width: 8),
                      ..._groupedProducts.keys.map((cat) => Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: _buildCategoryChip(cat, cat),
                      )),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                // Bouton mode réorganisation
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isReorderMode = !_isReorderMode),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isReorderMode ? Colors.orange : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_isReorderMode ? Icons.check : Icons.swap_vert, color: _isReorderMode ? Colors.white : Colors.orange, size: 20),
                              SizedBox(width: 8),
                              Text(
                                _isReorderMode ? 'Terminer' : 'Réorganiser',
                                style: TextStyle(color: _isReorderMode ? Colors.white : Colors.orange, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Liste des produits
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadProducts,
              child: _isReorderMode ? _buildReorderList() : _buildProductGrid(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(), 
        icon: Icon(Icons.add), 
        label: Text('Produit'), 
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? value) {
    final isSelected = _selectedCategory == value;
    final count = value == null ? _products.length : _products.where((p) => p.category == value).length;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.blue, fontWeight: FontWeight.w500)),
            SizedBox(width: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: TextStyle(color: isSelected ? Colors.white : Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReorderList() {
    final products = _filteredProducts;
    return ListView.builder(
      padding: EdgeInsets.all(12),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isFirst = index == 0;
        final isLast = index == products.length - 1;
        
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: product.imageUrl!.startsWith('data:')
                          ? Image.memory(base64Decode(product.imageUrl!.split(',').last), fit: BoxFit.cover)
                          : Image.network(product.imageUrl!, fit: BoxFit.cover),
                    )
                  : Icon(Icons.fastfood, color: Colors.grey[400]),
            ),
            title: Text(product.name, style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Row(
              children: [
                Text('${product.price.toStringAsFixed(0)} DA', style: TextStyle(color: Colors.blue)),
                if (product.category != null) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                    child: Text(product.category!, style: TextStyle(fontSize: 10)),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_upward, color: isFirst ? Colors.grey[300] : Colors.orange),
                  onPressed: isFirst ? null : () => _reorderProduct(product, 'up'),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_downward, color: isLast ? Colors.grey[300] : Colors.orange),
                  onPressed: isLast ? null : () => _reorderProduct(product, 'down'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductGrid() {
    return GridView.builder(
      padding: EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) => _buildProductCard(_filteredProducts[index]),
    );
  }

  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () => _showProductDialog(product),
      child: Card(
        elevation: 2, 
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(flex: 3, child: Stack(children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50], 
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
              ),
              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                  ? ClipRRect(borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      child: product.imageUrl!.startsWith('data:')
                          ? Image.memory(base64Decode(product.imageUrl!.split(',').last), fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                          : Image.network(product.imageUrl!, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => Center(child: Icon(Icons.fastfood, size: 50, color: Colors.grey[300]))))
                  : Center(child: Icon(Icons.fastfood, size: 50, color: Colors.grey[300])),
            ),
            // Badge statut - Plus visible
            Positioned(top: 10, right: 10, child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
              decoration: BoxDecoration(
                color: product.active ? Colors.green : Colors.grey[600], 
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
              ), 
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(product.active ? Icons.check_circle : Icons.block, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(product.active ? 'Actif' : 'Inactif', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            )),
            // Badge catégorie - Design amélioré
            if (product.category != null)
              Positioned(top: 10, left: 10, child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.95), 
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                ), 
                child: Text(product.category!, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              )),
            // Badges Nouveau / Promo - Plus visibles
            Positioned(
              bottom: 10,
              left: 10,
              child: Row(
                children: [
                  if (product.isNew)
                    Container(
                      margin: EdgeInsets.only(right: 6),
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[600], 
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fiber_new, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Nouveau', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  if (product.isPromo)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red[600], 
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_offer, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Promo', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ])),
          Expanded(flex: 2, child: Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                Text(product.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                _buildProductActions(product),
              ],
            ),
          )),
        ]),
      ),
    );
  }

  Widget _buildProductActions(Product product) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      // Prix avec promo - Taille augmentée
      product.isPromo && product.promoPrice != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${product.price.toStringAsFixed(0)} DA', style: TextStyle(color: Colors.grey, fontSize: 13, decoration: TextDecoration.lineThrough)),
                Text('${product.promoPrice!.toStringAsFixed(0)} DA', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            )
          : Text('${product.price.toStringAsFixed(0)} DA', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 20)),
      Row(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(onTap: () async { await _apiService.toggleProduct(product.id); _loadProducts(); }, child: Icon(product.active ? Icons.visibility : Icons.visibility_off, color: product.active ? Colors.green : Colors.grey, size: 22)),
        SizedBox(width: 8),
        GestureDetector(onTap: () async {
          final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
            title: Text('Supprimer ce produit?'), 
            content: Text('Le produit "${product.name}" sera supprimé définitivement.\n\nSi le produit est utilisé dans des commandes, il sera archivé au lieu d\'être supprimé.'), 
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler')), 
              TextButton(
                onPressed: () => Navigator.pop(context, true), 
                child: Text('Supprimer', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
              )
            ]
          ));
          if (confirm == true) { 
            try {
              final result = await _apiService.deleteProduct(product.id);
              _loadProducts();
              
              // Afficher le message approprié
              final message = result['archived'] == true 
                ? 'Produit archivé (utilisé dans des commandes)'
                : 'Produit supprimé';
              final color = result['archived'] == true ? Colors.orange : Colors.green;
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message), backgroundColor: color)
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red)
              );
            }
          }
        }, child: Icon(Icons.delete_outline, color: Colors.red, size: 22)),
      ]),
    ]);
  }
}
