import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ledger_lite/blocs/auth/auth_bloc.dart';
import 'package:ledger_lite/blocs/analytics/analytics_bloc.dart';
import 'package:ledger_lite/blocs/category/category_bloc.dart';
import 'package:ledger_lite/blocs/transaction/transaction_bloc.dart';
import 'package:ledger_lite/features/dashboard/dashboard_screen.dart';
import 'package:ledger_lite/features/lock/lock_screen.dart';

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

class MockTransactionBloc extends MockBloc<TransactionEvent, TransactionState> implements TransactionBloc {}

class MockCategoryBloc extends MockBloc<CategoryEvent, CategoryState> implements CategoryBloc {}

class MockAnalyticsBloc extends MockBloc<AnalyticsEvent, AnalyticsState> implements AnalyticsBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LockScreen', () {
    late MockLocalAuthentication mockLocalAuth;

    setUp(() {
      mockLocalAuth = MockLocalAuthentication();
      when(() => mockLocalAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            biometricOnly: any(named: 'biometricOnly'),
          )).thenAnswer((_) async => false);
    });

    testWidgets('shows the locked prompt and an unlock button', (tester) async {
      final authBloc = AuthBloc(localAuth: mockLocalAuth);
      addTearDown(authBloc.close);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: authBloc,
            child: const LockScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('App Locked'), findsOneWidget);
      expect(find.text('Unlock LedgerLite'), findsOneWidget);
    });

    testWidgets('shows the auth error message after a failed attempt', (tester) async {
      final authBloc = AuthBloc(localAuth: mockLocalAuth);
      addTearDown(authBloc.close);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: authBloc,
            child: const LockScreen(),
          ),
        ),
      );
      // initState's post-frame callback triggers an authenticate() call that
      // the mock resolves to `false`, which should surface an error message.
      await tester.pumpAndSettle();

      expect(find.text('Authentication failed. Please try again.'), findsOneWidget);
    });
  });

  group('DashboardScreen', () {
    // Mocked blocs (not a real drift database) so the widget test is
    // deterministic and instant - no real Stream/Timer/isolate is involved.
    late MockTransactionBloc transactionBloc;
    late MockCategoryBloc categoryBloc;
    late MockAnalyticsBloc analyticsBloc;

    setUp(() {
      transactionBloc = MockTransactionBloc();
      categoryBloc = MockCategoryBloc();
      analyticsBloc = MockAnalyticsBloc();
    });

    Widget buildDashboard() {
      return MultiBlocProvider(
        providers: [
          BlocProvider<TransactionBloc>.value(value: transactionBloc),
          BlocProvider<CategoryBloc>.value(value: categoryBloc),
          BlocProvider<AnalyticsBloc>.value(value: analyticsBloc),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      );
    }

    testWidgets('shows the empty state when there are no transactions', (tester) async {
      whenListen(transactionBloc, const Stream<TransactionState>.empty(),
          initialState: const TransactionLoaded([]));
      whenListen(categoryBloc, const Stream<CategoryState>.empty(), initialState: const CategoryLoaded([]));
      whenListen(
        analyticsBloc,
        const Stream<AnalyticsState>.empty(),
        initialState: const AnalyticsLoaded(
          totalIncome: 0,
          totalExpense: 0,
          totalBalance: 0,
          categoryExpenses: {},
          categoryIncomes: {},
          monthlySpends: [],
          dailySpends: [],
          filterType: 'month',
        ),
      );

      await tester.pumpWidget(buildDashboard());
      await tester.pump();

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('No transactions yet'), findsOneWidget);
    });

    testWidgets('shows a loading indicator while transactions are loading', (tester) async {
      whenListen(transactionBloc, const Stream<TransactionState>.empty(), initialState: TransactionLoading());
      whenListen(categoryBloc, const Stream<CategoryState>.empty(), initialState: CategoryLoading());
      whenListen(analyticsBloc, const Stream<AnalyticsState>.empty(), initialState: AnalyticsLoading());

      await tester.pumpWidget(buildDashboard());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('No transactions yet'), findsNothing);
    });
  });
}
