import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:intl/intl.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledger_lite/data/database/app_database.dart';
import 'package:ledger_lite/blocs/auth/auth_bloc.dart';
import 'package:ledger_lite/blocs/transaction/transaction_bloc.dart';
import 'package:ledger_lite/blocs/analytics/analytics_bloc.dart';
import 'package:ledger_lite/blocs/category/category_bloc.dart';

import 'package:mocktail/mocktail.dart';
import 'package:local_auth/local_auth.dart';

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

class FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async => Directory.systemTemp.path;
}

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

    blocTest<AuthBloc, AuthState>(
      'keeps isLockEnabledSync in sync with CheckAuthStatus and ToggleAppLock',
      build: () => AuthBloc(localAuth: mockLocalAuth),
      act: (bloc) async {
        bloc.add(CheckAuthStatus());
        await Future<void>.delayed(Duration.zero);
        bloc.add(ToggleAppLock(true));
      },
      verify: (bloc) {
        expect(bloc.isLockEnabledSync, isTrue);
      },
    );
  });

  group('TransactionBloc & AnalyticsBloc Tests', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      PathProviderPlatform.instance = FakePathProviderPlatform();
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

    blocTest<TransactionBloc, TransactionState>(
      'emits TransactionError when CSV export requested before transactions are loaded',
      build: () => TransactionBloc(database),
      act: (bloc) => bloc.add(ExportTransactionsCsv()),
      expect: () => [
        isA<TransactionError>(),
      ],
    );

    blocTest<TransactionBloc, TransactionState>(
      'emits TransactionLoaded with csvExportPath when CSV export succeeds',
      build: () => TransactionBloc(database),
      act: (bloc) async {
        bloc.add(LoadTransactions());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(ExportTransactionsCsv());
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      expect: () => [
        isA<TransactionLoading>(),
        isA<TransactionLoaded>(),
        predicate<TransactionLoaded>((state) => state.csvExportPath != null),
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

  group('CategoryBloc Tests', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    blocTest<CategoryBloc, CategoryState>(
      'emits CategoryLoading and CategoryLoaded with the 10 default categories',
      build: () => CategoryBloc(database),
      act: (bloc) => bloc.add(LoadCategories()),
      expect: () => [
        isA<CategoryLoading>(),
        predicate<CategoryLoaded>((state) => state.categories.length == 10),
      ],
    );

    blocTest<CategoryBloc, CategoryState>(
      'emits an updated CategoryLoaded after successfully adding a category',
      build: () => CategoryBloc(database),
      act: (bloc) async {
        bloc.add(LoadCategories());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(AddCategory(name: 'Freelance', icon: 'work', colorValue: 0xFF009688, isIncome: true));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      expect: () => [
        isA<CategoryLoading>(),
        isA<CategoryLoaded>(),
        predicate<CategoryLoaded>(
          (state) => state.categories.length == 11 && state.categories.any((c) => c.name == 'Freelance'),
        ),
      ],
    );

    blocTest<CategoryBloc, CategoryState>(
      'emits CategoryError when adding a category with a duplicate name',
      build: () => CategoryBloc(database),
      act: (bloc) => bloc.add(AddCategory(name: 'Salary', icon: 'payments', colorValue: 0xFF4CAF50, isIncome: true)),
      expect: () => [
        isA<CategoryError>(),
      ],
    );
  });
}
