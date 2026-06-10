import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart';
import 'package:ledger_lite/data/database/app_database.dart';

// --- Events ---
abstract class TransactionEvent {}

class LoadTransactions extends TransactionEvent {}

class AddTransaction extends TransactionEvent {
  final double amount;
  final String description;
  final DateTime dateTime;
  final int categoryId;
  final String type; // 'income' or 'expense'

  AddTransaction({
    required this.amount,
    required this.description,
    required this.dateTime,
    required this.categoryId,
    required this.type,
  });
}

class UpdateTransaction extends TransactionEvent {
  final Transaction transaction;
  UpdateTransaction(this.transaction);
}

class DeleteTransaction extends TransactionEvent {
  final Transaction transaction;
  DeleteTransaction(this.transaction);
}

class ExportTransactionsCsv extends TransactionEvent {}

// --- States ---
abstract class TransactionState {
  const TransactionState();
}

class TransactionLoading extends TransactionState {}

class TransactionLoaded extends TransactionState {
  final List<TransactionWithCategory> transactions;
  final String? csvExportPath;
  const TransactionLoaded(this.transactions, {this.csvExportPath});
}

class TransactionError extends TransactionState {
  final String message;
  const TransactionError(this.message);
}

// --- BLoC ---
class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final AppDatabase _database;
  StreamSubscription<List<TransactionWithCategory>>? _subscription;

  TransactionBloc(this._database) : super(TransactionLoading()) {
    on<LoadTransactions>(_onLoadTransactions);
    on<_UpdateTransactionsList>(_onUpdateTransactionsList);
    on<AddTransaction>(_onAddTransaction);
    on<UpdateTransaction>(_onUpdateTransaction);
    on<DeleteTransaction>(_onDeleteTransaction);
    on<ExportTransactionsCsv>(_onExportTransactionsCsv);
  }

  void _onLoadTransactions(LoadTransactions event, Emitter<TransactionState> emit) {
    emit(TransactionLoading());
    _subscription?.cancel();
    _subscription = _database.watchTransactions().listen(
      (transactions) {
        add(_UpdateTransactionsList(transactions));
      },
      onError: (error) {
        emit(TransactionError('Failed to load transactions: $error'));
      },
    );
  }

  // Internal helper event to handle stream updates
  void _onUpdateTransactionsList(_UpdateTransactionsList event, Emitter<TransactionState> emit) {
    emit(TransactionLoaded(event.transactions));
  }

  Future<void> _onAddTransaction(AddTransaction event, Emitter<TransactionState> emit) async {
    try {
      await _database.insertTransaction(TransactionsCompanion.insert(
        amount: event.amount,
        description: Value(event.description),
        date: event.dateTime,
        categoryId: event.categoryId,
        type: event.type,
      ));
    } catch (e) {
      emit(TransactionError('Failed to add transaction: $e'));
    }
  }

  Future<void> _onUpdateTransaction(UpdateTransaction event, Emitter<TransactionState> emit) async {
    try {
      await _database.updateTransaction(event.transaction);
    } catch (e) {
      emit(TransactionError('Failed to update transaction: $e'));
    }
  }

  Future<void> _onDeleteTransaction(DeleteTransaction event, Emitter<TransactionState> emit) async {
    try {
      await _database.deleteTransaction(event.transaction);
    } catch (e) {
      emit(TransactionError('Failed to delete transaction: $e'));
    }
  }

  Future<void> _onExportTransactionsCsv(ExportTransactionsCsv event, Emitter<TransactionState> emit) async {
    final currentState = state;
    if (currentState is TransactionLoaded) {
      try {
        final transactions = currentState.transactions;
        
        // Prepare CSV rows
        List<List<dynamic>> rows = [
          ['ID', 'Date', 'Type', 'Category', 'Amount', 'Description']
        ];
        
        for (var t in transactions) {
          rows.add([
            t.transaction.id,
            t.transaction.date.toIso8601String(),
            t.transaction.type,
            t.category.name,
            t.transaction.amount,
            t.transaction.description ?? '',
          ]);
        }
        
        // Convert to CSV
        String csvData = Csv().encode(rows);
        
        // Save to file
        final directory = await getApplicationDocumentsDirectory();
        final filePath = p.join(directory.path, 'ledger_lite_export_${DateTime.now().millisecondsSinceEpoch}.csv');
        final file = File(filePath);
        await file.writeAsString(csvData);
        
        emit(TransactionLoaded(currentState.transactions, csvExportPath: filePath));
      } catch (e) {
        emit(TransactionError('Failed to export CSV: $e'));
      }
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

// Internal class to dispatch database stream updates to bloc state
class _UpdateTransactionsList extends TransactionEvent {
  final List<TransactionWithCategory> transactions;
  _UpdateTransactionsList(this.transactions);
}
