import 'package:flutter/material.dart';
import '../../../../core/services/favorite_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/models/favorite_order_model.dart';
import '../../../../core/models/notification_model.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FavoriteService _favoriteService = FavoriteService();
  final NotificationService _notificationService = NotificationService();
  UserPreferences? _preferences;
  NotificationPreferences? _notificationPreferences;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadNotificationPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    try {
      final response = await _favoriteService.getPreferences();
      if (response['success']) {
        setState(() {
          _preferences = UserPreferences.fromJson(response['data']);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _preferences = UserPreferences(
          favoriteOrdersEnabled: true,
          autoSuggestEnabled: true,
          minPatternCount: 3,
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final response = await _notificationService.getPreferences();
      if (response['success']) {
        setState(() {
          _notificationPreferences = NotificationPreferences.fromJson(response['data']);
        });
      }
    } catch (e) {
      setState(() {
        _notificationPreferences = NotificationPreferences(
          paymentNotifications: true,
          debtNotifications: true,
          favoriteNotifications: true,
          debtRemindersEnabled: false,
          debtReminderFrequency: 7,
        );
      });
    }
  }

  Future<void> _savePreferences() async {
    if (_preferences == null || _notificationPreferences == null) return;
    
    setState(() => _isSaving = true);
    try {
      // Sauvegarder préférences favoris
      await _favoriteService.updatePreferences(
        favoriteOrdersEnabled: _preferences!.favoriteOrdersEnabled,
        autoSuggestEnabled: _preferences!.autoSuggestEnabled,
        minPatternCount: _preferences!.minPatternCount,
      );
      
      // Sauvegarder préférences notifications
      await _notificationService.updatePreferences(
        paymentNotifications: _notificationPreferences!.paymentNotifications,
        debtNotifications: _notificationPreferences!.debtNotifications,
        favoriteNotifications: _notificationPreferences!.favoriteNotifications,
        debtRemindersEnabled: _notificationPreferences!.debtRemindersEnabled,
        debtReminderFrequency: _notificationPreferences!.debtReminderFrequency,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Préférences sauvegardées'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Paramètres'),
          backgroundColor: Colors.green.shade700,
        ),
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Paramètres'),
        backgroundColor: Colors.green.shade700,
        actions: [
          if (_isSaving)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _savePreferences,
              icon: Icon(Icons.save),
              tooltip: 'Sauvegarder',
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Section Commandes Favorites
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Commandes Favorites',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  // Activer/Désactiver favoris
                  SwitchListTile(
                    value: _preferences?.favoriteOrdersEnabled ?? true,
                    onChanged: (value) {
                      setState(() {
                        _preferences = UserPreferences(
                          favoriteOrdersEnabled: value,
                          autoSuggestEnabled: _preferences!.autoSuggestEnabled,
                          minPatternCount: _preferences!.minPatternCount,
                        );
                      });
                    },
                    title: Text('Activer les favoris'),
                    subtitle: Text('Permet de sauvegarder vos commandes habituelles'),
                    activeTrackColor: Colors.green,
                    contentPadding: EdgeInsets.zero,
                  ),
                  
                  Divider(),
                  
                  // Suggestions automatiques
                  SwitchListTile(
                    value: _preferences?.autoSuggestEnabled ?? true,
                    onChanged: (_preferences?.favoriteOrdersEnabled ?? true)
                        ? (value) {
                            setState(() {
                              _preferences = UserPreferences(
                                favoriteOrdersEnabled: _preferences!.favoriteOrdersEnabled,
                                autoSuggestEnabled: value,
                                minPatternCount: _preferences!.minPatternCount,
                              );
                            });
                          }
                        : null,
                    title: Text('Suggestions automatiques'),
                    subtitle: Text('Suggère de sauvegarder les commandes répétées'),
                    activeTrackColor: Colors.green,
                    contentPadding: EdgeInsets.zero,
                  ),
                  
                  if (_preferences?.autoSuggestEnabled == true) ...[
                    SizedBox(height: 16),
                    Text(
                      'Nombre de répétitions avant suggestion',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: (_preferences?.minPatternCount ?? 3).toDouble(),
                            min: 2,
                            max: 10,
                            divisions: 8,
                            label: '${_preferences?.minPatternCount ?? 3}',
                            activeColor: Colors.green,
                            onChanged: (value) {
                              setState(() {
                                _preferences = UserPreferences(
                                  favoriteOrdersEnabled: _preferences!.favoriteOrdersEnabled,
                                  autoSuggestEnabled: _preferences!.autoSuggestEnabled,
                                  minPatternCount: value.toInt(),
                                );
                              });
                            },
                          ),
                        ),
                        Container(
                          width: 40,
                          child: Text(
                            '${_preferences?.minPatternCount ?? 3}x',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Le système suggérera de sauvegarder après ${_preferences?.minPatternCount ?? 3} commandes identiques',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Section Notifications
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications, color: Colors.blue, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  // Notifications paiements
                  SwitchListTile(
                    value: _notificationPreferences?.paymentNotifications ?? true,
                    onChanged: (value) {
                      setState(() {
                        _notificationPreferences = NotificationPreferences(
                          paymentNotifications: value,
                          debtNotifications: _notificationPreferences!.debtNotifications,
                          favoriteNotifications: _notificationPreferences!.favoriteNotifications,
                          debtRemindersEnabled: _notificationPreferences!.debtRemindersEnabled,
                          debtReminderFrequency: _notificationPreferences!.debtReminderFrequency,
                        );
                      });
                    },
                    title: Text('Paiements'),
                    subtitle: Text('Notifications lors des paiements'),
                    activeTrackColor: Colors.green,
                    contentPadding: EdgeInsets.zero,
                  ),
                  
                  Divider(),
                  
                  // Notifications dettes
                  SwitchListTile(
                    value: _notificationPreferences?.debtNotifications ?? true,
                    onChanged: (value) {
                      setState(() {
                        _notificationPreferences = NotificationPreferences(
                          paymentNotifications: _notificationPreferences!.paymentNotifications,
                          debtNotifications: value,
                          favoriteNotifications: _notificationPreferences!.favoriteNotifications,
                          debtRemindersEnabled: _notificationPreferences!.debtRemindersEnabled,
                          debtReminderFrequency: _notificationPreferences!.debtReminderFrequency,
                        );
                      });
                    },
                    title: Text('Dettes'),
                    subtitle: Text('Notifications dette soldée'),
                    activeTrackColor: Colors.green,
                    contentPadding: EdgeInsets.zero,
                  ),
                  
                  Divider(),
                  
                  // Notifications favoris
                  SwitchListTile(
                    value: _notificationPreferences?.favoriteNotifications ?? true,
                    onChanged: (value) {
                      setState(() {
                        _notificationPreferences = NotificationPreferences(
                          paymentNotifications: _notificationPreferences!.paymentNotifications,
                          debtNotifications: _notificationPreferences!.debtNotifications,
                          favoriteNotifications: value,
                          debtRemindersEnabled: _notificationPreferences!.debtRemindersEnabled,
                          debtReminderFrequency: _notificationPreferences!.debtReminderFrequency,
                        );
                      });
                    },
                    title: Text('Suggestions favoris'),
                    subtitle: Text('Notifications commande habituelle'),
                    activeTrackColor: Colors.green,
                    contentPadding: EdgeInsets.zero,
                  ),
                  
                  Divider(),
                  
                  // Rappels dette
                  SwitchListTile(
                    value: _notificationPreferences?.debtRemindersEnabled ?? false,
                    onChanged: (value) {
                      setState(() {
                        _notificationPreferences = NotificationPreferences(
                          paymentNotifications: _notificationPreferences!.paymentNotifications,
                          debtNotifications: _notificationPreferences!.debtNotifications,
                          favoriteNotifications: _notificationPreferences!.favoriteNotifications,
                          debtRemindersEnabled: value,
                          debtReminderFrequency: _notificationPreferences!.debtReminderFrequency,
                        );
                      });
                    },
                    title: Text('Rappels de dette'),
                    subtitle: Text('Recevoir des rappels périodiques'),
                    activeTrackColor: Colors.green,
                    contentPadding: EdgeInsets.zero,
                  ),
                  
                  if (_notificationPreferences?.debtRemindersEnabled == true) ...[
                    SizedBox(height: 16),
                    Text(
                      'Fréquence des rappels',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: (_notificationPreferences?.debtReminderFrequency ?? 7).toDouble(),
                            min: 1,
                            max: 30,
                            divisions: 29,
                            label: '${_notificationPreferences?.debtReminderFrequency ?? 7}',
                            activeColor: Colors.green,
                            onChanged: (value) {
                              setState(() {
                                _notificationPreferences = NotificationPreferences(
                                  paymentNotifications: _notificationPreferences!.paymentNotifications,
                                  debtNotifications: _notificationPreferences!.debtNotifications,
                                  favoriteNotifications: _notificationPreferences!.favoriteNotifications,
                                  debtRemindersEnabled: _notificationPreferences!.debtRemindersEnabled,
                                  debtReminderFrequency: value.toInt(),
                                );
                              });
                            },
                          ),
                        ),
                        Container(
                          width: 60,
                          child: Text(
                            '${_notificationPreferences?.debtReminderFrequency ?? 7}j',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Rappel tous les ${_notificationPreferences?.debtReminderFrequency ?? 7} jours',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Info
          Card(
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Les favoris vous permettent de commander plus rapidement vos articles habituels en un seul clic.',
                      style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
