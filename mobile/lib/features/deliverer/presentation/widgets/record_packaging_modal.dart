import 'package:flutter/material.dart';
import '../../../../core/models/packaging_model.dart';
import '../../../../core/services/api_service.dart';

class RecordPackagingModal extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String? deliveryId;
  final List<PackagingBalance> currentBalance;
  final Function() onSuccess;
  final ApiService? apiService;

  const RecordPackagingModal({
    Key? key,
    required this.customerId,
    required this.customerName,
    this.deliveryId,
    required this.currentBalance,
    required this.onSuccess,
    this.apiService,
  }) : super(key: key);

  @override
  _RecordPackagingModalState createState() => _RecordPackagingModalState();
}

class _RecordPackagingModalState extends State<RecordPackagingModal> {
  late final ApiService _apiService;
  List<PackagingType> _packagingTypes = [];
  String? _selectedTypeId;
  final _quantityController = TextEditingController(text: '1');
  final _noteController = TextEditingController();
  bool _isReturn = true; // Default to return (negative quantity)
  bool _isLoading = false;
  bool _isLoadingTypes = true;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadPackagingTypes();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadPackagingTypes() async {
    try {
      final result = await _apiService.getPackagingTypes();
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _packagingTypes = (result['data'] as List)
              .map((e) => PackagingType.fromJson(e))
              .toList();
          _isLoadingTypes = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingTypes = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sélectionnez un type de consigne'), backgroundColor: Colors.orange),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quantité invalide'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _apiService.recordPackagingDeposit({
        'customerId': widget.customerId,
        'packagingTypeId': _selectedTypeId,
        'quantity': _isReturn ? -quantity : quantity, // Negative for returns
        'deliveryId': widget.deliveryId,
        'note': _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isReturn ? 'Retour enregistré' : 'Consigne donnée enregistrée'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Consignes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close)),
                ],
              ),
              SizedBox(height: 8),
              Text('Client: ${widget.customerName}', style: TextStyle(fontWeight: FontWeight.w500)),
              
              // Current balance summary
              if (widget.currentBalance.isNotEmpty) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Solde actuel:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ...widget.currentBalance.map((b) => Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(b.typeName, style: TextStyle(fontSize: 13)),
                            Text('${b.outstanding}', 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                color: b.outstanding > 0 ? Colors.orange : Colors.green
                              )),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ],
              
              SizedBox(height: 20),
              
              // Return/Give toggle
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isReturn = true),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isReturn ? Colors.green : Colors.grey.shade200,
                          borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
                        ),
                        child: Center(
                          child: Text('Retour ↓', 
                            style: TextStyle(
                              color: _isReturn ? Colors.white : Colors.black54,
                              fontWeight: FontWeight.bold,
                            )),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isReturn = false),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isReturn ? Colors.blue : Colors.grey.shade200,
                          borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                        ),
                        child: Center(
                          child: Text('Donner ↑', 
                            style: TextStyle(
                              color: !_isReturn ? Colors.white : Colors.black54,
                              fontWeight: FontWeight.bold,
                            )),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Packaging type dropdown
              if (_isLoadingTypes)
                Center(child: CircularProgressIndicator())
              else if (_packagingTypes.isEmpty)
                Center(child: Text('Aucun type de consigne configuré', style: TextStyle(color: Colors.grey)))
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedTypeId,
                  decoration: InputDecoration(
                    labelText: 'Type de consigne',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: Icon(Icons.inventory_2),
                  ),
                  items: _packagingTypes.map((type) => DropdownMenuItem(
                    value: type.id,
                    child: Text(type.name),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedTypeId = v),
                ),
              
              SizedBox(height: 16),
              
              // Quantity
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantité',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Note
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Note (optionnel)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
              
              SizedBox(height: 24),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isReturn ? Colors.green : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _isReturn ? 'Enregistrer le retour' : 'Enregistrer la consigne donnée',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
