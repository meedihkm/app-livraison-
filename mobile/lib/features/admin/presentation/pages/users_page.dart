import 'package:flutter/material.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/services/settings_service.dart';
import 'client_detail_page.dart';
import 'deliverer_detail_page.dart';
import 'kitchen_detail_page.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  _UsersPageState createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final ApiService _apiService = ApiService();
  final SettingsService _settingsService = SettingsService();
  List<dynamic> _users = [];
  bool _isLoading = true;
  bool _kitchenModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settingsService.loadSettings();
    setState(() {
      _kitchenModeEnabled = _settingsService.kitchenMode;
    });
  }

  Future<void> _loadUsers() async {
    try {
      final response = await _apiService.getUsers();
      if (response['success']) {
        setState(() {
          _users = response['data'];
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

  Future<void> _showUserDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    var selectedRole = 'customer';
    String? selectedClientType;

    final clientTypes = [
      'Restaurant',
      'Pizzeria',
      'Café',
      'Cafétéria',
      'Épicerie',
      'Superette',
      'Hôtel',
      'Snack',
      'Boulangerie',
      'Pâtisserie',
      'Fast-food',
      'Autre',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Nouvel utilisateur', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Choix du rôle
                      Text('Type de compte', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => selectedRole = 'customer'),
                              child: Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: selectedRole == 'customer' ? Colors.green.shade50 : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: selectedRole == 'customer' ? Colors.green : Colors.grey[300]!, width: 2),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.store,
                                        color: selectedRole == 'customer' ? Colors.green : Colors.grey, size: 32),
                                    SizedBox(height: 8),
                                    Text('Client',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: selectedRole == 'customer' ? Colors.green : Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => selectedRole = 'deliverer'),
                              child: Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: selectedRole == 'deliverer' ? Colors.orange.shade50 : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: selectedRole == 'deliverer' ? Colors.orange : Colors.grey[300]!, width: 2),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.delivery_dining,
                                        color: selectedRole == 'deliverer' ? Colors.orange : Colors.grey, size: 32),
                                    SizedBox(height: 8),
                                    Text('Livreur',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: selectedRole == 'deliverer' ? Colors.orange : Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Option Atelier si kitchen_mode activé
                      if (_kitchenModeEnabled) ...[
                        SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => setModalState(() => selectedRole = 'kitchen'),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedRole == 'kitchen' ? Colors.purple.shade50 : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: selectedRole == 'kitchen' ? Colors.purple : Colors.grey[300]!, width: 2),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.kitchen,
                                    color: selectedRole == 'kitchen' ? Colors.purple : Colors.grey, size: 32),
                                SizedBox(width: 12),
                                Text('Atelier / Cuisine',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: selectedRole == 'kitchen' ? Colors.purple : Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: 20),

                      // Type de client (si client sélectionné)
                      if (selectedRole == 'customer') ...[
                        Text('Type d\'établissement',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: clientTypes
                              .map((type) => GestureDetector(
                                    onTap: () => setModalState(() => selectedClientType = type),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: selectedClientType == type ? Colors.green : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(type,
                                          style: TextStyle(
                                              color: selectedClientType == type ? Colors.white : Colors.grey[700],
                                              fontWeight: FontWeight.w500)),
                                    ),
                                  ))
                              .toList(),
                        ),
                        SizedBox(height: 20),
                      ],

                      // Nom
                      Text('Nom', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: selectedRole == 'customer' ? 'Ex: Pizzeria Bella' : 'Ex: Ahmed',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border:
                              OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          prefixIcon: Icon(selectedRole == 'customer' ? Icons.store : Icons.person),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Email
                      Text('Email', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      SizedBox(height: 8),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'email@exemple.com',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border:
                              OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Mot de passe
                      Text('Mot de passe', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      SizedBox(height: 8),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Min 6 caractères',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border:
                              OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Téléphone
                      Text('Téléphone', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      SizedBox(height: 8),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '0555 00 00 00',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border:
                              OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Adresse (pour clients)
                      if (selectedRole == 'customer') ...[
                        Text('Adresse', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                        SizedBox(height: 8),
                        TextField(
                          controller: addressController,
                          decoration: InputDecoration(
                            hintText: 'Rue, quartier, ville',
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            prefixIcon: Icon(Icons.location_on),
                          ),
                        ),
                      ],
                      SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.isEmpty ||
                            emailController.text.isEmpty ||
                            passwordController.text.isEmpty) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Remplir tous les champs obligatoires')));
                          return;
                        }
                        if (passwordController.text.length < 6) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Mot de passe: min 6 caractères')));
                          return;
                        }

                        var finalName = nameController.text;
                        if (selectedRole == 'customer' && selectedClientType != null) {
                          finalName = '[$selectedClientType] ${nameController.text}';
                        }

                        final data = {
                          'name': finalName,
                          'email': emailController.text,
                          'password': passwordController.text,
                          'phone': phoneController.text,
                          'role': selectedRole,
                        };

                        try {
                          await _apiService.createUser(data);
                          Navigator.pop(context);
                          _loadUsers();
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Utilisateur créé!'), backgroundColor: Colors.green));
                        } catch (e) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedRole == 'customer' ? Colors.green : Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('CRÉER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRoleText(String role) {
    switch (role) {
      case 'customer':
        return 'Client';
      case 'deliverer':
        return 'Livreur';
      case 'admin':
        return 'Admin';
      case 'kitchen':
        return 'Atelier';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'customer':
        return Colors.green;
      case 'deliverer':
        return Colors.orange;
      case 'admin':
        return Colors.blue;
      case 'kitchen':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'customer':
        return Icons.store;
      case 'deliverer':
        return Icons.delivery_dining;
      case 'admin':
        return Icons.admin_panel_settings;
      case 'kitchen':
        return Icons.kitchen;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: _users.length,
          itemBuilder: (context, index) {
            final user = _users[index];
            return Card(
              margin: EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () => _openUserDetail(user),
                leading: CircleAvatar(
                  backgroundColor: _getRoleColor(user['role']),
                  child: Icon(
                    _getRoleIcon(user['role']),
                    color: Colors.white,
                  ),
                ),
                title: Text(user['name']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['email']),
                    Text(_getRoleText(user['role'])),
                    if (user['phone'] != null && user['phone'].isNotEmpty) Text(user['phone']),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: user['active'] ?? true,
                      onChanged: (value) async {
                        try {
                          await _apiService.toggleUser(user['id']);
                          _loadUsers();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: ${e.toString()}')),
                          );
                        }
                      },
                    ),
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: Row(
                            children: const [
                              Icon(Icons.info_outline, size: 20),
                              SizedBox(width: 8),
                              Text('Voir fiche'),
                            ],
                          ),
                          onTap: () => Future.delayed(Duration.zero, () => _openUserDetail(user)),
                        ),
                        PopupMenuItem(
                          child: Row(
                            children: const [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Supprimer', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                          onTap: () => Future.delayed(Duration.zero, () => _confirmDelete(user)),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showUserDialog,
        child: Icon(Icons.add),
      ),
    );
  }

  Future<void> _openUserDetail(Map<String, dynamic> user) async {
    Widget page;
    if (user['role'] == 'deliverer') {
      page = DelivererDetailPage(deliverer: user);
    } else if (user['role'] == 'kitchen') {
      page = KitchenDetailPage(kitchen: user);
    } else {
      page = ClientDetailPage(client: user);
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (result == true) _loadUsers();
  }

  Future<void> _confirmDelete(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer ${user['name']}?'),
        content: Text(
            'Cette action est irréversible. Si l\'utilisateur a des commandes, il sera désactivé au lieu d\'être supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('SUPPRIMER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await _apiService.deleteUser(user['id']);
        _loadUsers();
        final message =
            response['deactivated'] == true ? 'Utilisateur désactivé (commandes existantes)' : 'Utilisateur supprimé';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
