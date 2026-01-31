import 'package:flutter/material.dart';
import '../database/sync_service.dart';

class SyncIndicator extends StatelessWidget {
  final SyncService _syncService = SyncService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _syncService.connectionStatus,
      initialData: _syncService.isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? false;
        
        return StreamBuilder<int>(
          stream: _syncService.pendingActionCount,
          initialData: 0,
          builder: (context, countSnapshot) {
            final count = countSnapshot.data ?? 0;
            
            if (count == 0 && isOnline) {
              return SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Badge(
                  label: Text('$count'),
                  isLabelVisible: count > 0,
                  backgroundColor: isOnline ? Colors.blue : Colors.red,
                  child: IconButton(
                    icon: Icon(
                      isOnline ? Icons.cloud_done : Icons.cloud_off,
                      color: isOnline ? Colors.white : Colors.white70,
                    ),
                    tooltip: isOnline 
                      ? 'Synchronisé ($count en attente)'
                      : 'Hors ligne ($count en attente)',
                    onPressed: () {
                      if (isOnline) {
                        _syncService.syncData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Synchronisation lancée...')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Mode Hors Ligne : $count actions en attente de connexion')),
                        );
                      }
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
