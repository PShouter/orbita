import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_service.dart';
import '../services/sync_service.dart';

class BudgetState {
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> transactions;

  final double totalAccountsBalance;
  final double expectedIncome;
  final double plannedExpenses;
  final double totalDebtsAndCredits;
  final double freeMoney;
  final double dailySafeLimit;
  final int daysLeftInMonth;

  double get balance => freeMoney;
  double get totalIncome => expectedIncome;
  double get totalExpense => plannedExpenses;

  final List<Map<String, dynamic>> recentExpenses;
  final List<Map<String, dynamic>> recentIncomes;
  final List<Map<String, dynamic>> plannedExpenseList;
  final List<Map<String, dynamic>> plannedIncomeList;

  final List<Map<String, dynamic>> todayTasks;
  final List<Map<String, dynamic>> missedOperations;
  final List<Map<String, dynamic>> futureOperations;

  BudgetState({
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.totalAccountsBalance,
    required this.expectedIncome,
    required this.plannedExpenses,
    required this.totalDebtsAndCredits,
    required this.freeMoney,
    required this.dailySafeLimit,
    required this.daysLeftInMonth,
    required this.recentExpenses,
    required this.recentIncomes,
    required this.plannedExpenseList,
    required this.plannedIncomeList,
    required this.todayTasks,
    required this.missedOperations,
    required this.futureOperations,
  });

  factory BudgetState.initial() {
    return BudgetState(
      accounts: const [],
      categories: const [],
      transactions: const [],
      totalAccountsBalance: 0.0,
      expectedIncome: 0.0,
      plannedExpenses: 0.0,
      totalDebtsAndCredits: 0.0,
      freeMoney: 0.0,
      dailySafeLimit: 0.0,
      daysLeftInMonth: 1,
      recentExpenses: const [],
      recentIncomes: const [],
      plannedExpenseList: const [],
      plannedIncomeList: const [],
      todayTasks: const [],
      missedOperations: const [],
      futureOperations: const [],
    );
  }
}

class BudgetNotifier extends Notifier<BudgetState> {
  @override
  BudgetState build() {
    loadAll();
    return BudgetState.initial();
  }

