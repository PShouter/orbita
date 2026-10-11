import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/budget_provider.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;
  final VoidCallback onExitBudget;

  const BudgetScreen({
    super.key,
    required this.isDarkMode,
    required this.onExitBudget,
  });

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod =
      'Этот месяц'; // 'Этот месяц', 'Прошлый месяц', 'Все время'

  static const Map<String, IconData> _categoryIcons = {
    'Продукты': Icons.shopping_basket_outlined,
    'Кафе и рестораны': Icons.restaurant_outlined,
    'Транспорт': Icons.directions_car_outlined,
    'Жилье и ЖКХ': Icons.home_outlined,
    'Здоровье': Icons.medical_services_outlined,
    'Развлечения': Icons.sports_esports_outlined,
    'Покупки': Icons.shopping_bag_outlined,
    'Зарплата': Icons.payments_outlined,
    'Инвестиции': Icons.trending_up_outlined,
    'Другое': Icons.category_outlined,
  };

  static const Map<String, Color> _categoryColors = {
    'Продукты': Color(0xFF4CAF50),
    'Кафе и рестораны': Color(0xFFFF9800),
    'Транспорт': Color(0xFF03A9F4),
    'Жилье и ЖКХ': Color(0xFF9C27B0),
    'Здоровье': Color(0xFFE91E63),
    'Развлечения': Color(0xFFFF5722),
    'Покупки': Color(0xFF00BCD4),
    'Зарплата': Color(0xFF2E7D32),
    'Инвестиции': Color(0xFF3F51B5),
    'Другое': Color(0xFF607D8B),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgetState = ref.watch(budgetProvider);
    final notifier = ref.read(budgetProvider.notifier);

    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final textSecondary = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

    // Группировка расходов по категориям для круговой диаграммы и аналитики
    final Map<String, double> expensesByCategory = {};
    for (final tx in budgetState.transactions) {
      if (tx['type'] == 'expense') {
        final cat = tx['category'] ?? 'Другое';
        final amount = (tx['amount'] is num)
            ? (tx['amount'] as num).toDouble()
            : 0.0;
        expensesByCategory[cat] = (expensesByCategory[cat] ?? 0.0) + amount;
      }
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: textPrimary,
          onPressed: widget.onExitBudget,
        ),
        title: Text(
          'Бюджет',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.calendar_today_outlined,
              size: 20,
              color: textPrimary,
            ),
            initialValue: _selectedPeriod,
            onSelected: (v) => setState(() => _selectedPeriod = v),
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'Этот месяц',
                child: Text('Этот месяц'),
              ),
              const PopupMenuItem(
                value: 'Прошлый месяц',
                child: Text('Прошлый месяц'),
              ),
              const PopupMenuItem(value: 'Все время', child: Text('Все время')),
            ],
          ),
          IconButton(
            tooltip: 'Добавить операцию',
            icon: const Icon(
              Icons.add_circle,
              color: Color(0xFF38BDF8),
              size: 26,
            ),
            onPressed: () => _openAddTransactionDialog(context, notifier),
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Премиальная карточка сводки с градиентом
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1E3A8A),
                          Color(0xFF2563EB),
                          Color(0xFF38BDF8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB)
                              .withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'СВОБОДНЫЙ ОСТАТОК',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _selectedPeriod,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${budgetState.balance.toStringAsFixed(0)} ₽',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.greenAccent,
                                      child: Icon(
                                        Icons.arrow_downward,
                                        color: Colors.black87,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Доходы',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 10,
                                            ),
                                          ),
                                          Text(
                                            '+${budgetState.totalIncome.toStringAsFixed(0)} ₽',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.redAccent,
                                      child: Icon(
                                        Icons.arrow_upward,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Расходы',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 10,
                                            ),
                                          ),
                                          Text(
                                            '-${budgetState.totalExpense.toStringAsFixed(0)} ₽',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Переключатель вкладок «Операции» и «Аналитика по категориям»
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFF38BDF8),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: const Color(0xFF38BDF8),
                      unselectedLabelColor: textSecondary,
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      tabs: const [
                        Tab(text: 'Транзакции'),
                        Tab(text: 'Категории'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Вкладка 1: Список операций с группировкой
            _buildTransactionsList(
              budgetState,
              notifier,
              cardBg,
              borderColor,
              textPrimary,
              textSecondary,
            ),

            // Вкладка 2: Аналитика расходов по категориям
            _buildCategoriesAnalytics(
              expensesByCategory,
              budgetState.totalExpense,
              cardBg,
              borderColor,
              textPrimary,
              textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList(
    BudgetState budgetState,
    BudgetNotifier notifier,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (budgetState.transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Colors.grey.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 10),
            Text(
              'Нет операций',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Нажмите «+», чтобы внести доход или расход',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: budgetState.transactions.length,
      itemBuilder: (ctx, i) {
        final tx = budgetState.transactions[i];
        final isIncome = tx['type'] == 'income';
        final amount = (tx['amount'] is num)
            ? (tx['amount'] as num).toDouble()
            : 0.0;
        final d = tx['date'] as DateTime;
        final cat = tx['category'] ?? 'Другое';

        final icon = _categoryIcons[cat] ?? Icons.category_outlined;
        final color = _categoryColors[cat] ?? Colors.blueAccent;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx['title'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$cat • ${d.day}.${d.month}.${d.year}',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                '${isIncome ? '+' : '-'}${amount.toStringAsFixed(0)} ₽',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isIncome ? const Color(0xFF10B981) : textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.redAccent,
                ),
                onPressed: () =>
                    notifier.deleteTransaction(tx['id'].toString()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoriesAnalytics(
    Map<String, double> expensesByCategory,
    double totalExpense,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (expensesByCategory.isEmpty) {
      return Center(
        child: Text(
          'Нет расходов для аналитики',
          style: TextStyle(color: textSecondary, fontSize: 13),
        ),
      );
    }

    final sortedEntries = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: sortedEntries.map((e) {
        final cat = e.key;
        final amount = e.value;
        final pct = totalExpense > 0 ? (amount / totalExpense) : 0.0;
        final icon = _categoryIcons[cat] ?? Icons.category_outlined;
        final color = _categoryColors[cat] ?? Colors.blueAccent;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${amount.toStringAsFixed(0)} ₽',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: borderColor.withValues(alpha: 0.3),
                  color: color,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _openAddTransactionDialog(
    BuildContext context,
    BudgetNotifier notifier,
  ) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String type = 'expense';
    String category = 'Продукты';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF161B22)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Новая операция',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Переключатель Расход / Доход
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDState(() {
                          type = 'expense';
                          category = 'Продукты';
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: type == 'expense'
                                ? Colors.redAccent.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: type == 'expense'
                                  ? Colors.redAccent
                                  : Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Расход',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: type == 'expense'
                                    ? Colors.redAccent
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDState(() {
                          type = 'income';
                          category = 'Зарплата';
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: type == 'income'
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: type == 'income'
                                  ? Colors.green
                                  : Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Доход',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: type == 'income'
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Сумма',
                    suffixText: '₽',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Описание (например: Супермаркет)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Категория',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items:
                      (type == 'expense'
                              ? [
                                  'Продукты',
                                  'Кафе и рестораны',
                                  'Транспорт',
                                  'Жилье и ЖКХ',
                                  'Здоровье',
                                  'Развлечения',
                                  'Покупки',
                                  'Другое',
                                ]
                              : ['Зарплата', 'Инвестиции', 'Другое'])
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                  onChanged: (v) => setDState(() => category = v ?? category),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: type == 'expense'
                          ? const Color(0xFF2C69D1)
                          : const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final amount =
                          double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      final title = titleCtrl.text.trim().isEmpty
                          ? category
                          : titleCtrl.text.trim();
                      if (amount <= 0) return;

                      HapticFeedback.lightImpact();
                      notifier.addTransaction(
                        title: title,
                        amount: amount,
                        type: type,
                        category: category,
                        date: DateTime.now(),
                      );

                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      'Сохранить',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
