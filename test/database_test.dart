import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_lite/data/database/app_database.dart';

void main() {
  // Ensure Flutter bindings are initialized for path_provider (even if mocked/in-memory)
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;

  setUp(() {
    // Connect to a clean, transient in-memory SQLite instance for each test run
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('Database is initialized with default categories', () async {
    final categories = await database.getAllCategories();
    expect(categories.length, equals(10));
    expect(categories.any((c) => c.name == 'Salary'), isTrue);
    expect(categories.any((c) => c.name == 'Food & Dining'), isTrue);
  });

  test('Transactions can be inserted and queried reactively', () async {
    final categories = await database.getAllCategories();
    final salaryCategory = categories.firstWhere((c) => c.name == 'Salary');

    // Watch stream and verify insertions trigger updates
    final stream = database.watchTransactions();
    
    // We expect the stream to first yield an empty list, then a list of 1 transaction
    final expectation = expectLater(
      stream,
      emitsInOrder([
        isEmpty,
        predicate<List<TransactionWithCategory>>((list) {
          return list.length == 1 &&
              list.first.transaction.amount == 1500.0 &&
              list.first.category.name == 'Salary';
        }),
      ]),
    );

    await database.insertTransaction(TransactionsCompanion.insert(
      amount: 1500.0,
      description: const Value('Monthly Salary'),
      date: DateTime.now(),
      categoryId: salaryCategory.id,
      type: 'income',
    ));

    await expectation;
  });

  test('Database reset wipes all transactions and maintains default categories', () async {
    final categories = await database.getAllCategories();
    final salaryCategory = categories.firstWhere((c) => c.name == 'Salary');

    await database.insertTransaction(TransactionsCompanion.insert(
      amount: 50.0,
      description: const Value('Lunch'),
      date: DateTime.now(),
      categoryId: salaryCategory.id,
      type: 'expense',
    ));

    var txs = await database.getAllTransactions();
    expect(txs.length, equals(1));

    // Reset database
    await database.resetDatabase();

    txs = await database.getAllTransactions();
    expect(txs, isEmpty);

    final resetCategories = await database.getAllCategories();
    expect(resetCategories.length, equals(10));
  });
}
