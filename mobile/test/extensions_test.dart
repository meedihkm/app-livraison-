// =====================================================
// TESTS: Extensions et Modèles Financiers
// =====================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/extensions/number_extensions.dart';
import 'package:mobile/core/models/financial_models.dart';

void main() {
  group('DynamicNumberParsing', () {
    test('toDoubleOrZero handles null', () {
      expect(null.toDoubleOrZero(), 0.0);
    });

    test('toDoubleOrZero handles double', () {
      expect(3.14.toDoubleOrZero(), 3.14);
    });

    test('toDoubleOrZero handles int', () {
      expect(42.toDoubleOrZero(), 42.0);
    });

    test('toDoubleOrZero handles valid string', () {
      expect('3.14'.toDoubleOrZero(), 3.14);
    });

    test('toDoubleOrZero handles invalid string', () {
      expect('invalid'.toDoubleOrZero(), 0.0);
    });

    test('toIntOrZero handles null', () {
      expect(null.toIntOrZero(), 0);
    });

    test('toIntOrZero handles double', () {
      expect(3.9.toIntOrZero(), 3);
    });

    test('toIntOrZero handles valid string', () {
      expect('42'.toIntOrZero(), 42);
    });

    test('toBool handles various inputs', () {
      expect(null.toBool(), false);
      expect(true.toBool(), true);
      expect(1.toBool(), true);
      expect(0.toBool(), false);
      expect('true'.toBool(), true);
      expect('false'.toBool(), false);
      expect('yes'.toBool(), true);
    });
  });

  group('JsonParsing', () {
    test('getDouble extracts double from JSON', () {
      final json = {'amount': 100.50, 'nullValue': null};
      expect(json.getDouble('amount'), 100.50);
      expect(json.getDouble('nullValue'), 0.0);
      expect(json.getDouble('missing'), 0.0);
    });

    test('getInt extracts int from JSON', () {
      final json = {'count': 42, 'nullValue': null};
      expect(json.getInt('count'), 42);
      expect(json.getInt('nullValue'), 0);
      expect(json.getInt('missing'), 0);
    });

    test('getString extracts string from JSON', () {
      final json = {'name': 'Test', 'nullValue': null};
      expect(json.getString('name'), 'Test');
      expect(json.getString('nullValue'), '');
      expect(json.getString('missing', defaultValue: 'Default'), 'Default');
    });

    test('getBool extracts bool from JSON', () {
      final json = {'active': true, 'nullValue': null};
      expect(json.getBool('active'), true);
      expect(json.getBool('nullValue'), false);
      expect(json.getBool('missing'), false);
    });
  });

  group('NumberFormatting', () {
    test('toCurrency formats correctly', () {
      expect(1500.0.toCurrency(), '1500 DA');
      expect(1500.5.toCurrency(decimals: 2), '1500.50 DA');
    });

    test('toPercent formats correctly', () {
      expect(0.85.toPercent(), '85.0%');
      expect(0.856.toPercent(decimals: 2), '85.60%');
    });

    test('formatSmart handles integers', () {
      expect(1500.0.formatSmart(), '1500');
      expect(1500.5.formatSmart(), '1500.50');
    });
  });

  group('FinancialCalculations', () {
    test('sumOf calculates sum correctly', () {
      final list = [
        {'amount': 100.0},
        {'amount': 200.0},
        {'amount': 50.0},
      ];
      expect(list.sumOf('amount'), 350.0);
    });

    test('averageOf calculates average correctly', () {
      final list = [
        {'value': 10.0},
        {'value': 20.0},
        {'value': 30.0},
      ];
      expect(list.averageOf('value'), 20.0);
    });

    test('averageOf handles empty list', () {
      final list = <Map<String, dynamic>>[];
      expect(list.averageOf('value'), 0.0);
    });
  });

  group('FinancialModels', () {
    test('FinancialSummary calculates collectionRate', () {
      final summary = FinancialSummary(
        totalRevenue: 1000,
        totalCollected: 750,
      );
      expect(summary.collectionRate, 0.75);
    });

    test('CustomerDebt hasDebt returns correct value', () {
      final debt1 = CustomerDebt(
        customerId: '1',
        name: 'Test',
        totalDebt: 100,
      );
      expect(debt1.hasDebt, true);

      final debt2 = CustomerDebt(
        customerId: '2',
        name: 'Test 2',
        totalDebt: 0,
      );
      expect(debt2.hasDebt, false);
    });

    test('CreditInfo isCritical works correctly', () {
      final critical = CreditInfo(
        limit: 1000,
        used: 1200,
        status: CreditStatus.critical,
      );
      expect(critical.isCritical, true);
      expect(critical.isOverLimit, false);

      final overLimit = CreditInfo(
        limit: 1000,
        used: 1100,
        status: CreditStatus.overLimit,
      );
      expect(overLimit.isOverLimit, true);
    });

    test('UnpaidOrder progress calculates correctly', () {
      final order = UnpaidOrder(
        id: '1',
        total: 1000,
        amountPaid: 400,
        remaining: 600,
      );
      expect(order.progress, 0.4);
      expect(order.isFullyPaid, false);

      final paidOrder = UnpaidOrder(
        id: '2',
        total: 1000,
        amountPaid: 1000,
        remaining: 0,
      );
      expect(paidOrder.isFullyPaid, true);
    });

    test('PaginationInfo calculates pages correctly', () {
      final pagination = PaginationInfo(
        page: 2,
        limit: 10,
        total: 25,
        totalPages: 3,
      );
      expect(pagination.hasNextPage, true);
      expect(pagination.hasPreviousPage, true);
      expect(pagination.nextPage, 3);
      expect(pagination.previousPage, 1);
    });

    test('DelivererStat successRate calculates correctly', () {
      final stat = DelivererStat(
        id: '1',
        name: 'Test',
        totalDeliveries: 100,
        deliveredCount: 85,
      );
      expect(stat.successRate, 0.85);
    });
  });

  group('FinancialHelpers', () {
    test('calculateCreditStatus returns correct status', () {
      // No limit
      expect(
        FinancialHelpers.calculateCreditStatus(500, 0),
        CreditStatus.noLimit,
      );

      // OK
      expect(
        FinancialHelpers.calculateCreditStatus(500, 1000),
        CreditStatus.ok,
      );

      // Approaching
      expect(
        FinancialHelpers.calculateCreditStatus(850, 1000),
        CreditStatus.approaching,
      );

      // Over limit
      expect(
        FinancialHelpers.calculateCreditStatus(1050, 1000),
        CreditStatus.overLimit,
      );

      // Critical
      expect(
        FinancialHelpers.calculateCreditStatus(1250, 1000),
        CreditStatus.critical,
      );
    });

    test('formatCurrency formats correctly', () {
      expect(FinancialHelpers.formatCurrency(1500), '1500 DA');
      expect(FinancialHelpers.formatCurrency(1500.5, decimals: 2), '1500.50 DA');
    });
  });
}
