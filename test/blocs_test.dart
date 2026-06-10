import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:drift/native.dart';
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
  });
}
