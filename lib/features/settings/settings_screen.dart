import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledger_lite/blocs/auth/auth_bloc.dart';
import 'package:ledger_lite/blocs/transaction/transaction_bloc.dart';
import 'package:ledger_lite/data/database/app_database.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hasBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final auth = context.read<AuthBloc>();
    final hasBio = await auth.hasBiometrics();
    setState(() {
      _hasBiometrics = hasBio;
    });
  }

  void _confirmResetDatabase(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Reset Database?'),
          content: const Text(
            'This action will permanently delete all your transactions and reset categories to their default states. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Clear SQLite tables
                final db = context.read<AppDatabase>();
                await db.resetDatabase();
                if (context.mounted) {
                  // Reload transactions list
                  context.read<TransactionBloc>().add(LoadTransactions());
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Database reset successfully')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<TransactionBloc, TransactionState>(
      listener: (context, state) {
        if (state is TransactionLoaded && state.csvExportPath != null) {
          showDialog(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Export Successful'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CSV file saved successfully to:'),
                    const SizedBox(height: 8),
                    SelectableText(
                      state.csvExportPath!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Dismiss'),
                  ),
                ],
              );
            },
          );
        } else if (state is TransactionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          children: [
            // Security Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.security),
                      title: const Text('Biometric Security', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        _hasBiometrics
                            ? 'Enable fingerprint or face unlock on launch.'
                            : 'Biometrics unavailable on this device.',
                      ),
                      trailing: BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          bool isEnabled = false;
                          if (state is AuthConfigured) {
                            isEnabled = state.isLockEnabled;
                          } else {
                            // Fetch sync status or state check
                            final isLockEnabled = context.read<AuthBloc>().state is! AuthUnlocked;
                            // Wait, we can toggle dynamically.
                          }
                          return FutureBuilder<bool>(
                            future: context.read<AuthBloc>().isLockEnabled(),
                            builder: (context, snapshot) {
                              final currentVal = snapshot.data ?? false;
                              return Switch(
                                value: currentVal,
                                onChanged: _hasBiometrics
                                    ? (val) {
                                        context.read<AuthBloc>().add(ToggleAppLock(val));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              val ? 'Biometric Lock Enabled' : 'Biometric Lock Disabled',
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Data Management Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.file_download),
                      title: const Text('Export Data', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Compile transactions list into a CSV spreadsheet file.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        context.read<TransactionBloc>().add(ExportTransactionsCsv());
                      },
                    ),
                    const Divider(indent: 56),
                    ListTile(
                      leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
                      title: Text(
                        'Reset All Data',
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.error),
                      ),
                      subtitle: const Text('Clear all saved transactions and reset categories.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _confirmResetDatabase(context),
                    ),
                  ],
                ),
              ),
            ),
            // App Info Section
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Text(
                    'LedgerLite v1.0.0',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.disabledColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Flutter Mobile + Desktop Expense Tracker',
                    style: TextStyle(
                      color: theme.disabledColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
