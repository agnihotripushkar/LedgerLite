import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ledger_lite/data/database/app_database.dart';

// --- Helper Models ---
class MonthlySpend {
  final String monthName; // e.g., "Jan", "Feb"
  final double income;
  final double expense;
  MonthlySpend(this.monthName, this.income, this.expense);
}

class DailySpend {
  final DateTime date;
  final double amount;
  DailySpend(this.date, this.amount);
}

// --- Events ---
abstract class AnalyticsEvent {}

class LoadAnalyticsData extends AnalyticsEvent {
  final String filterType; // 'week', 'month', 'year', 'all'
  final DateTimeRange? customRange;
  LoadAnalyticsData({required this.filterType, this.customRange});
}

class _UpdateAnalyticsFromDb extends AnalyticsEvent {
  final List<TransactionWithCategory> transactions;
  _UpdateAnalyticsFromDb(this.transactions);
}

// --- States ---
abstract class AnalyticsState {
  const AnalyticsState();
}

class AnalyticsLoading extends AnalyticsState {}

class AnalyticsLoaded extends AnalyticsState {
  final double totalIncome;
  final double totalExpense;
  final double totalBalance;
  final Map<Category, double> categoryExpenses;
  final Map<Category, double> categoryIncomes;
  final List<MonthlySpend> monthlySpends;
  final List<DailySpend> dailySpends;
  final String filterType;
  final DateTimeRange? customRange;

  const AnalyticsLoaded({
    required this.totalIncome,
    required this.totalExpense,
    required this.totalBalance,
    required this.categoryExpenses,
    required this.categoryIncomes,
    required this.monthlySpends,
    required this.dailySpends,
    required this.filterType,
    this.customRange,
  });
}

class AnalyticsError extends AnalyticsState {
  final String message;
  const AnalyticsError(this.message);
}

// --- BLoC ---
class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  final AppDatabase _database;
  StreamSubscription<List<TransactionWithCategory>>? _subscription;
  String _currentFilterType = 'month';
  DateTimeRange? _currentCustomRange;

  AnalyticsBloc(this._database) : super(AnalyticsLoading()) {
    on<LoadAnalyticsData>(_onLoadAnalyticsData);
    on<_UpdateAnalyticsFromDb>(_onUpdateAnalyticsFromDb);
  }

  void _onLoadAnalyticsData(LoadAnalyticsData event, Emitter<AnalyticsState> emit) {
    _currentFilterType = event.filterType;
    _currentCustomRange = event.customRange;
    emit(AnalyticsLoading());

    _subscription?.cancel();
    _subscription = _database.watchTransactions().listen(
      (transactions) {
        add(_UpdateAnalyticsFromDb(transactions));
      },
      onError: (error) {
        emit(AnalyticsError('Failed to load analytics: $error'));
      },
    );
  }

  void _onUpdateAnalyticsFromDb(_UpdateAnalyticsFromDb event, Emitter<AnalyticsState> emit) {
    final allTransactions = event.transactions;
    final now = DateTime.now();

    // 1. Filter transactions based on date criteria
    DateTime? startDate;
    DateTime? endDate = now;

    if (_currentFilterType == 'week') {
      startDate = now.subtract(const Duration(days: 7));
    } else if (_currentFilterType == 'month') {
      startDate = DateTime(now.year, now.month, 1);
    } else if (_currentFilterType == 'year') {
      startDate = DateTime(now.year, 1, 1);
    } else if (_currentFilterType == 'custom' && _currentCustomRange != null) {
      startDate = _currentCustomRange!.start;
      endDate = _currentCustomRange!.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    }

    final filteredTransactions = allTransactions.where((item) {
      final tDate = item.transaction.date;
      if (startDate != null && tDate.isBefore(startDate)) return false;
      if (endDate != null && tDate.isAfter(endDate)) return false;
      return true;
    }).toList();

    // 2. Calculate aggregations
    double totalIncome = 0;
    double totalExpense = 0;
    final Map<Category, double> categoryExpenses = {};
    final Map<Category, double> categoryIncomes = {};

    for (var item in filteredTransactions) {
      final t = item.transaction;
      final cat = item.category;

      if (t.type == 'income') {
        totalIncome += t.amount;
        categoryIncomes[cat] = (categoryIncomes[cat] ?? 0) + t.amount;
      } else {
        totalExpense += t.amount;
        categoryExpenses[cat] = (categoryExpenses[cat] ?? 0) + t.amount;
      }
    }

    double totalBalance = totalIncome - totalExpense;

    // 3. Daily spending (typically for line chart, last N days of filtered transactions)
    // Group by day
    final Map<String, double> dailyGroups = {};
    final dailyFormat = DateFormat('yyyy-MM-dd');
    for (var item in filteredTransactions) {
      if (item.transaction.type == 'expense') {
        final key = dailyFormat.format(item.transaction.date);
        dailyGroups[key] = (dailyGroups[key] ?? 0) + item.transaction.amount;
      }
    }

    final List<DailySpend> dailySpends = dailyGroups.entries.map((entry) {
      return DailySpend(dailyFormat.parse(entry.key), entry.value);
    }).toList();
    dailySpends.sort((a, b) => a.date.compareTo(b.date));

    // 4. Monthly trend (typically bar chart showing last 6 months comparison)
    // Let's use the unfiltered transactions list for this to show a true history trend
    final Map<String, Map<String, double>> monthlyGroups = {}; // "yyyy-MM" -> {"income": X, "expense": Y}
    final monthlyKeyFormat = DateFormat('yyyy-MM');
    
    // Sort transactions chronologically for trend building
    final chronologicalTx = List<TransactionWithCategory>.from(allTransactions)
      ..sort((a, b) => a.transaction.date.compareTo(b.transaction.date));

    // Determine months to include (last 6 months)
    for (int i = 5; i >= 0; i--) {
      final pastDate = DateTime(now.year, now.month - i, 1);
      final key = monthlyKeyFormat.format(pastDate);
      monthlyGroups[key] = {'income': 0.0, 'expense': 0.0};
    }

    for (var item in chronologicalTx) {
      final key = monthlyKeyFormat.format(item.transaction.date);
      if (monthlyGroups.containsKey(key)) {
        final type = item.transaction.type;
        monthlyGroups[key]![type] = (monthlyGroups[key]![type] ?? 0.0) + item.transaction.amount;
      }
    }

    final List<MonthlySpend> monthlySpends = monthlyGroups.entries.map((entry) {
      final parsedDate = DateFormat('yyyy-MM').parse(entry.key);
      final monthName = DateFormat('MMM').format(parsedDate);
      return MonthlySpend(
        monthName,
        entry.value['income'] ?? 0.0,
        entry.value['expense'] ?? 0.0,
      );
    }).toList();

    emit(AnalyticsLoaded(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      totalBalance: totalBalance,
      categoryExpenses: categoryExpenses,
      categoryIncomes: categoryIncomes,
      monthlySpends: monthlySpends,
      dailySpends: dailySpends,
      filterType: _currentFilterType,
      customRange: _currentCustomRange,
    ));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
