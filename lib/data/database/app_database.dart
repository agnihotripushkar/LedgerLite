import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get icon => text()();
  IntColumn get colorValue => integer()();
  BoolColumn get isIncome => boolean()();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get date => dateTime()();
  IntColumn get categoryId => integer().customConstraint('NOT NULL REFERENCES categories(id)')();
  TextColumn get type => text()(); // 'income' or 'expense'
}

class TransactionWithCategory {
  final Transaction transaction;
  final Category category;

  TransactionWithCategory({
    required this.transaction,
    required this.category,
  });
}

@DriftDatabase(tables: [Categories, Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Insert default categories
        await batch((b) {
          b.insertAll(categories, [
            CategoriesCompanion.insert(name: 'Salary', icon: 'payments', colorValue: 0xFF4CAF50, isIncome: true),
            CategoriesCompanion.insert(name: 'Investments', icon: 'trending_up', colorValue: 0xFF2196F3, isIncome: true),
            CategoriesCompanion.insert(name: 'Refunds', icon: 'history', colorValue: 0xFF00BCD4, isIncome: true),
            CategoriesCompanion.insert(name: 'Food & Dining', icon: 'restaurant', colorValue: 0xFFFF9800, isIncome: false),
            CategoriesCompanion.insert(name: 'Shopping', icon: 'shopping_bag', colorValue: 0xFFE91E63, isIncome: false),
            CategoriesCompanion.insert(name: 'Transportation', icon: 'directions_car', colorValue: 0xFF03A9F4, isIncome: false),
            CategoriesCompanion.insert(name: 'Bills & Utilities', icon: 'receipt_long', colorValue: 0xFF9C27B0, isIncome: false),
            CategoriesCompanion.insert(name: 'Entertainment', icon: 'sports_esports', colorValue: 0xFFFF5722, isIncome: false),
            CategoriesCompanion.insert(name: 'Healthcare', icon: 'medical_services', colorValue: 0xFFE53935, isIncome: false),
            CategoriesCompanion.insert(name: 'Education', icon: 'school', colorValue: 0xFF795548, isIncome: false),
          ]);
        });
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');
      },
    );
  }

  // --- Category operations ---
  Stream<List<Category>> watchCategories() {
    return select(categories).watch();
  }

  Future<List<Category>> getAllCategories() {
    return select(categories).get();
  }

  Future<int> insertCategory(CategoriesCompanion companion) {
    return into(categories).insert(companion);
  }

  // --- Transaction operations ---
  Stream<List<TransactionWithCategory>> watchTransactions() {
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ]);
    // Order by date descending
    query.orderBy([OrderingTerm.desc(transactions.date)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithCategory(
          transaction: row.readTable(transactions),
          category: row.readTable(categories),
        );
      }).toList();
    });
  }

  Future<List<TransactionWithCategory>> getAllTransactions() {
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ]);
    query.orderBy([OrderingTerm.desc(transactions.date)]);

    return query.get().then((rows) {
      return rows.map((row) {
        return TransactionWithCategory(
          transaction: row.readTable(transactions),
          category: row.readTable(categories),
        );
      }).toList();
    });
  }

  Future<int> insertTransaction(TransactionsCompanion companion) {
    return into(transactions).insert(companion);
  }

  Future<bool> updateTransaction(Transaction transaction) {
    return update(transactions).replace(transaction);
  }

  Future<int> deleteTransaction(Transaction transaction) {
    return (delete(transactions)..where((t) => t.id.equals(transaction.id))).go();
  }

  // --- Reset Database ---
  Future<void> resetDatabase() async {
    await transaction(() async {
      await delete(transactions).go();
      await delete(categories).go();
      // Re-populate default categories
      await batch((b) {
        b.insertAll(categories, [
          CategoriesCompanion.insert(name: 'Salary', icon: 'payments', colorValue: 0xFF4CAF50, isIncome: true),
          CategoriesCompanion.insert(name: 'Investments', icon: 'trending_up', colorValue: 0xFF2196F3, isIncome: true),
          CategoriesCompanion.insert(name: 'Refunds', icon: 'history', colorValue: 0xFF00BCD4, isIncome: true),
          CategoriesCompanion.insert(name: 'Food & Dining', icon: 'restaurant', colorValue: 0xFFFF9800, isIncome: false),
          CategoriesCompanion.insert(name: 'Shopping', icon: 'shopping_bag', colorValue: 0xFFE91E63, isIncome: false),
          CategoriesCompanion.insert(name: 'Transportation', icon: 'directions_car', colorValue: 0xFF03A9F4, isIncome: false),
          CategoriesCompanion.insert(name: 'Bills & Utilities', icon: 'receipt_long', colorValue: 0xFF9C27B0, isIncome: false),
          CategoriesCompanion.insert(name: 'Entertainment', icon: 'sports_esports', colorValue: 0xFFFF5722, isIncome: false),
          CategoriesCompanion.insert(name: 'Healthcare', icon: 'medical_services', colorValue: 0xFFE53935, isIncome: false),
          CategoriesCompanion.insert(name: 'Education', icon: 'school', colorValue: 0xFF795548, isIncome: false),
        ]);
      });
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'ledger_lite.db'));
    return NativeDatabase.createInBackground(file);
  });
}
