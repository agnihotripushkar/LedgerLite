import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:ledger_lite/blocs/analytics/analytics_bloc.dart';
import 'package:ledger_lite/features/dashboard/dashboard_screen.dart'; // for getCategoryIcon

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    // Default load monthly analytics
    context.read<AnalyticsBloc>().add(LoadAnalyticsData(filterType: 'month'));
  }

  Future<void> _selectCustomRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      ),
    );

    if (picked != null && mounted) {
      context.read<AnalyticsBloc>().add(LoadAnalyticsData(
        filterType: 'custom',
        customRange: picked,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: BlocBuilder<AnalyticsBloc, AnalyticsState>(
        builder: (context, state) {
          if (state is AnalyticsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AnalyticsLoaded) {
            // Calculate max value for trend chart y-axis scaling
            double maxTrendVal = 100;
            for (var val in state.monthlySpends) {
              if (val.income > maxTrendVal) maxTrendVal = val.income;
              if (val.expense > maxTrendVal) maxTrendVal = val.expense;
            }
            maxTrendVal *= 1.15; // 15% padding at top of chart

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Range Picker Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChipButton(
                          label: 'This Week',
                          isSelected: state.filterType == 'week',
                          onTap: () => context.read<AnalyticsBloc>().add(LoadAnalyticsData(filterType: 'week')),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipButton(
                          label: 'This Month',
                          isSelected: state.filterType == 'month',
                          onTap: () => context.read<AnalyticsBloc>().add(LoadAnalyticsData(filterType: 'month')),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipButton(
                          label: 'This Year',
                          isSelected: state.filterType == 'year',
                          onTap: () => context.read<AnalyticsBloc>().add(LoadAnalyticsData(filterType: 'year')),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipButton(
                          label: state.filterType == 'custom'
                              ? 'Custom (${DateFormat('MM/dd').format(state.customRange!.start)} - ${DateFormat('MM/dd').format(state.customRange!.end)})'
                              : 'Custom Range',
                          isSelected: state.filterType == 'custom',
                          onTap: () => _selectCustomRange(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // High-level aggregation metrics
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth > 600 ? 3 : 1;
                      if (cols == 3) {
                        return Row(
                          children: [
                            Expanded(child: _SummaryStatCard(title: 'Total Income', value: currencyFormat.format(state.totalIncome), color: Colors.green)),
                            const SizedBox(width: 12),
                            Expanded(child: _SummaryStatCard(title: 'Total Expenses', value: currencyFormat.format(state.totalExpense), color: theme.colorScheme.error)),
                            const SizedBox(width: 12),
                            Expanded(child: _SummaryStatCard(title: 'Net Savings', value: currencyFormat.format(state.totalBalance), color: theme.colorScheme.primary)),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _SummaryStatCard(title: 'Total Income', value: currencyFormat.format(state.totalIncome), color: Colors.green),
                            const SizedBox(height: 8),
                            _SummaryStatCard(title: 'Total Expenses', value: currencyFormat.format(state.totalExpense), color: theme.colorScheme.error),
                            const SizedBox(height: 8),
                            _SummaryStatCard(title: 'Net Savings', value: currencyFormat.format(state.totalBalance), color: theme.colorScheme.primary),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Visual Graphs Grid
                  LayoutBuilder(
                    builder: (context, gridConstraints) {
                      final useHorizontalSplit = gridConstraints.maxWidth > 900;

                      final pieChartCard = Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expenses Breakdown',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 32),
                              if (state.categoryExpenses.isEmpty)
                                const SizedBox(
                                  height: 220,
                                  child: Center(child: Text('No spending data for the selected period')),
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: SizedBox(
                                        height: 200,
                                        child: PieChart(
                                          PieChartData(
                                            sectionsSpace: 3,
                                            centerSpaceRadius: 35,
                                            sections: state.categoryExpenses.entries.map((entry) {
                                              final percentage = (entry.value / state.totalExpense) * 100;
                                              return PieChartSectionData(
                                                color: Color(entry.key.colorValue),
                                                value: entry.value,
                                                title: '${percentage.toStringAsFixed(0)}%',
                                                radius: 40,
                                                titleStyle: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: state.categoryExpenses.entries.map((entry) {
                                          final cat = entry.key;
                                          final val = entry.value;
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: Color(cat.colorValue),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    cat.name,
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  currencyFormat.format(val),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.disabledColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );

                      final barChartCard = Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monthly Income vs Expense Trend',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                height: 220,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: maxTrendVal,
                                    barTouchData: BarTouchData(
                                      touchTooltipData: BarTouchTooltipData(
                                        getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
                                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                          final label = rodIndex == 0 ? 'Income' : 'Expense';
                                          return BarTooltipItem(
                                            '$label\n${currencyFormat.format(rod.toY)}',
                                            TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                                          );
                                        },
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (double value, TitleMeta meta) {
                                            int idx = value.toInt();
                                            if (idx >= 0 && idx < state.monthlySpends.length) {
                                              return SideTitleWidget(
                                                meta: meta,
                                                child: Text(
                                                  state.monthlySpends[idx].monthName,
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    barGroups: state.monthlySpends.asMap().entries.map((entry) {
                                      int index = entry.key;
                                      var trend = entry.value;
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: trend.income,
                                            color: Colors.green,
                                            width: 10,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          BarChartRodData(
                                            toY: trend.expense,
                                            color: theme.colorScheme.error,
                                            width: 10,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Chart Legend
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(3))),
                                      const SizedBox(width: 6),
                                      const Text('Income', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(width: 24),
                                  Row(
                                    children: [
                                      Container(width: 12, height: 12, decoration: BoxDecoration(color: theme.colorScheme.error, borderRadius: BorderRadius.circular(3))),
                                      const SizedBox(width: 6),
                                      const Text('Expense', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );

                      if (useHorizontalSplit) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: pieChartCard),
                            const SizedBox(width: 16),
                            Expanded(child: barChartCard),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            pieChartCard,
                            const SizedBox(height: 16),
                            barChartCard,
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// --- Custom Subcomponents ---
class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RawChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? theme.colorScheme.onPrimaryContainer : null,
      ),
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryStatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.disabledColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
