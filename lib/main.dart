import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ledger_lite/data/database/app_database.dart';
import 'package:ledger_lite/blocs/auth/auth_bloc.dart';
import 'package:ledger_lite/blocs/transaction/transaction_bloc.dart';
import 'package:ledger_lite/blocs/category/category_bloc.dart';
import 'package:ledger_lite/blocs/analytics/analytics_bloc.dart';
import 'package:ledger_lite/routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final database = AppDatabase();
  
  runApp(
    RepositoryProvider<AppDatabase>.value(
      value: database,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc()..add(CheckAuthStatus()),
          ),
          BlocProvider<TransactionBloc>(
            create: (context) => TransactionBloc(database)..add(LoadTransactions()),
          ),
          BlocProvider<CategoryBloc>(
            create: (context) => CategoryBloc(database)..add(LoadCategories()),
          ),
          BlocProvider<AnalyticsBloc>(
            create: (context) => AnalyticsBloc(database)..add(LoadAnalyticsData(filterType: 'month')),
          ),
        ],
        child: const LedgerLiteApp(),
      ),
    ),
  );
}

class LedgerLiteApp extends StatefulWidget {
  const LedgerLiteApp({super.key});

  @override
  State<LedgerLiteApp> createState() => _LedgerLiteAppState();
}

class _LedgerLiteAppState extends State<LedgerLiteApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.router(context.read<AuthBloc>());
  }

  @override
  Widget build(BuildContext context) {
    // Premium Material 3 Light Theme (Teal Seed)
    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0D9488), // Teal-600
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate-50 background
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
    );

    // Premium Material 3 Dark Theme (Teal + Slate)
    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0D9488), // Teal-600
        brightness: Brightness.dark,
        surface: const Color(0xFF1E293B), // Slate-800
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate-900 background
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
    );

    return MaterialApp.router(
      title: 'LedgerLite',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
