import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ledger_lite/blocs/transaction/transaction_bloc.dart';
import 'package:ledger_lite/blocs/category/category_bloc.dart';
import 'package:ledger_lite/data/database/app_database.dart';
import 'package:ledger_lite/features/dashboard/dashboard_screen.dart'; // import to reuse getCategoryIcon

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedType = 'all'; // 'all', 'income', 'expense'
  Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    // Ensure data is loaded
    context.read<TransactionBloc>().add(LoadTransactions());
    context.read<CategoryBloc>().add(LoadCategories());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper to format date header
  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) {
      return 'Today';
    } else if (checkDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMMM dd, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search descriptions or categories...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                // Type Filter Chips
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedType == 'all',
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = 'all';
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Expense'),
                  selected: _selectedType == 'expense',
                  selectedColor: theme.colorScheme.errorContainer,
                  labelStyle: TextStyle(
                    color: _selectedType == 'expense' ? theme.colorScheme.onErrorContainer : null,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = 'expense';
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Income'),
                  selected: _selectedType == 'income',
                  selectedColor: Colors.green.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: _selectedType == 'income' ? Colors.green[800] : null,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = 'income';
                    });
                  },
                ),
                const VerticalDivider(width: 20, thickness: 1),
                // Category Filter chips
                BlocBuilder<CategoryBloc, CategoryState>(
                  builder: (context, state) {
                    if (state is CategoryLoaded) {
                      return Wrap(
                        spacing: 8,
                        children: state.categories.map((cat) {
                          final isSelected = _selectedCategory?.id == cat.id;
                          return FilterChip(
                            avatar: Icon(getCategoryIcon(cat.icon), color: isSelected ? Colors.white : Color(cat.colorValue), size: 16),
                            label: Text(cat.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = selected ? cat : null;
                              });
                            },
                          );
                        }).toList(),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Transaction List
          Expanded(
            child: BlocBuilder<TransactionBloc, TransactionState>(
              builder: (context, state) {
                if (state is TransactionLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is TransactionLoaded) {
                  // Apply Client-Side Filtering
                  var filtered = state.transactions.where((txWithCat) {
                    final tx = txWithCat.transaction;
                    final cat = txWithCat.category;

                    // 1. Filter by search query
                    final descMatch = tx.description?.toLowerCase().contains(_searchQuery) ?? false;
                    final catMatch = cat.name.toLowerCase().contains(_searchQuery);
                    if (_searchQuery.isNotEmpty && !descMatch && !catMatch) {
                      return false;
                    }

                    // 2. Filter by type
                    if (_selectedType != 'all' && tx.type != _selectedType) {
                      return false;
                    }

                    // 3. Filter by category
                    if (_selectedCategory != null && tx.categoryId != _selectedCategory!.id) {
                      return false;
                    }

                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: theme.disabledColor),
                          const SizedBox(height: 16),
                          Text(
                            'No matching transactions found',
                            style: theme.textTheme.titleMedium?.copyWith(color: theme.disabledColor),
                          ),
                        ],
                      ),
                    );
                  }

                  // Group by date
                  final Map<String, List<TransactionWithCategory>> groupedTransactions = {};
                  for (var txWithCat in filtered) {
                    final header = _formatDateHeader(txWithCat.transaction.date);
                    groupedTransactions[header] = groupedTransactions[header] ?? [];
                    groupedTransactions[header]!.add(txWithCat);
                  }

                  final keys = groupedTransactions.keys.toList();

                  return ListView.builder(
                    itemCount: keys.length,
                    itemBuilder: (context, groupIndex) {
                      final groupHeader = keys[groupIndex];
                      final txList = groupedTransactions[groupHeader]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date Header Section
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                            child: Text(
                              groupHeader.toUpperCase(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          // List of transactions for this date
                          Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16.0),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: txList.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final txWithCat = txList[index];
                                final tx = txWithCat.transaction;
                                final cat = txWithCat.category;
                                final isIncome = tx.type == 'income';

                                return Dismissible(
                                  key: Key('all_tx_${tx.id}'),
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
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
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
                                      DateFormat('hh:mm a').format(tx.date),
                                      style: TextStyle(color: theme.disabledColor, fontSize: 11),
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
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}
