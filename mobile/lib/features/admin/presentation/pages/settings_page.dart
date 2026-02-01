import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/providers/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settings = SettingsService();
  final _debtAlertController = TextEditingController();
  final _debtBlockController = TextEditingController();
  final _tvaController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settings.loadSettings();
    setState(() {
      _debtAlertController.text = _settings.debtAlertThreshold.toStringAsFixed(0);
      _debtBlockController.text = _settings.debtBlockThreshold.toStringAsFixed(0);
      _tvaController.text = _settings.tvaRate.toStringAsFixed(0);
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _debtAlertController.dispose();
    _debtBlockController.dispose();
    _tvaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Paramètres'),
        backgroundColor: Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Mode Atelier
            _buildSectionHeader('Mode Atelier', Icons.kitchen, Colors.purple),
            SizedBox(height: 12),
            _buildSettingCard([
              _buildSwitchField(
                label: 'Activer le mode Atelier',
                subtitle: 'Ajoute un workflow de préparation avec un terminal dédié pour l\'atelier',
                value: _settings.kitchenMode,
                onChanged: (v) async {
                  final success = await _settings.setKitchenMode(value: v);
                  if (success) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(v ? 'Mode Atelier activé' : 'Mode Atelier désactivé'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur lors de la mise à jour'), backgroundColor: Colors.red),
                    );
                  }
                },
              ),
              if (_settings.kitchenMode) ...[
                Divider(height: 24),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Workflow avec Atelier:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                      SizedBox(height: 8),
                      _buildWorkflowStep('1', 'Client commande', 'pending'),
                      _buildWorkflowStep('2', 'Admin valide', 'validated'),
                      _buildWorkflowStep('3', 'Atelier prépare', 'preparing'),
                      _buildWorkflowStep('4', 'Atelier termine', 'ready'),
                      _buildWorkflowStep('5', 'Admin assigne livreur', 'in_delivery'),
                      _buildWorkflowStep('6', 'Livreur livre', 'delivered'),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Créez un compte "Atelier" dans les utilisateurs pour accéder au terminal de préparation.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ]),

            SizedBox(height: 24),

            SizedBox(height: 24),

            // Section Apparence
            _buildSectionHeader('Apparence', Icons.palette, Colors.blue),
            SizedBox(height: 12),
            _buildSettingCard([
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text('Thème de l\'application', style: TextStyle(fontWeight: FontWeight.w600)),
                       SizedBox(height: 8),
                       SegmentedButton<ThemeMode>(
                         segments: [
                           ButtonSegment(value: ThemeMode.light, label: Text('Clair'), icon: Icon(Icons.light_mode)),
                           ButtonSegment(value: ThemeMode.dark, label: Text('Sombre'), icon: Icon(Icons.dark_mode)),
                           ButtonSegment(value: ThemeMode.system, label: Text('Système'), icon: Icon(Icons.brightness_auto)),
                         ],
                         selected: {themeProvider.themeMode},
                         onSelectionChanged: (Set<ThemeMode> newSelection) {
                           final mode = newSelection.first;
                           if (mode == ThemeMode.system) {
                             themeProvider.setSystemTheme();
                           } else {
                             themeProvider.toggleTheme(isDark: mode == ThemeMode.dark);
                           }
                         },
                       ),
                     ],
                  );
                },
              ),
            ]),

            SizedBox(height: 24),

            // Section Dettes
            _buildSectionHeader('Gestion des dettes', Icons.warning_amber, Colors.orange),
            SizedBox(height: 12),
            _buildSettingCard([
              _buildNumberField(
                label: 'Seuil d\'alerte dette (DA)',
                hint: 'Alerte si dette dépasse ce montant',
                controller: _debtAlertController,
                onSave: _settings.setDebtAlertThreshold,
              ),
              Divider(height: 24),
              _buildNumberField(
                label: 'Seuil de blocage dette (DA)',
                hint: 'Bloquer client si dette dépasse ce montant',
                controller: _debtBlockController,
                onSave: _settings.setDebtBlockThreshold,
              ),
              Divider(height: 24),
              _buildSwitchField(
                label: 'Blocage automatique',
                subtitle: 'Bloquer automatiquement les clients dépassant le seuil',
                value: _settings.autoBlockOnDebt,
                onChanged: (v) {
                  _settings.setAutoBlockOnDebt(value: v);
                  setState(() {});
                },
              ),
            ]),

            SizedBox(height: 24),

            // Section Facturation
            _buildSectionHeader('Facturation', Icons.receipt, Colors.green),
            SizedBox(height: 12),
            _buildSettingCard([
              _buildNumberField(
                label: 'Taux TVA (%)',
                hint: 'Taux de TVA pour les factures',
                controller: _tvaController,
                onSave: _settings.setTvaRate,
              ),
            ]),

            SizedBox(height: 24),

            // Info
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Les paramètres locaux sont sauvegardés sur cet appareil. Le mode Atelier est synchronisé avec le serveur.',
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowStep(String num, String label, String status) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.purple,
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(num, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          ),
          SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
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

  Widget _buildSettingCard(List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildNumberField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required ValueChanged<double> onSave,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: 4),
        Text(hint, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                final value = double.tryParse(controller.text) ?? 0;
                onSave(value);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sauvegardé'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('OK'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSwitchField({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
              Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          // ignore: deprecated_member_use
          activeColor: Colors.blue,
        ),
      ],
    );
  }
}
