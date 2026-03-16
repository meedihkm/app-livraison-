class ApiConstants {
  // URL configurable via --dart-define=API_URL=...
  // En production: flutter build apk --dart-define=API_URL=https://votre-api.com/api
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://awid.gleeze.com/api',  // Production
  );
  
  // Auth endpoints
  static const String login = '$baseUrl/auth/login';
  static const String me = '$baseUrl/auth/me';
  
  // Products endpoints
  static const String products = '$baseUrl/products';
  
  // Users endpoints
  static const String users = '$baseUrl/users';
  static const String deliverers = '$baseUrl/users/deliverers';
  
  // Orders endpoints
  static const String orders = '$baseUrl/orders';
  static const String myOrders = '$baseUrl/orders/my';
  
  // Deliveries endpoints
  static const String deliveries = '$baseUrl/deliveries';
  static const String deliveryRoute = '$baseUrl/deliveries/route';
  
  // Deliverers/Location endpoints (dans deliveries.routes.js)
  static const String deliverersLocation = '$baseUrl/deliveries/location';
  static const String deliverersLocations = '$baseUrl/deliveries/locations';
  
  // Financial endpoints
  static const String dailyFinancial = '$baseUrl/organization/daily';
  static const String debts = '$baseUrl/financial/debts';
  static const String financialOverview = '$baseUrl/financial/overview';
  static const String financialPayments = '$baseUrl/financial/payments';

  // Audit logs
  static const String auditLogs = '$baseUrl/audit-logs';

  // Favorites endpoints (Phase 2)
  static const String favorites = '$baseUrl/favorites';
  
  // Notifications endpoints (Phase 3)
  static const String notifications = '$baseUrl/notifications';
  
  // Super admin endpoints
  static const String superAdminTest = '$baseUrl/super-admin/test';
  static const String superAdminStats = '$baseUrl/super-admin/stats';
  static const String superAdminOrgs = '$baseUrl/super-admin/organizations';
}