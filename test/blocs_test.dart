import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledger_lite/data/database/app_database.dart';
import 'package:ledger_lite/blocs/auth/auth_bloc.dart';
import 'package:ledger_lite/blocs/transaction/transaction_bloc.dart';
import 'package:ledger_lite/blocs/analytics/analytics_bloc.dart';
import 'package:ledger_lite/blocs/category/category_bloc.dart';

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