  Future<void> loadAll() async {
    final db = await DatabaseService.instance.database;

    final accRows = await db.query(
      'budget_accounts',
      orderBy: 'updated_at DESC',
    );
    final accounts = accRows.map((r) => Map<String, dynamic>.from(r)).toList();

    final catRows = await db.query('budget_categories', orderBy: 'name ASC');
    List<Map<String, dynamic>> categories = catRows
        .map((r) => Map<String, dynamic>.from(r))
        .toList();

    if (categories.isEmpty) {
      await _insertDefaultCategories(db);
      final reloadedCats = await db.query(
        'budget_categories',
        orderBy: 'name ASC',
      );
      categories = reloadedCats
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    }

    final txRows = await db.query('budget_transactions', orderBy: 'date DESC');
    final transactions = txRows.map((r) {
      final m = Map<String, dynamic>.from(r);
      m['date'] = DateTime.parse(m['date'] as String);
      return m;
    }).toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysLeft = lastDayOfMonth.day - now.day + 1;

    double accountsBalance = 0;
    double debtsAndCredits = 0;

    for (final acc in accounts) {
      final bal = (acc['balance'] as num?)?.toDouble() ?? 0.0;
      final type = acc['type'];
      if (type == 'card' || type == 'saving') {
        accountsBalance += bal;
      } else if (type == 'debt' || type == 'credit') {
        debtsAndCredits += bal;
      }
    }

    final List<Map<String, dynamic>> recentExp = [];
    final List<Map<String, dynamic>> recentInc = [];
    final List<Map<String, dynamic>> planExp = [];
    final List<Map<String, dynamic>> planInc = [];

    final List<Map<String, dynamic>> todayList = [];
    final List<Map<String, dynamic>> missedList = [];
    final List<Map<String, dynamic>> futureList = [];

    double expIncome = 0;
    double planExpense = 0;

    for (final t in transactions) {
      final isPlanned = (t['is_planned'] == 1);
      final isCompleted = (t['is_completed'] == 1);
      final isExpense = (t['type'] == 'expense');
      final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
      final date = t['date'] as DateTime;
      final itemDay = DateTime(date.year, date.month, date.day);

      if (!isPlanned && isCompleted) {
        if (isExpense) {
          recentExp.add(t);
        } else {
          recentInc.add(t);
        }
      } else if (isPlanned) {
        if (itemDay == today && !isCompleted) {
          todayList.add(t);
        } else if (itemDay.isBefore(today) && !isCompleted) {
          missedList.add(t);
        } else if (itemDay.isAfter(today)) {
          futureList.add(t);
        }

        if (date.year == now.year && date.month == now.month && !isCompleted) {
          if (isExpense) {
            planExpense += amount;
            planExp.add(t);
          } else {
            expIncome += amount;
            planInc.add(t);
          }
        }
      }
    }

    recentExp.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );
    recentInc.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );
    planExp.sort(
      (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
    );
    planInc.sort(
      (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
    );

    final free = accountsBalance + expIncome - debtsAndCredits - planExpense;
    final dailySafe = daysLeft > 0 ? (free / daysLeft) : 0.0;

    state = BudgetState(
      accounts: accounts,
      categories: categories,
      transactions: transactions,
      totalAccountsBalance: accountsBalance,
      expectedIncome: expIncome,
      plannedExpenses: planExpense,
      totalDebtsAndCredits: debtsAndCredits,
      freeMoney: free,
      dailySafeLimit: dailySafe,
      daysLeftInMonth: daysLeft > 0 ? daysLeft : 1,
      recentExpenses: recentExp.take(10).toList(),
      recentIncomes: recentInc.take(10).toList(),
      plannedExpenseList: planExp.take(10).toList(),
      plannedIncomeList: planInc.take(10).toList(),
      todayTasks: todayList,
      missedOperations: missedList,
      futureOperations: futureList,
    );
  }

  Future<void> _insertDefaultCategories(Database db) async {
    final defCats = [
      {
        'id': 'cat_groceries',
        'name': 'Продукты',
        'type': 'expense',
        'icon': 'shopping_basket',
        'color': 0xFF10B981,
      },
      {
        'id': 'cat_cafe',
        'name': 'Кафе и рестораны',
        'type': 'expense',
        'icon': 'restaurant',
        'color': 0xFFF59E0B,
      },
      {
        'id': 'cat_transport',
        'name': 'Транспорт',
        'type': 'expense',
        'icon': 'directions_car',
        'color': 0xFF06B6D4,
      },
      {
        'id': 'cat_housing',
        'name': 'Жилье и ЖКХ',
        'type': 'expense',
        'icon': 'home',
        'color': 0xFF8B5CF6,
      },
      {
        'id': 'cat_health',
        'name': 'Здоровье',
        'type': 'expense',
        'icon': 'medical_services',
        'color': 0xFFEC4899,
      },
      {
        'id': 'cat_fun',
        'name': 'Развлечения',
        'type': 'expense',
        'icon': 'sports_esports',
        'color': 0xFFF97316,
      },
      {
        'id': 'cat_salary',
        'name': 'Зарплата',
        'type': 'income',
        'icon': 'payments',
        'color': 0xFF10B981,
      },
      {
        'id': 'cat_invest',
        'name': 'Инвестиции',
        'type': 'income',
        'icon': 'trending_up',
        'color': 0xFF3B82F6,
      },
      {
        'id': 'cat_other',
        'name': 'Другое',
        'type': 'expense',
        'icon': 'category',
        'color': 0xFF64748B,
      },
    ];

    for (final c in defCats) {
      await db.insert('budget_categories', {
        ...c,
        'monthly_limit': 0.0,
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> addAccount({
    required String name,
    required String type,
    required double balance,
  }) async {
    final db = await DatabaseService.instance.database;
    final id = 'acc_${DateTime.now().millisecondsSinceEpoch}';
    final nowIso = DateTime.now().toIso8601String();

    await db.insert('budget_accounts', {
      'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'currency': '₽',
      'color': 0xFF7C3AED,
      'is_synced': 0,
      'updated_at': nowIso,
    });
    await loadAll();
    SyncService.instance.syncAll();
  }

  Future<void> addCategory({required String name, required String type}) async {
    final db = await DatabaseService.instance.database;
    final id = 'bcat_${DateTime.now().millisecondsSinceEpoch}';
    final nowIso = DateTime.now().toIso8601String();

    await db.insert('budget_categories', {
      'id': id,
      'name': name,
      'type': type,
      'icon': 'category',
      'color': 0xFF8B5CF6,
      'monthly_limit': 0.0,
      'is_synced': 0,
      'updated_at': nowIso,
    });
    await loadAll();
    SyncService.instance.syncAll();
  }

  Future<void> editCategory({
    required String id,
    required String newName,
  }) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      'budget_categories',
      {'name': newName, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await loadAll();
    SyncService.instance.syncAll();
  }

  Future<void> deleteCategory(String id) async {
    final db = await DatabaseService.instance.database;
    await db.delete('budget_categories', where: 'id = ?', whereArgs: [id]);
    await loadAll();
    SyncService.instance.syncAll();
  }

  Future<void> saveTransaction({
    String? id,
    required String title,
    required double amount,
    required String type,
    required String category,
    String? accountId,
    required DateTime date,
    required bool isPlanned,
    bool isCompleted = true,
  }) async {
    final db = await DatabaseService.instance.database;
    final txId = id ?? 'tx_${DateTime.now().millisecondsSinceEpoch}';
    final nowIso = DateTime.now().toIso8601String();

    final row = {
      'id': txId,
      'title': title,
      'amount': amount,
      'type': type,
      'category': category,
      'account_id': accountId,
      'date': date.toIso8601String(),
      'is_planned': isPlanned ? 1 : 0,
      'is_completed': isCompleted ? 1 : 0,
      'is_synced': 0,
      'updated_at': nowIso,
    };

    await db.insert(
      'budget_transactions',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (accountId != null && isCompleted) {
      final accRes = await db.query(
        'budget_accounts',
        where: 'id = ?',
        whereArgs: [accountId],
      );
      if (accRes.isNotEmpty) {
        final currentBal = (accRes.first['balance'] as num).toDouble();
        final newBal = (type == 'income')
            ? (currentBal + amount)
            : (currentBal - amount);
        await db.update(
          'budget_accounts',
          {'balance': newBal},
          where: 'id = ?',
          whereArgs: [accountId],
        );
      }
    }

    await loadAll();
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

    await loadAll();
    SyncService.instance.syncAll();
  }
}

final budgetProvider = NotifierProvider<BudgetNotifier, BudgetState>(
  BudgetNotifier.new,
);
