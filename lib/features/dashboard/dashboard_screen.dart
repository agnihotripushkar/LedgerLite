import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_lite/blocs/transaction/transaction_bloc.dart';
import 'package:ledger_lite/blocs/category/category_bloc.dart';
import 'package:ledger_lite/blocs/analytics/analytics_bloc.dart';
import 'package:ledger_lite/data/database/app_database.dart';

IconData getCategoryIcon(String iconName) {
  switch (iconName) {
    case 'payments':
      return Icons.payments;
    case 'trending_up':
      return Icons.trending_up;
    case 'history':
      return Icons.history;
    case 'restaurant':
      return Icons.restaurant;
    case 'shopping_bag':
      return Icons.shopping_bag;
    case 'directions_car':
      return Icons.directions_car;
    case 'receipt_long':
      return Icons.receipt_long;
    case 'sports_esports':
      return Icons.sports_esports;
    case 'medical_services':
      return Icons.medical_services;
    case 'school':
      return Icons.school;
    default:
      return Icons.category;
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Dispatch loads
    context.read<TransactionBloc>().add(LoadTransactions());
    context.read<CategoryBloc>().add(LoadCategories());
    context.read<AnalyticsBloc>().add(LoadAnalyticsData(filterType: 'month'));
  }

  void _showAddTransactionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<TransactionBloc>()),
            BlocProvider.value(value: context.read<CategoryBloc>()),
          ],
          child: const AddTransactionDialog(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, size: 28),
            onPressed: () => _showAddTransactionDialog(context),
            tooltip: 'Add Transaction',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth >= 900;

          final balanceWidget = BlocBuilder<AnalyticsBloc, AnalyticsState>(
            builder: (context, state) {
              if (state is AnalyticsLoading) {
                return const Card(
                  child: SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              if (state is AnalyticsLoaded) {
                return Column(
                  children: [
                    // Total Balance Header
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: theme.colorScheme.primaryContainer),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NET BALANCE',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  currencyFormat.format(state.totalBalance),
                                  style: theme.textTheme.headlineLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: state.totalBalance >= 0
                                        ? (theme.brightness == Brightness.dark ? Colors.greenAccent : Colors.green[700])
                                        : theme.colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Income & Expense Cards
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.arrow_downward, color: Colors.green, size: 20),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Income',
                                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    currencyFormat.format(state.totalIncome),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.error.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.arrow_upward, color: theme.colorScheme.error, size: 20),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Expenses',
                                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    currencyFormat.format(state.totalExpense),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          );

          final recentTransactionsWidget = Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Transactions',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          // Router redirect using GoRouter context helper
                          context.go('/transactions');
                        },
                        child: const Text('See All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  BlocBuilder<TransactionBloc, TransactionState>(
                    builder: (context, state) {
                      if (state is TransactionLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is TransactionLoaded) {
                        final txs = state.transactions.take(5).toList();
                        if (txs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32.0),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long, size: 48, color: theme.disabledColor),
                                  const SizedBox(height: 8),
                                  Text('No transactions yet', style: TextStyle(color: theme.disabledColor)),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: txs.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final txWithCat = txs[index];
                            final tx = txWithCat.transaction;
                            final cat = txWithCat.category;
                            final isIncome = tx.type == 'income';

                            return Dismissible(
                              key: Key('tx_${tx.id}'),
                              background: Container(
                                color: theme.colorScheme.error,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20.0),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              direction: DismissDirection.endToStart,
                              onDismissed: (direction) {
                                context.read<TransactionBloc>().add(DeleteTransaction(tx));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Transaction deleted')),
                                );
                              },
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Color(cat.colorValue).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    getCategoryIcon(cat.icon),
                                    color: Color(cat.colorValue),
                                  ),
                                ),
                                title: Text(
                                  tx.description?.isNotEmpty == true ? tx.description! : cat.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  DateFormat('MMM d, yyyy').format(tx.date),
                                  style: TextStyle(color: theme.disabledColor, fontSize: 12),
                                ),
                                trailing: Text(
                                  '${isIncome ? '+' : '-'}${currencyFormat.format(tx.amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isIncome ? Colors.green : theme.colorScheme.error,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          );

          final breakdownChartWidget = Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category Breakdown',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  BlocBuilder<AnalyticsBloc, AnalyticsState>(
                    builder: (context, state) {
                      if (state is AnalyticsLoading) {
                        return const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (state is AnalyticsLoaded) {
                        final expenses = state.categoryExpenses;
                        if (expenses.isEmpty) {
                          return const SizedBox(
                            height: 200,
                            child: Center(child: Text('No spending data for this month')),
                          );
                        }

                        final totalExp = state.totalExpense;

                        return Column(
                          children: [
                            SizedBox(
                              height: 180,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 4,
                                  centerSpaceRadius: 40,
                                  sections: expenses.entries.map((entry) {
                                    final percentage = (entry.value / totalExp) * 100;
                                    return PieChartSectionData(
                                      color: Color(entry.key.colorValue),
                                      value: entry.value,
                                      title: '${percentage.toStringAsFixed(0)}%',
                                      radius: 45,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Custom Legend
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: expenses.keys.map((cat) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Color(cat.colorValue),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      cat.name,
                                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          );

          if (isLargeScreen) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        balanceWidget,
                        const SizedBox(height: 24),
                        recentTransactionsWidget,
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        breakdownChartWidget,
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  balanceWidget,
                  const SizedBox(height: 16),
                  breakdownChartWidget,
                  const SizedBox(height: 16),
                  recentTransactionsWidget,
                ],
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransactionDialog(context),
        label: const Text('Add Tx'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

// --- Add Transaction Dialog Widget ---
class AddTransactionDialog extends StatefulWidget {
  const AddTransactionDialog({super.key});

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  
  String _txType = 'expense'; // 'expense' or 'income'
  Category? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Default select first category of correct type
    final catState = context.read<CategoryBloc>().state;
    if (catState is CategoryLoaded && catState.categories.isNotEmpty) {
      final relevant = catState.categories.where((c) => c.isIncome == (_txType == 'income')).toList();
      if (relevant.isNotEmpty) {
        _selectedCategory = relevant.first;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String? type) {
    if (type == null) return;
    setState(() {
      _txType = type;
      // Auto-update default category selector match
      final catState = context.read<CategoryBloc>().state;
      if (catState is CategoryLoaded) {
        final relevant = catState.categories.where((c) => c.isIncome == (_txType == 'income')).toList();
        _selectedCategory = relevant.isNotEmpty ? relevant.first : null;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    
    context.read<TransactionBloc>().add(AddTransaction(
      amount: amount,
      description: _descController.text.trim(),
      dateTime: _selectedDate,
      categoryId: _selectedCategory!.id,
      type: _txType,
    ));

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text('New Transaction', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Segmented type selector
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Expense')),
                      selected: _txType == 'expense',
                      onSelected: (selected) => _onTypeChanged('expense'),
                      selectedColor: theme.colorScheme.errorContainer,
                      labelStyle: TextStyle(
                        color: _txType == 'expense' ? theme.colorScheme.onErrorContainer : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Income')),
                      selected: _txType == 'income',
                      onSelected: (selected) => _onTypeChanged('income'),
                      selectedColor: Colors.green.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: _txType == 'income' ? Colors.green[800] : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Amount Input
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  labelText: 'Amount',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter an amount';
                  final parsed = double.tryParse(val);
                  if (parsed == null || parsed <= 0) return 'Enter a valid positive number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Category Selector
              BlocBuilder<CategoryBloc, CategoryState>(
                builder: (context, state) {
                  if (state is CategoryLoading) {
                    return const CircularProgressIndicator();
                  }
                  if (state is CategoryLoaded) {
                    final filteredCats = state.categories.where((c) => c.isIncome == (_txType == 'income')).toList();

                    return DropdownButtonFormField<Category>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                      ),
                      items: filteredCats.map((cat) {
                        return DropdownMenuItem<Category>(
                          value: cat,
                          child: Row(
                            children: [
                              Icon(getCategoryIcon(cat.icon), color: Color(cat.colorValue), size: 20),
                              const SizedBox(width: 10),
                              Text(cat.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (cat) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                    );
                  }
                  return const Text('Failed to load categories');
                },
              ),
              const SizedBox(height: 16),
              // Description
              TextFormField(
                controller: _descController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              // Date picker chip/button
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMMM dd, yyyy').format(_selectedDate)),
                      const Icon(Icons.calendar_month),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
