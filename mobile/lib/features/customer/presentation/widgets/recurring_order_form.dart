import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/models/recurring_order_model.dart';
import '../../../../core/models/product_model.dart';

class RecurringOrderForm extends StatefulWidget {
  final RecurringOrder? existingOrder;
  final VoidCallback onSaved;

  const RecurringOrderForm({
    Key? key,
    this.existingOrder,
    required this.onSaved,
  }) : super(key: key);

  @override
  _RecurringOrderFormState createState() => _RecurringOrderFormState();
}

class _RecurringOrderFormState extends State<RecurringOrderForm> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  String _frequency = 'weekly';
  int _dayOfWeek = 1; // Monday
  int _dayOfMonth = 1;
  TimeOfDay _timeOfDay = TimeOfDay(hour: 6, minute: 0);
  
  List<Product> _availableProducts = [];
  List<RecurringOrderItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    
    if (widget.existingOrder != null) {
      final order = widget.existingOrder!;
      _nameController.text = order.name ?? '';
      _frequency = order.frequency;
      _dayOfWeek = order.dayOfWeek ?? 1;
      _dayOfMonth = order.dayOfMonth ?? 1;
      final timeParts = order.timeOfDay.split(':');
      _timeOfDay = TimeOfDay(
        hour: int.tryParse(timeParts[0]) ?? 6,
        minute: int.tryParse(timeParts[1]) ?? 0,
      );
      _items = List.from(order.items);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final result = await _apiService.getProducts();
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _availableProducts = (result['data'] as List)
              .map((e) => Product.fromJson(e))
              .toList();
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingProducts = false);
    }
  }

  void _addProduct() {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedProductId;
        int quantity = 1;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Ajouter un produit'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedProductId,
                    decoration: InputDecoration(
                      labelText: 'Produit',
                      border: OutlineInputBorder(),
                    ),
                    items: _availableProducts
                        .where((p) => !_items.any((i) => i.productId == p.id))
                        .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedProductId = v),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Quantité: '),
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: quantity > 1 ? () => setDialogState(() => quantity--) : null,
                      ),
                      Text('$quantity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () => setDialogState(() => quantity++),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
                ElevatedButton(
                  onPressed: selectedProductId == null ? null : () {
                    final product = _availableProducts.firstWhere((p) => p.id == selectedProductId);
                    setState(() {
                      _items.add(RecurringOrderItem(
                        productId: product.id,
                        productName: product.name,
                        quantity: quantity,
                      ));
                    });
                    Navigator.pop(context);
                  },
                  child: Text('Ajouter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removeProduct(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ajoutez au moins un produit'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'frequency': _frequency,
        'dayOfWeek': _frequency == 'weekly' ? _dayOfWeek : null,
        'dayOfMonth': _frequency == 'monthly' ? _dayOfMonth : null,
        'timeOfDay': '${_timeOfDay.hour.toString().padLeft(2, '0')}:${_timeOfDay.minute.toString().padLeft(2, '0')}:00',
        'items': _items.map((i) => {'productId': i.productId, 'quantity': i.quantity}).toList(),
      };

      if (widget.existingOrder != null) {
        await _apiService.updateRecurringOrder(widget.existingOrder!.id, data);
      } else {
        await _apiService.createRecurringOrder(data);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingOrder != null ? 'Commande modifiée' : 'Commande créée'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onSaved();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existingOrder != null ? 'Modifier la récurrence' : 'Nouvelle récurrence',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close)),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Nom (optionnel)',
                          hintText: 'Ex: Ma commande du lundi',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: Icon(Icons.label),
                        ),
                      ),
                      SizedBox(height: 20),
                      
                      // Frequency
                      Text('Fréquence', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(value: 'daily', label: Text('Quotidien')),
                          ButtonSegment(value: 'weekly', label: Text('Hebdo')),
                          ButtonSegment(value: 'monthly', label: Text('Mensuel')),
                        ],
                        selected: {_frequency},
                        onSelectionChanged: (v) => setState(() => _frequency = v.first),
                      ),
                      SizedBox(height: 20),
                      
                      // Day selector
                      if (_frequency == 'weekly') ...[
                        Text('Jour de la semaine', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (int i = 0; i < 7; i++)
                              ChoiceChip(
                                label: Text(_shortDayName(i)),
                                selected: _dayOfWeek == i,
                                onSelected: (s) => setState(() => _dayOfWeek = i),
                              ),
                          ],
                        ),
                        SizedBox(height: 20),
                      ],
                      
                      if (_frequency == 'monthly') ...[
                        Text('Jour du mois', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: _dayOfMonth,
                          decoration: InputDecoration(border: OutlineInputBorder()),
                          items: List.generate(31, (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('${i + 1}'),
                          )),
                          onChanged: (v) => setState(() => _dayOfMonth = v ?? 1),
                        ),
                        SizedBox(height: 20),
                      ],
                      
                      // Time
                      Text('Heure de génération', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: _timeOfDay);
                          if (picked != null) setState(() => _timeOfDay = picked);
                        },
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time),
                              SizedBox(width: 12),
                              Text('${_timeOfDay.hour.toString().padLeft(2, '0')}:${_timeOfDay.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // Products
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Produits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          TextButton.icon(
                            onPressed: _isLoadingProducts ? null : _addProduct,
                            icon: Icon(Icons.add),
                            label: Text('Ajouter'),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      
                      if (_items.isEmpty)
                        Container(
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text('Aucun produit ajouté', style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      else
                        ...List.generate(_items.length, (index) {
                          final item = _items[index];
                          return Card(
                            child: ListTile(
                              title: Text(item.productName ?? 'Produit'),
                              subtitle: Text('Quantité: ${item.quantity}'),
                              trailing: IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeProduct(index),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              
              // Submit button
              Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(widget.existingOrder != null ? 'Enregistrer' : 'Créer la récurrence',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortDayName(int day) {
    const days = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
    return days[day % 7];
  }
}
