import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/hive_service.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/notification_service.dart';
import 'core/services/sentry_service.dart';
import 'core/storage/secure_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/presentation/pages/admin_dashboard.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/customer/presentation/pages/customer_dashboard.dart';
import 'features/deliverer/presentation/pages/deliverer_dashboard.dart';
import 'features/kitchen/presentation/pages/kitchen_dashboard.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show errors on screen instead of grey/white screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                SizedBox(height: 16),
                Text('Une erreur est survenue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(details.exception.toString(), textAlign: TextAlign.center, style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
      ),
    );
  };

  // Initialisation Hive
  await HiveService().init();

  // Initialisation OneSignal
  await NotificationService().init();

  // Check Onboarding status
  final prefs = await SharedPreferences.getInstance();
  final bool showOnboarding = !(prefs.getBool('onboarding_complete') ?? false);

  // Initialisation de Sentry qui va wrapper l'application
  await SentryService.init(() async {
    runApp(MyApp(showOnboarding: showOnboarding));
  });
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final bool showOnboarding;

  MyApp({Key? key, required this.showOnboarding}) : super(key: key) {
    NotificationService().setNotificationHandler(navigatorKey);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Awid',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: showOnboarding ? OnboardingPage() : AuthWrapper(),
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final SecureStorage _storage = SecureStorage();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = await _storage.isLoggedIn();

    if (isLoggedIn) {
      final user = await _storage.getUser();
      if (user != null) {
        authProvider.setUser(user);
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isAuthenticated) {
          return LoginPage();
        }

        switch (authProvider.user!['role']) {
          case 'admin':
            return AdminDashboard();
          case 'customer':
            return CustomerDashboard();
          case 'deliverer':
            return DelivererDashboard();
          case 'kitchen':
            return KitchenDashboard();
          default:
            return LoginPage();
        }
      },
    );
  }
}
