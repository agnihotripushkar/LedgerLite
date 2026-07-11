import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledger_lite/data/database/app_database.dart';
import 'package:ledger_lite/blocs/auth/auth_bloc.dart';
import 'package:ledger_lite/blocs/transaction/transaction_bloc.dart';
import 'package:ledger_lite/blocs/analytics/analytics_bloc.dart';

import 'package:mocktail/mocktail.dart';
import 'package:local_auth/local_auth.dart';

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthBloc Tests', () {
    late MockLocalAuthentication mockLocalAuth;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockLocalAuth = MockLocalAuthentication();
      when(() => mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
      when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
    });

    blocTest<AuthBloc, AuthState>(
      'emits AuthConfigured when app lock toggled',
      build: () => AuthBloc(localAuth: mockLocalAuth),
      act: (bloc) => bloc.add(ToggleAppLock(true)),
      expect: () => [
        predicate<AuthConfigured>((state) => state.isLockEnabled == true && state.hasBiometrics == true),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits AuthUnlocked initially if lock is disabled',
      build: () => AuthBloc(localAuth: mockLocalAuth),
      act: (bloc) => bloc.add(CheckAuthStatus()),
      expect: () => [
        isA<AuthUnlocked>(),
      ],
    );
  });

  group('TransactionBloc & AnalyticsBloc Tests', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    blocTest<TransactionBloc, TransactionState>(
      'emits TransactionLoading and TransactionLoaded when loading transactions',
      build: () => TransactionBloc(database),
      act: (bloc) => bloc.add(LoadTransactions()),
      expect: () => [
        isA<TransactionLoading>(),
        isA<TransactionLoaded>(),
      ],
    );

    blocTest<AnalyticsBloc, AnalyticsState>(
      'emits AnalyticsLoading and AnalyticsLoaded with zero totals initially',
      build: () => AnalyticsBloc(database),
      act: (bloc) => bloc.add(LoadAnalyticsData(filterType: 'month')),
      expect: () => [
        isA<AnalyticsLoading>(),
        predicate<AnalyticsLoaded>((state) =>
            state.totalIncome == 0 &&
            state.totalExpense == 0 &&
            state.totalBalance == 0 &&
            state.categoryExpenses.isEmpty),
      ],
    );

    blocTest<AnalyticsBloc, AnalyticsState>(
      'still includes a 3-month-old transaction in the monthly trend when filter is week',
      build: () => AnalyticsBloc(database),
      setUp: () async {
        final categories = await database.getAllCategories();
        final salary = categories.firstWhere((c) => c.name == 'Salary');
        final now = DateTime.now();
        final threeMonthsAgo = DateTime(now.year, now.month - 3, 15);
        await database.insertTransaction(TransactionsCompanion.insert(
          amount: 1000.0,
          description: const Value('Old income'),
          date: threeMonthsAgo,
          categoryId: salary.id,
          type: 'income',
        ));
      },
      act: (bloc) async {
        bloc.add(LoadAnalyticsData(filterType: 'week'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) {
        final state = bloc.state;
        expect(state, isA<AnalyticsLoaded>());
        final loaded = state as AnalyticsLoaded;
        // The week filter excludes the transaction from totals...
        expect(loaded.totalIncome, 0);
        // ...but the 6-month trend must still see it, since bounding the DB
        // subscription to the active filter's own start date would have
        // clipped it out entirely.
        final now = DateTime.now();
        final threeMonthsAgoName = DateFormat('MMM').format(DateTime(now.year, now.month - 3, 1));
        final monthEntry = loaded.monthlySpends.firstWhere((m) => m.monthName == threeMonthsAgoName);
        expect(monthEntry.income, 1000.0);
      },
    );
  });
}
