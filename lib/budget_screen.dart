import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BudgetScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onExitBudget; // Кнопка возврата в главное меню Orbita

  const BudgetScreen({
    super.key,
    required this.isDarkMode,
    required this.onExitBudget,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  int _budgetNavIndex = 0;

  // Счета (Банки, Карты, Накопления, Долги, Кредиты)
  final List<Map<String, dynamic>> _accounts = [
    {
      'name': 'Основная карта',
      'type': 'Карта',
      'balance': 45200.0,
      'icon': Icons.credit_card,
    },
    {
      'name': 'Накопительный счет',
      'type': 'Накопления',
      'balance': 120000.0,
      'icon': Icons.savings,
    },
    {
      'name': 'Кредитная карта',
      'type': 'Кредиты',
      'balance': -15000.0,
      'icon': Icons.payment,
    },
  ];

  // Операции
  final List<Map<String, dynamic>> _operations = [
    {
      'title': 'Продукты и супермаркет',
      'amount': -2450.0,
      'category': 'Еда',
      'date': 'Сегодня',
      'isExpense': true,
    },
    {
      'title': 'Зарплата',
      'amount': 85000.0,
      'category': 'Доход',
      'date': 'Вчера',
      'isExpense': false,
    },
    {
      'title': 'Кофейня',
      'amount': -350.0,
      'category': 'Кафе',
      'date': '05.10.2026',
      'isExpense': true,
    },
  ];

  // Планы
  final List<Map<String, dynamic>> _plannedExpenses = [
    {
      'title': 'Оплата подписки Obsidian Sync',
      'amount': 800.0,
      'dueDate': '15.10.2026',
    },
    {'title': 'Аренда квартиры', 'amount': 35000.0, 'dueDate': '20.10.2026'},
  ];

  // Настройки
  bool _remindAt21 = true;
  int _startPeriodDay = 1;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final textPrimary = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D1117)
          : const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Вернуться в приложение',
          onPressed: widget.onExitBudget,
        ),
        title: Text(
          _getAppBarTitle(),
          style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
        ),
      ),
      body: _buildCurrentTab(isDark, textPrimary, cardBg, borderColor),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _budgetNavIndex,
        onTap: (i) => setState(() => _budgetNavIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF38BDF8),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Счета',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Операции',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_outlined),
            label: 'Планы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline),
            label: 'Аналитика',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'Еще'),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_budgetNavIndex) {
      case 0:
        return 'Финансы • Счета';
      case 1:
        return 'Финансы • Операции';
      case 2:
        return 'Финансы • Запланированные траты';
      case 3:
        return 'Финансы • Аналитика';
      case 4:
        return 'Финансы • Настройки';
      default:
        return 'Бюджет';
    }
  }

  Widget _buildCurrentTab(
    bool isDark,
    Color textPrimary,
    Color cardBg,
    Color borderColor,
  ) {
    switch (_budgetNavIndex) {
      case 0:
        return _buildAccountsTab(isDark, textPrimary, cardBg, borderColor);
      case 1:
        return _buildOperationsTab(isDark, textPrimary, cardBg, borderColor);
      case 2:
        return _buildPlansTab(isDark, textPrimary, cardBg, borderColor);
      case 3:
        return _buildAnalyticsTab(isDark, textPrimary, cardBg, borderColor);
      case 4:
        return _buildMoreTab(isDark, textPrimary, cardBg, borderColor);
      default:
        return const SizedBox.shrink();
    }
  }

  // --- ВКЛАДКА 1: СЧЕТА ---
  Widget _buildAccountsTab(
    bool isDark,
    Color textPrimary,
    Color cardBg,
    Color borderColor,
  ) {
    final totalBalance = _accounts.fold<double>(
      0.0,
      (sum, item) => sum + (item['balance'] as double),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Общий баланс
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2C69D1), Color(0xFF0EA5E9)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Общий капитал',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                '${totalBalance.toStringAsFixed(0)} ₽',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ваши счета и карты',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Добавить счет'),
              onPressed: _openAddAccountDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),

        ..._accounts.map((acc) {
          final isDebt = (acc['balance'] as double) < 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF38BDF8).withOpacity(0.12),
                  child: Icon(
                    acc['icon'] as IconData,
                    color: const Color(0xFF38BDF8),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        acc['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        acc['type'],
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(acc['balance'] as double).toStringAsFixed(0)} ₽',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDebt ? Colors.redAccent : const Color(0xFF4ADE80),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // --- ВКЛАДКА 2: ОПЕРАЦИИ ---
  Widget _buildOperationsTab(
    bool isDark,
    Color textPrimary,
    Color cardBg,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'История операций',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Внести'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2C69D1),
              ),
              onPressed: _openAddOperationDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._operations.map((op) {
          final isExpense = op['isExpense'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isExpense
                      ? Colors.redAccent.withOpacity(0.12)
                      : Colors.greenAccent.withOpacity(0.12),
                  child: Icon(
                    isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isExpense ? Colors.redAccent : Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        op['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        '${op['category']} • ${op['date']}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isExpense ? '' : '+'}${(op['amount'] as double).toStringAsFixed(0)} ₽',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isExpense
                        ? Colors.redAccent
                        : const Color(0xFF4ADE80),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // --- ВКЛАДКА 3: ПЛАНЫ ---
  Widget _buildPlansTab(
    bool isDark,
    Color textPrimary,
    Color cardBg,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Запланированные траты',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            FilledButton.tonal(
              onPressed: () {
                // Добавить план
              },
              child: const Text('Запланировать'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._plannedExpenses.map(
          (plan) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan['title'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Дата списания: ${plan['dueDate']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                Text(
                  '${plan['amount']} ₽',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.orangeAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- ВКЛАДКА 4: АНАЛИТИКА ---
  Widget _buildAnalyticsTab(
    bool isDark,
    Color textPrimary,
    Color cardBg,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Доходы vs Расходы',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Доходы: 85 000 ₽',
                    style: TextStyle(
                      color: Color(0xFF4ADE80),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Расходы: 2 800 ₽',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: 0.95,
                  minHeight: 10,
                  backgroundColor: Colors.redAccent,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF4ADE80)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Категории расходов',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _buildCategoryBar(
          'Еда и продукты',
          2450.0,
          0.85,
          Colors.orangeAccent,
          textPrimary,
        ),
        _buildCategoryBar(
          'Кафе и перекусы',
          350.0,
          0.15,
          Colors.blueAccent,
          textPrimary,
        ),
      ],
    );
  }

  Widget _buildCategoryBar(
    String title,
    double amount,
    double percent,
    Color color,
    Color textPrimary,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 13, color: textPrimary)),
              Text(
                '${amount.toStringAsFixed(0)} ₽',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  // --- ВКЛАДКА 5: ЕЩЕ (НАСТРОЙКИ) ---
  Widget _buildMoreTab(
    bool isDark,
    Color textPrimary,
    Color cardBg,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.people_outline,
                  color: Color(0xFF38BDF8),
                ),
                title: Text(
                  'Совместный доступ',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'В разработке',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.amberAccent,
                ),
                title: Text(
                  'Напоминать о внесении операций',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Если за день не добавилось ни одной операции, придет напоминание в 21:00',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: _remindAt21,
                onChanged: (v) => setState(() => _remindAt21 = v),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.calendar_today,
                  color: Colors.greenAccent,
                ),
                title: Text(
                  'Начало расчетного периода',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Текущее число: $_startPeriodDay-е число каждого месяца',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Выбор дня
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.category_outlined,
                  color: Colors.purpleAccent,
                ),
                title: Text(
                  'Категории доходов и расходов',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Настройка списка категорий',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openAddAccountDialog() {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    String type = 'Карта';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить счет'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Название (Банк/Счет)',
              ),
            ),
            TextField(
              controller: balanceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Текущий баланс (₽)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                setState(() {
                  _accounts.add({
                    'name': nameCtrl.text.trim(),
                    'type': type,
                    'balance': double.tryParse(balanceCtrl.text) ?? 0.0,
                    'icon': Icons.account_balance,
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _openAddOperationDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    bool isExpense = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Внести операцию'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Расход'),
                    selected: isExpense,
                    onSelected: (v) => setDState(() => isExpense = true),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Доход'),
                    selected: !isExpense,
                    onSelected: (v) => setDState(() => isExpense = false),
                  ),
                ],
              ),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Что купили / Источник',
                ),
              ),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Сумма (₽)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.isNotEmpty && amountCtrl.text.isNotEmpty) {
                  final val = double.tryParse(amountCtrl.text) ?? 0.0;
                  setState(() {
                    _operations.insert(0, {
                      'title': titleCtrl.text.trim(),
                      'amount': isExpense ? -val : val,
                      'category': isExpense ? 'Разное' : 'Доход',
                      'date': 'Сегодня',
                      'isExpense': isExpense,
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Записать'),
            ),
          ],
        ),
      ),
    );
  }
}
