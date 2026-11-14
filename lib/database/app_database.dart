import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_settings_model.dart';
import '../models/transaction_model.dart';
import '../models/recurring_payment_model.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('safe_to_spend.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        initial_balance REAL NOT NULL DEFAULT 0.0,
        current_balance REAL NOT NULL DEFAULT 0.0,
        currency_symbol TEXT NOT NULL DEFAULT '₹',
        is_biometric_enabled INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('INCOME', 'EXPENSE')),
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE recurring_payments (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        frequency TEXT NOT NULL CHECK (frequency IN ('DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY')),
        next_payment_date TEXT NOT NULL,
        end_date TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category TEXT UNIQUE NOT NULL,
        monthly_limit REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE savings_goals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        saved_amount REAL NOT NULL DEFAULT 0.0,
        target_date TEXT
      )
    ''');

    // Insert default settings row
    await db.insert('user_settings', {
      'id': 1,
      'initial_balance': 0.0,
      'current_balance': 0.0,
      'currency_symbol': '₹',
      'is_biometric_enabled': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // Settings Queries
  Future<UserSettings> getUserSettings() async {
    final db = await instance.database;
    final maps = await db.query('user_settings', where: 'id = 1');
    if (maps.isNotEmpty) {
      return UserSettings.fromMap(maps.first);
    }
    return UserSettings(
      initialBalance: 0,
      currentBalance: 0,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> updateUserSettings(UserSettings settings) async {
    final db = await instance.database;
    await db.update(
      'user_settings',
      settings.toMap(),
      where: 'id = 1',
    );
  }

  // Transaction Queries
  Future<void> insertTransaction(TransactionModel transaction) async {
    final db = await instance.database;
    await db.insert('transactions', transaction.toMap());

    // Update current balance automatically
    final settings = await getUserSettings();
    final newBalance = transaction.type == TransactionType.income
        ? settings.currentBalance + transaction.amount
        : settings.currentBalance - transaction.amount;

    await updateUserSettings(settings.copyWith(
      currentBalance: newBalance,
      updatedAt: DateTime.now(),
    ));
  }

  Future<List<TransactionModel>> getTransactions() async {
    final db = await instance.database;
    final maps = await db.query('transactions', orderBy: 'date DESC');
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  // Recurring Payments Queries
  Future<void> insertRecurringPayment(RecurringPaymentModel payment) async {
    final db = await instance.database;
    await db.insert('recurring_payments', payment.toMap());
  }

  Future<List<RecurringPaymentModel>> getRecurringPayments() async {
    final db = await instance.database;
    final maps = await db.query('recurring_payments');
    return maps.map((map) => RecurringPaymentModel.fromMap(map)).toList();
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
