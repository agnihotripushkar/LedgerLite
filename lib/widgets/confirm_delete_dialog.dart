import 'package:flutter/material.dart';
import 'package:ledger_lite/data/database/app_database.dart';

/// Prompts the user to confirm deleting [txWithCat] before a swipe-to-delete
/// is committed. Returns true if the user confirmed deletion.
Future<bool> confirmDeleteTransaction(BuildContext context, TransactionWithCategory txWithCat) async {
  final tx = txWithCat.transaction;
  final cat = txWithCat.category;
  final label = tx.description?.isNotEmpty == true ? tx.description! : cat.name;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text('This will delete "$label". You can undo it from the snackbar right after.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  return confirmed ?? false;
}
