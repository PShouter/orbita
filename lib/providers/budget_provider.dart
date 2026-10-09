import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_service.dart';
import '../services/sync_service.dart';

class BudgetState {
  final List<Map<String, dynamic>> transactions;
  final double totalIncome;
  final double totalExpense;
  final double balance;

  BudgetState({
    required this.transactions,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
  });
}

class BudgetNotifier extends Notifier<BudgetState> {
  @override
  BudgetState build() {
    loadTransactions();
    return BudgetState(
      transactions: [],
      totalIncome: 0,
      totalExpense: 0,
      balance: 0,
    );
  }

  Future<void> loadTransactions() async {
    final db = await DatabaseService.instance.database;
    final res = await db.query('budget_transactions', orderBy: 'date DESC');

    final transactions = res.map((row) {
      final m = Map<String, dynamic>.from(row);
      m['date'] = DateTime.parse(m['date']);
      return m;
    }).toList();

    double income = 0;
    double expense = 0;

    for (final t in transactions) {
      final amount = (t['amount'] is num)
          ? (t['amount'] as num).toDouble()
          : 0.0;
      if (t['type'] == 'income') {
        income += amount;
      } else {
        expense += amount;
      }
    }

    state = BudgetState(
      transactions: transactions,
      totalIncome: income,
      totalExpense: expense,
      balance: income - expense,
    );
  }

  Future<void> addTransaction({
    required String title,
    required double amount,
    required String type, // 'income' или 'expense'
    required String category,
    required DateTime date,
  }) async {
    final db = await DatabaseService.instance.database;
    final nowIso = DateTime.now().toIso8601String();
    final id = 'tx_${DateTime.now().millisecondsSinceEpoch}';

    final row = {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      'category': category,
      'date': date.toIso8601String(),
      'is_synced': 0,
      'updated_at': nowIso,
    };

    await db.insert(
      'budget_transactions',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await loadTransactions();
    SyncService.instance.syncAll();
  }

  Future<void> deleteTransaction(String txId) async {
    final db = await DatabaseService.instance.database;
    await db.delete('budget_transactions', where: 'id = ?', whereArgs: [txId]);
    await db.insert('delete_queue', {
      'table_name': 'budget_transactions',
      'record_id': txId,
      'created_at': DateTime.now().toIso8601String(),
    });

    await loadTransactions();
    SyncService.instance.syncAll();
  }
}

final budgetProvider = NotifierProvider<BudgetNotifier, BudgetState>(
  BudgetNotifier.new,
);
