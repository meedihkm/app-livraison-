// =====================================================
// EXPORT: Finance Module
// Exporte tous les composants du module finance
// =====================================================

// Models (depuis core) - utilise uniquement financial_models.dart
export '../../core/models/financial_models.dart';

// Services (depuis core)
export '../../core/services/financial_service_v2.dart';
export '../../core/utils/print_utils.dart';

// Widgets
export 'presentation/widgets/debt_payment_dialog.dart';
export 'presentation/widgets/finance_filters.dart';
export 'presentation/widgets/finance_summary_cards.dart';

// Pages
export 'presentation/pages/finance_dashboard_page.dart';
export 'presentation/pages/statistics_page.dart';
