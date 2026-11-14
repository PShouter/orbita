import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/budget_provider.dart';
import '../../theme/app_theme.dart';
import '../settings/sections/budget_settings_screen.dart';

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

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  int _currentNavIndex = 0;
  bool _hideBalances = false;
  bool _showDailySafeLimit = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hideBalances = prefs.getBool('budget_hide_balances') ?? false;
        _showDailySafeLimit = prefs.getBool('budget_show_daily_limit') ?? true;
      });
    }
  }

  String _formatAmount(double amount, String currency) {
    if (_hideBalances) return '•••• $currency';
    final fmt = NumberFormat("#,##0", "ru_RU");
    return '${fmt.format(amount.toInt())} $currency';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final budget = ref.watch(budgetProvider);
    final notifier = ref.read(budgetProvider.notifier);

    final pages = [
      _buildHomePage(budget, notifier, colors),
      _buildAccountsPage(budget, notifier, colors),
      _buildOperationsPage(budget, notifier, colors),
      _buildAnalyticsPage(budget, colors),
      _buildMorePage(budget, notifier, colors),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          widget.onExitBudget();
        }
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(child: pages[_currentNavIndex]),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: colors.card,
            border: Border(top: BorderSide(color: colors.nested)),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentNavIndex,
            onTap: (idx) => setState(() => _currentNavIndex = idx),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: colors.accent,
            unselectedItemColor: colors.text.withValues(alpha: 0.5),
            selectedFontSize: 11,
            unselectedFontSize: 10,
            selectedLabelStyle: const TextStyle(
              fontFamily: 'Onest',
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Onest',
              fontWeight: FontWeight.w500,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                label: 'Главная',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.credit_card_outlined),
                label: 'Счета',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.swap_horiz_outlined),
                label: 'Операции',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.pie_chart_outline_rounded),
                label: 'Аналитика',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.more_horiz_rounded),
                label: 'Еще',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. СТРАНИЦА: ГЛАВНАЯ
  // ==========================================
  Widget _buildHomePage(
    BudgetState budget,
    BudgetNotifier notifier,
    AppColorsExtension colors,
  ) {
    final now = DateTime.now();
    final monthYear = DateFormat('LLLL yyyy', 'ru').format(now);
    final formattedMonthYear =
        monthYear[0].toUpperCase() + monthYear.substring(1);

    return DefaultTabController(
      length: 4,
      child: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (ctx, innerScrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new,
                              size: 18,
                              color: colors.text,
                            ),
                            onPressed: widget.onExitBudget,
                          ),
                          Text(
                            formattedMonthYear,
                            style: TextStyle(
                              fontFamily: 'Unbounded',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.text,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              _hideBalances
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                              color: colors.text.withValues(alpha: 0.6),
                            ),
                            tooltip: _hideBalances
                                ? 'Показать баланс'
                                : 'Скрыть баланс',
                            onPressed: () =>
                                setState(() => _hideBalances = !_hideBalances),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: colors.accent.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              '${budget.daysLeftInMonth} дн. до конца',
                              style: TextStyle(
                                fontFamily: 'Onest',
                                color: colors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildFreeMoneyCard(budget, colors),
                      const SizedBox(height: 14),
                      TabBar(
                        indicatorColor: colors.accent,
                        indicatorWeight: 3,
                        labelColor: colors.accent,
                        unselectedLabelColor:
                            colors.text.withValues(alpha: 0.5),
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelStyle: const TextStyle(
                          fontFamily: 'Onest',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontFamily: 'Onest',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: const [
                          Tab(text: 'Расходы'),
                          Tab(text: 'Доходы'),
                          Tab(text: 'План расходов'),
                          Tab(text: 'План доходов'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              children: [
                _buildTransactionsSubList(
                  budget.recentExpenses,
                  notifier,
                  colors,
                  currency: budget.currency,
                  isExpense: true,
                  emptyText: 'Нет последних расходов',
                ),
                _buildTransactionsSubList(
                  budget.recentIncomes,
                  notifier,
                  colors,
                  currency: budget.currency,
                  isExpense: false,
                  emptyText: 'Нет последних доходов',
                ),
                _buildTransactionsSubList(
                  budget.plannedExpenseList,
                  notifier,
                  colors,
                  currency: budget.currency,
                  isExpense: true,
                  emptyText: 'План расходов пуст',
                ),
                _buildTransactionsSubList(
                  budget.plannedIncomeList,
                  notifier,
                  colors,
                  currency: budget.currency,
                  isExpense: false,
                  emptyText: 'План доходов пуст',
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              backgroundColor: colors.accent,
              foregroundColor: colors.isDark ? Colors.black : Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add, size: 28),
              onPressed: () =>
                  _openTransactionDialog(context, notifier, budget, colors),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeMoneyCard(
    BudgetState budget,
    AppColorsExtension colors,
  ) {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final monthShort = DateFormat('LLL', 'ru').format(now);
    final cur = budget.currency;

    final fAcc = (budget.ratioAccounts * 100).toInt().clamp(1, 100);
    final fInc = (budget.ratioIncome * 100).toInt().clamp(1, 100);
    final fDeb = (budget.ratioDebts * 100).toInt().clamp(1, 100);
    final fPlan = (budget.ratioPlanned * 100).toInt().clamp(1, 100);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.nested),
        boxShadow: [
          BoxShadow(
            color: colors.nested.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🧘 ', style: TextStyle(fontSize: 16)),
                  Text(
                    'СВОБОДНЫЕ ДЕНЬГИ',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Прогноз на ${lastDay.day} $monthShort',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: colors.text.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatAmount(budget.freeMoney, cur),
                    style: TextStyle(
                      fontFamily: 'Unbounded',
                      color: colors.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Свободно до конца периода',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (_showDailySafeLimit)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _hideBalances
                          ? '•••• $cur/дн'
                          : '${budget.dailySafeLimit.toInt()} $cur/день',
                      style: TextStyle(
                        fontFamily: 'Unbounded',
                        color: colors.warning,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Безопасно в день',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Row(
              children: [
                Expanded(
                  flex: fAcc,
                  child: Container(height: 6, color: colors.accent),
                ),
                Expanded(
                  flex: fInc,
                  child: Container(height: 6, color: colors.success),
                ),
                Expanded(
                  flex: fDeb,
                  child: Container(height: 6, color: colors.warning),
                ),
                Expanded(
                  flex: fPlan,
                  child: Container(
                    height: 6,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildBalanceRow(
                  'Остаток на счетах:',
                  _formatAmount(budget.totalAccountsBalance, cur),
                  colors.accent,
                  colors.text,
                  colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBalanceRow(
                  'Ожидаемый доход:',
                  '+${_formatAmount(budget.expectedIncome, cur)}',
                  colors.success,
                  colors.success,
                  colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildBalanceRow(
                  'Счета и кредиты:',
                  '-${_formatAmount(budget.totalDebtsAndCredits, cur)}',
                  colors.warning,
                  colors.warning,
                  colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBalanceRow(
                  'План расходов:',
                  '-${_formatAmount(budget.plannedExpenses, cur)}',
                  const Color(0xFF8B5CF6),
                  colors.text.withValues(alpha: 0.9),
                  colors,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(
    String label,
    String value,
    Color dotColor,
    Color valueColor,
    AppColorsExtension colors,
  ) {
    return Row(
      children: [
        Icon(Icons.circle, size: 7, color: dotColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Onest',
              color: colors.text.withValues(alpha: 0.5),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Onest',
            color: valueColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsSubList(
    List<Map<String, dynamic>> items,
    BudgetNotifier notifier,
    AppColorsExtension colors, {
    required String currency,
    required bool isExpense,
    required String emptyText,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyText,
            style: TextStyle(
              fontFamily: 'Onest',
              fontSize: 13,
              color: colors.text.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final t = items[i];
        final date = t['date'] as DateTime;
        final amount = (t['amount'] as num).toDouble();
        final title = t['title'] ?? '';
        final cat = t['category'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.nested),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$cat • ${DateFormat('d MMM', 'ru').format(date)}',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _hideBalances
                    ? '•••• $currency'
                    : '${isExpense ? '-' : '+'}${amount.toInt()} $currency',
                style: TextStyle(
                  fontFamily: 'Onest',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isExpense ? colors.error : colors.success,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // 2. СТРАНИЦА: СЧЕТА
  // ==========================================
  Widget _buildAccountsPage(
    BudgetState budget,
    BudgetNotifier notifier,
    AppColorsExtension colors,
  ) {
    final cards = budget.accounts.where((a) => a['type'] == 'card').toList();
    final savings =
        budget.accounts.where((a) => a['type'] == 'saving').toList();
    final debts = budget.accounts.where((a) => a['type'] == 'debt').toList();
    final credits =
        budget.accounts.where((a) => a['type'] == 'credit').toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Мои Счета',
              style: TextStyle(
                fontFamily: 'Unbounded',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildAccountSection(
                '1. Счета и карты',
                cards,
                'card',
                budget.currency,
                notifier,
                colors,
              ),
              const SizedBox(height: 14),
              _buildAccountSection(
                '2. Накопления',
                savings,
                'saving',
                budget.currency,
                notifier,
                colors,
              ),
              const SizedBox(height: 14),
              _buildAccountSection(
                '3. Долги',
                debts,
                'debt',
                budget.currency,
                notifier,
                colors,
              ),
              const SizedBox(height: 14),
              _buildAccountSection(
                '4. Кредиты',
                credits,
                'credit',
                budget.currency,
                notifier,
                colors,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.accent,
                side: BorderSide(color: colors.accent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'добавить карту, вклад, кредит',
                style: TextStyle(
                  fontFamily: 'Onest',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              onPressed: () => _openCreateAccountDialog(context, notifier, colors),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection(
    String title,
    List<Map<String, dynamic>> items,
    String defaultType,
    String currency,
    BudgetNotifier notifier,
    AppColorsExtension colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.nested),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Onest',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openCreateAccountDialog(
                context,
                notifier,
                colors,
                initialType: defaultType,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: colors.accent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Создать в этом разделе',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 12,
                        color: colors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...items.map((acc) {
              final bal = (acc['balance'] as num).toDouble();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      acc['name'] ?? '',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _hideBalances
                          ? '•••• $currency'
                          : '${bal.toInt()} $currency',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ==========================================
  // 3. СТРАНИЦА: ОПЕРАЦИИ
  // ==========================================
  Widget _buildOperationsPage(
    BudgetState budget,
    BudgetNotifier notifier,
    AppColorsExtension colors,
  ) {
    return DefaultTabController(
      length: 3,
      child: Stack(
        children: [
          Column(
            children: [
              if (budget.todayTasks.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('⚡ ', style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Text(
                          'У вас есть запланированные задачи на сегодня (${budget.todayTasks.length})',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            color: colors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              TabBar(
                indicatorColor: colors.accent,
                labelColor: colors.accent,
                unselectedLabelColor: colors.text.withValues(alpha: 0.5),
                labelStyle: const TextStyle(
                  fontFamily: 'Onest',
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Onest',
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Все'),
                  Tab(text: 'Пропущенные'),
                  Tab(text: 'Будущие'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildEditableTxList(
                      budget.transactions,
                      notifier,
                      budget.currency,
                      colors,
                    ),
                    _buildEditableTxList(
                      budget.missedOperations,
                      notifier,
                      budget.currency,
                      colors,
                    ),
                    _buildEditableTxList(
                      budget.futureOperations,
                      notifier,
                      budget.currency,
                      colors,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              backgroundColor: colors.accent,
              foregroundColor: colors.isDark ? Colors.black : Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add, size: 28),
              onPressed: () =>
                  _openTransactionDialog(context, notifier, budget, colors),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableTxList(
    List<Map<String, dynamic>> list,
    BudgetNotifier notifier,
    String currency,
    AppColorsExtension colors,
  ) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'Операций нет',
          style: TextStyle(
            fontFamily: 'Onest',
            color: colors.text.withValues(alpha: 0.5),
            fontSize: 13,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final tx = list[i];
        final isExp = tx['type'] == 'expense';
        final amt = (tx['amount'] as num).toDouble();
        final date = tx['date'] as DateTime;
        final budget = ref.read(budgetProvider);

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openTransactionDialog(
            context,
            notifier,
            budget,
            colors,
            existingTx: tx,
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.nested),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx['title'] ?? '',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${tx['category']} • ${DateFormat('d MMM yyyy', 'ru').format(date)}',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          color: colors.text.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _hideBalances
                      ? '•••• $currency'
                      : '${isExp ? '-' : '+'}${amt.toInt()} $currency',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isExp ? colors.error : colors.success,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: colors.error,
                  ),
                  onPressed: () => notifier.deleteTransaction(tx['id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // 4. СТРАНИЦА: АНАЛИТИКА
  // ==========================================
  Widget _buildAnalyticsPage(
    BudgetState budget,
    AppColorsExtension colors,
  ) {
    final Map<String, double> expensesByCategory = {};
    double totalExp = 0;

    for (final tx in budget.transactions) {
      if (tx['type'] == 'expense' && tx['is_completed'] == 1) {
        final cat = tx['category'] ?? 'Другое';
        final amount = (tx['amount'] as num).toDouble();
        expensesByCategory[cat] = (expensesByCategory[cat] ?? 0.0) + amount;
        totalExp += amount;
      }
    }

    final sortedCats = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Аналитика трат',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.nested),
          ),
          child: Column(
            children: [
              Text(
                'Всего потрачено',
                style: TextStyle(
                  fontFamily: 'Onest',
                  color: colors.text.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _hideBalances
                    ? '•••• ${budget.currency}'
                    : '${totalExp.toInt()} ${budget.currency}',
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 16),
              if (sortedCats.isEmpty)
                Text(
                  'Недостаточно данных для графика',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                )
              else
                ...sortedCats.map((e) {
                  final pct = totalExp > 0 ? (e.value / totalExp) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              e.key,
                              style: TextStyle(
                                fontFamily: 'Onest',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: colors.text,
                              ),
                            ),
                            Text(
                              _hideBalances
                                  ? '•••• ${budget.currency}'
                                  : '${e.value.toInt()} ${budget.currency} (${(pct * 100).toInt()}%)',
                              style: TextStyle(
                                fontFamily: 'Onest',
                                color: colors.text.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: colors.nested,
                            color: colors.accent,
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 5. СТРАНИЦА: ЕЩЕ
  // ==========================================
  Widget _buildMorePage(
    BudgetState budget,
    BudgetNotifier notifier,
    AppColorsExtension colors,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Управление Бюджетом',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.nested),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.settings_outlined,
                  color: colors.accent,
                ),
                title: Text(
                  'Настройки бюджета',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
                subtitle: Text(
                  'Валюта, зарплатный день, лимиты и напоминания',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: colors.text.withValues(alpha: 0.4),
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          BudgetSettingsScreen(isDarkMode: colors.isDark),
                    ),
                  );
                  _loadPreferences();
                },
              ),
              Divider(height: 1, color: colors.nested),
              ListTile(
                leading: Icon(
                  Icons.category_outlined,
                  color: colors.accent,
                ),
                title: Text(
                  'Категории',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
                subtitle: Text(
                  'Настроить категории расходов и доходов',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: colors.text.withValues(alpha: 0.4),
                ),
                onTap: () => _openCategoriesSheet(context, budget, notifier, colors),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ДИАЛОГИ И МОДАЛКИ
  // ==========================================

  void _openTransactionDialog(
    BuildContext context,
    BudgetNotifier notifier,
    BudgetState budget,
    AppColorsExtension colors, {
    Map<String, dynamic>? existingTx,
  }) {
    final titleCtrl = TextEditingController(text: existingTx?['title'] ?? '');
    final amountCtrl = TextEditingController(
      text: existingTx != null
          ? (existingTx['amount'] as num).toInt().toString()
          : '',
    );
    String type = existingTx?['type'] ?? 'expense';
    String? accountId = existingTx?['account_id'];
    bool isPlanned = existingTx != null
        ? (existingTx['is_planned'] == 1)
        : false;
    DateTime selectedDate = existingTx != null
        ? (existingTx['date'] as DateTime)
        : DateTime.now();

    List<Map<String, dynamic>> availableCats = budget.categories
        .where((c) => c['type'] == type)
        .toList();
    String category = existingTx?['category'] ??
        (availableCats.isNotEmpty ? availableCats.first['name'] : 'Другое');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) {
          availableCats = budget.categories
              .where((c) => c['type'] == type)
              .toList();

          return Padding(
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
                  Text(
                    existingTx != null
                        ? 'Редактировать операцию'
                        : 'Новая операция',
                    style: TextStyle(
                      fontFamily: 'Unbounded',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: Text(
                              'Расход',
                              style: TextStyle(fontFamily: 'Onest'),
                            ),
                          ),
                          selected: type == 'expense',
                          selectedColor: colors.error.withValues(alpha: 0.2),
                          backgroundColor: colors.nested.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                            side: BorderSide(
                              color: type == 'expense'
                                  ? colors.error
                                  : colors.nested,
                            ),
                          ),
                          onSelected: (v) => setMState(() {
                            type = 'expense';
                            final cats = budget.categories
                                .where((c) => c['type'] == 'expense')
                                .toList();
                            category = cats.isNotEmpty
                                ? cats.first['name']
                                : 'Другое';
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: Text(
                              'Доход',
                              style: TextStyle(fontFamily: 'Onest'),
                            ),
                          ),
                          selected: type == 'income',
                          selectedColor: colors.success.withValues(alpha: 0.2),
                          backgroundColor: colors.nested.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                            side: BorderSide(
                              color: type == 'income'
                                  ? colors.success
                                  : colors.nested,
                            ),
                          ),
                          onSelected: (v) => setMState(() {
                            type = 'income';
                            final cats = budget.categories
                                .where((c) => c['type'] == 'income')
                                .toList();
                            category = cats.isNotEmpty
                                ? cats.first['name']
                                : 'Другое';
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: colors.accent,
                    title: Text(
                      'Запланировать операцию',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                    subtitle: Text(
                      'Операция попадет в будущий план на выбранную дату',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 11,
                        color: colors.text.withValues(alpha: 0.5),
                      ),
                    ),
                    value: isPlanned,
                    onChanged: (v) => setMState(() => isPlanned = v),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setMState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.nested.withValues(alpha: 0.3),
                        border: Border.all(color: colors.nested),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_month,
                                size: 18,
                                color: colors.accent,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isPlanned ? 'Дата плана:' : 'Дата операции:',
                                style: TextStyle(
                                  fontFamily: 'Onest',
                                  fontSize: 13,
                                  color: colors.text,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            DateFormat('d MMMM yyyy', 'ru').format(selectedDate),
                            style: TextStyle(
                              fontFamily: 'Onest',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: colors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontFamily: 'Onest', color: colors.text),
                    decoration: InputDecoration(
                      labelText: 'Сумма (${budget.currency})',
                      labelStyle: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: colors.nested.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.nested),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.nested),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.accent, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(fontFamily: 'Onest', color: colors.text),
                    decoration: InputDecoration(
                      labelText: 'Название (например: Кофе / Зарплата)',
                      labelStyle: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: colors.nested.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.nested),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.nested),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.accent, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    dropdownColor: colors.card,
                    style: TextStyle(fontFamily: 'Onest', color: colors.text),
                    initialValue:
                        availableCats.any((c) => c['name'] == category)
                            ? category
                            : (availableCats.isNotEmpty
                                ? availableCats.first['name']
                                : null),
                    decoration: InputDecoration(
                      labelText: 'Категория',
                      labelStyle: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: colors.nested.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.nested),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.nested),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.accent, width: 1.5),
                      ),
                    ),
                    items: availableCats
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['name'] as String,
                            child: Text(c['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setMState(() => category = v ?? category),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor:
                            colors.isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        final amt =
                            double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                        final t = titleCtrl.text.trim().isEmpty
                            ? category
                            : titleCtrl.text.trim();
                        if (amt <= 0) return;

                        notifier.saveTransaction(
                          id: existingTx?['id'],
                          title: t,
                          amount: amt,
                          type: type,
                          category: category,
                          accountId: accountId,
                          date: selectedDate,
                          isPlanned: isPlanned,
                          isCompleted: !isPlanned,
                        );
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Сохранить',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openCreateAccountDialog(
    BuildContext context,
    BudgetNotifier notifier,
    AppColorsExtension colors, {
    String initialType = 'card',
  }) {
    final nameCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0');
    String type = initialType;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Новый счет',
            style: TextStyle(
              fontFamily: 'Unbounded',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(fontFamily: 'Onest', color: colors.text),
                  decoration: InputDecoration(
                    labelText: 'Название счета / карты',
                    labelStyle: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: colors.nested.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.nested),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: balCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontFamily: 'Onest', color: colors.text),
                  decoration: InputDecoration(
                    labelText: 'Баланс (${ref.read(budgetProvider).currency})',
                    labelStyle: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: colors.nested.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.nested),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  dropdownColor: colors.card,
                  style: TextStyle(fontFamily: 'Onest', color: colors.text),
                  decoration: InputDecoration(
                    labelText: 'Тип',
                    labelStyle: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: colors.nested.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.nested),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'card',
                      child: Text('Счет / Карта'),
                    ),
                    DropdownMenuItem(
                      value: 'saving',
                      child: Text('Накопления'),
                    ),
                    DropdownMenuItem(value: 'debt', child: Text('Долг')),
                    DropdownMenuItem(value: 'credit', child: Text('Кредит')),
                  ],
                  onChanged: (v) => setDState(() => type = v ?? type),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Отмена',
                style: TextStyle(
                  fontFamily: 'Onest',
                  color: colors.text.withValues(alpha: 0.6),
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final bal = double.tryParse(balCtrl.text.trim()) ?? 0.0;
                if (name.isNotEmpty) {
                  notifier.addAccount(name: name, type: type, balance: bal);
                  Navigator.pop(ctx);
                }
              },
              child: const Text(
                'Создать',
                style: TextStyle(
                  fontFamily: 'Onest',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCategoriesSheet(
    BuildContext context,
    BudgetState budget,
    BudgetNotifier notifier,
    AppColorsExtension colors,
  ) {
    final nameCtrl = TextEditingController();
    String activeType = 'expense';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final currentBudget = ref.watch(budgetProvider);

          return StatefulBuilder(
            builder: (ctx, setCState) {
              final cats = currentBudget.categories
                  .where((c) => c['type'] == activeType)
                  .toList();

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Управление категориями',
                        style: TextStyle(
                          fontFamily: 'Unbounded',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(
                                child: Text('Категории расходов'),
                              ),
                              selected: activeType == 'expense',
                              selectedColor:
                                  colors.error.withValues(alpha: 0.2),
                              backgroundColor:
                                  colors.nested.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                                side: BorderSide(
                                  color: activeType == 'expense'
                                      ? colors.error
                                      : colors.nested,
                                ),
                              ),
                              onSelected: (v) =>
                                  setCState(() => activeType = 'expense'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(
                                child: Text('Категории доходов'),
                              ),
                              selected: activeType == 'income',
                              selectedColor:
                                  colors.success.withValues(alpha: 0.2),
                              backgroundColor:
                                  colors.nested.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                                side: BorderSide(
                                  color: activeType == 'income'
                                      ? colors.success
                                      : colors.nested,
                                ),
                              ),
                              onSelected: (v) =>
                                  setCState(() => activeType = 'income'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: nameCtrl,
                              style: TextStyle(
                                fontFamily: 'Onest',
                                color: colors.text,
                              ),
                              decoration: InputDecoration(
                                labelText: activeType == 'expense'
                                    ? 'Новая категория расхода'
                                    : 'Новая категория дохода',
                                labelStyle: TextStyle(
                                  fontFamily: 'Onest',
                                  color: colors.text.withValues(alpha: 0.6),
                                ),
                                isDense: true,
                                filled: true,
                                fillColor:
                                    colors.nested.withValues(alpha: 0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: colors.nested),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.add_circle,
                              color: colors.accent,
                              size: 34,
                            ),
                            onPressed: () async {
                              final n = nameCtrl.text.trim();
                              if (n.isNotEmpty) {
                                await notifier.addCategory(
                                  name: n,
                                  type: activeType,
                                );
                                nameCtrl.clear();
                                setCState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: cats.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text(
                                    'Нет категорий в этом разделе',
                                    style: TextStyle(
                                      fontFamily: 'Onest',
                                      color: colors.text.withValues(alpha: 0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: cats.length,
                                separatorBuilder: (_, __) =>
                                    Divider(height: 1, color: colors.nested),
                                itemBuilder: (ctx, i) {
                                  final c = cats[i];
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      c['name'],
                                      style: TextStyle(
                                        fontFamily: 'Onest',
                                        fontWeight: FontWeight.w600,
                                        color: colors.text,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                            color: colors.accent,
                                          ),
                                          onPressed: () async {
                                            await _showEditCategoryDialog(
                                              context,
                                              notifier,
                                              c['id'],
                                              c['name'],
                                              colors,
                                            );
                                            setCState(() {});
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: colors.error,
                                          ),
                                          onPressed: () async {
                                            await notifier.deleteCategory(
                                              c['id'],
                                            );
                                            setCState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showEditCategoryDialog(
    BuildContext context,
    BudgetNotifier notifier,
    String id,
    String currentName,
    AppColorsExtension colors,
  ) async {
    final editCtrl = TextEditingController(text: currentName);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text(
          'Редактировать категорию',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          style: TextStyle(fontFamily: 'Onest', color: colors.text),
          decoration: InputDecoration(
            labelText: 'Название категории',
            labelStyle: TextStyle(
              fontFamily: 'Onest',
              color: colors.text.withValues(alpha: 0.6),
            ),
            filled: true,
            fillColor: colors.nested.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.nested),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Отмена',
              style: TextStyle(
                fontFamily: 'Onest',
                color: colors.text.withValues(alpha: 0.6),
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () async {
              final newName = editCtrl.text.trim();
              if (newName.isNotEmpty) {
                await notifier.editCategory(id: id, newName: newName);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text(
              'Сохранить',
              style: TextStyle(
                fontFamily: 'Onest',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}