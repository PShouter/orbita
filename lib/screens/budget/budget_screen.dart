import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/budget_provider.dart';
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
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF07090E) : const Color(0xFFF6F8FA);
    final cardBg = isDark ? const Color(0xFF131826) : Colors.white;
    final textPrimary =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    final budget = ref.watch(budgetProvider);
    final notifier = ref.read(budgetProvider.notifier);

    final pages = [
      _buildHomePage(
        budget,
        notifier,
        bg,
        cardBg,
        textPrimary,
        textSecondary,
        borderColor,
      ),
      _buildAccountsPage(
        budget,
        notifier,
        bg,
        cardBg,
        textPrimary,
        textSecondary,
        borderColor,
      ),
      _buildOperationsPage(
        budget,
        notifier,
        bg,
        cardBg,
        textPrimary,
        textSecondary,
        borderColor,
      ),
      _buildAnalyticsPage(
        budget,
        bg,
        cardBg,
        textPrimary,
        textSecondary,
        borderColor,
      ),
      _buildMorePage(
        budget,
        notifier,
        bg,
        cardBg,
        textPrimary,
        textSecondary,
        borderColor,
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          widget.onExitBudget();
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(child: pages[_currentNavIndex]),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C0F1A) : Colors.white,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentNavIndex,
            onTap: (idx) => setState(() => _currentNavIndex = idx),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: const Color(0xFF8B5CF6),
            unselectedItemColor: textSecondary,
            selectedFontSize: 11,
            unselectedFontSize: 10,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
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
    Color bg,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
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
                              color: textPrimary,
                            ),
                            onPressed: widget.onExitBudget,
                          ),
                          Text(
                            formattedMonthYear,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              _hideBalances
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                              color: textSecondary,
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
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              '${budget.daysLeftInMonth} дн. до конца',
                              style: const TextStyle(
                                color: Color(0xFFC4B5FD),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildFreeMoneyCard(budget, cardBg, borderColor),
                      const SizedBox(height: 14),
                      TabBar(
                        indicatorColor: const Color(0xFF8B5CF6),
                        indicatorWeight: 3,
                        labelColor: const Color(0xFF8B5CF6),
                        unselectedLabelColor: textSecondary,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
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
                  cardBg,
                  borderColor,
                  textPrimary,
                  textSecondary,
                  currency: budget.currency,
                  isExpense: true,
                  emptyText: 'Нет последних расходов',
                ),
                _buildTransactionsSubList(
                  budget.recentIncomes,
                  notifier,
                  cardBg,
                  borderColor,
                  textPrimary,
                  textSecondary,
                  currency: budget.currency,
                  isExpense: false,
                  emptyText: 'Нет последних доходов',
                ),
                _buildTransactionsSubList(
                  budget.plannedExpenseList,
                  notifier,
                  cardBg,
                  borderColor,
                  textPrimary,
                  textSecondary,
                  currency: budget.currency,
                  isExpense: true,
                  emptyText: 'План расходов пуст',
                ),
                _buildTransactionsSubList(
                  budget.plannedIncomeList,
                  notifier,
                  cardBg,
                  borderColor,
                  textPrimary,
                  textSecondary,
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
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.add, size: 28),
              onPressed: () =>
                  _openTransactionDialog(context, notifier, budget),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeMoneyCard(
    BudgetState budget,
    Color cardBg,
    Color borderColor,
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
        color: const Color(0xFF0B141C),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🧘 ', style: TextStyle(fontSize: 16)),
                  Text(
                    'СВОБОДНЫЕ ДЕНЬГИ',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Прогноз на ${lastDay.day} $monthShort',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.info_outline, size: 14, color: Colors.grey),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Свободно до конца периода',
                    style: TextStyle(
                      color: Color(0xFF10B981),
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
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Безопасно в день',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(
                  flex: fAcc,
                  child: Container(height: 6, color: const Color(0xFF38BDF8)),
                ),
                Expanded(
                  flex: fInc,
                  child: Container(height: 6, color: const Color(0xFF10B981)),
                ),
                Expanded(
                  flex: fDeb,
                  child: Container(height: 6, color: const Color(0xFFF59E0B)),
                ),
                Expanded(
                  flex: fPlan,
                  child: Container(height: 6, color: const Color(0xFF8B5CF6)),
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
                  const Color(0xFF38BDF8),
                  Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBalanceRow(
                  'Ожидаемый доход:',
                  '+${_formatAmount(budget.expectedIncome, cur)}',
                  const Color(0xFF10B981),
                  const Color(0xFF10B981),
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
                  const Color(0xFFFBBF24),
                  const Color(0xFFFBBF24),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBalanceRow(
                  'План расходов:',
                  '-${_formatAmount(budget.plannedExpenses, cur)}',
                  const Color(0xFF8B5CF6),
                  const Color(0xFFC4B5FD),
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
  ) {
    return Row(
      children: [
        Icon(Icons.circle, size: 7, color: dotColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          value,
          style: TextStyle(
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
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary, {
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
            style: TextStyle(fontSize: 13, color: textSecondary),
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
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
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
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$cat • ${DateFormat('d MMM', 'ru').format(date)}',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                _hideBalances
                    ? '•••• $currency'
                    : '${isExpense ? '-' : '+'}${amount.toInt()} $currency',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isExpense
                      ? const Color(0xFFF87171)
                      : const Color(0xFF34D399),
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
    Color bg,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
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
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textPrimary,
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
                cardBg,
                borderColor,
                textPrimary,
                textSecondary,
              ),
              const SizedBox(height: 14),
              _buildAccountSection(
                '2. Накопления',
                savings,
                'saving',
                budget.currency,
                notifier,
                cardBg,
                borderColor,
                textPrimary,
                textSecondary,
              ),
              const SizedBox(height: 14),
              _buildAccountSection(
                '3. Долги',
                debts,
                'debt',
                budget.currency,
                notifier,
                cardBg,
                borderColor,
                textPrimary,
                textSecondary,
              ),
              const SizedBox(height: 14),
              _buildAccountSection(
                '4. Кредиты',
                credits,
                'credit',
                budget.currency,
                notifier,
                cardBg,
                borderColor,
                textPrimary,
                textSecondary,
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
                foregroundColor: const Color(0xFF8B5CF6),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'добавить карту, вклад, кредит',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () => _openCreateAccountDialog(context, notifier),
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
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            InkWell(
              onTap: () => _openCreateAccountDialog(
                context,
                notifier,
                initialType: defaultType,
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: Color(0xFF8B5CF6),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Создать в этом разделе',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8B5CF6),
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
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _hideBalances
                          ? '•••• $currency'
                          : '${bal.toInt()} $currency',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
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
    Color bg,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
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
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('⚡ ', style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Text(
                          'У вас есть запланированные задачи на сегодня (${budget.todayTasks.length})',
                          style: const TextStyle(
                            color: Color(0xFFDDD6FE),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              TabBar(
                indicatorColor: const Color(0xFF8B5CF6),
                labelColor: const Color(0xFF8B5CF6),
                unselectedLabelColor: textSecondary,
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
                      cardBg,
                      borderColor,
                      textPrimary,
                      textSecondary,
                    ),
                    _buildEditableTxList(
                      budget.missedOperations,
                      notifier,
                      budget.currency,
                      cardBg,
                      borderColor,
                      textPrimary,
                      textSecondary,
                    ),
                    _buildEditableTxList(
                      budget.futureOperations,
                      notifier,
                      budget.currency,
                      cardBg,
                      borderColor,
                      textPrimary,
                      textSecondary,
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
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.add, size: 28),
              onPressed: () =>
                  _openTransactionDialog(context, notifier, budget),
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
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'Операций нет',
          style: TextStyle(color: textSecondary, fontSize: 13),
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
          borderRadius: BorderRadius.circular(16),
          onTap: () =>
              _openTransactionDialog(context, notifier, budget, existingTx: tx),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
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
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${tx['category']} • ${DateFormat('d MMM yyyy', 'ru').format(date)}',
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  _hideBalances
                      ? '•••• $currency'
                      : '${isExp ? '-' : '+'}${amt.toInt()} $currency',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isExp
                        ? const Color(0xFFF87171)
                        : const Color(0xFF34D399),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.redAccent,
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
    Color bg,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
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
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Text(
                'Всего потрачено',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                _hideBalances
                    ? '•••• ${budget.currency}'
                    : '${totalExp.toInt()} ${budget.currency}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              if (sortedCats.isEmpty)
                Text(
                  'Недостаточно данных для графика',
                  style: TextStyle(color: textSecondary, fontSize: 12),
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
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              _hideBalances
                                  ? '•••• ${budget.currency}'
                                  : '${e.value.toInt()} ${budget.currency} (${(pct * 100).toInt()}%)',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: borderColor,
                            color: const Color(0xFF8B5CF6),
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
    Color bg,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Управление Бюджетом',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.settings_outlined,
                  color: Color(0xFF8B5CF6),
                ),
                title: Text(
                  'Настройки бюджета',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Валюта, зарплатный день, лимиты и напоминания',
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          BudgetSettingsScreen(isDarkMode: widget.isDarkMode),
                    ),
                  );
                  _loadPreferences();
                },
              ),
              Divider(height: 1, color: borderColor),
              ListTile(
                leading: const Icon(
                  Icons.category_outlined,
                  color: Color(0xFF38BDF8),
                ),
                title: Text(
                  'Категории',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Настроить категории расходов и доходов',
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => _openCategoriesSheet(context, budget, notifier),
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
    BudgetState budget, {
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
    bool isPlanned =
        existingTx != null ? (existingTx['is_planned'] == 1) : false;
    DateTime selectedDate =
        existingTx != null ? (existingTx['date'] as DateTime) : DateTime.now();

    List<Map<String, dynamic>> availableCats =
        budget.categories.where((c) => c['type'] == type).toList();
    String category = existingTx?['category'] ??
        (availableCats.isNotEmpty ? availableCats.first['name'] : 'Другое');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF131826) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) {
          availableCats =
              budget.categories.where((c) => c['type'] == type).toList();

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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Расход')),
                          selected: type == 'expense',
                          selectedColor: Colors.redAccent.withValues(
                            alpha: 0.25,
                          ),
                          onSelected: (v) => setMState(() {
                            type = 'expense';
                            final cats = budget.categories
                                .where((c) => c['type'] == 'expense')
                                .toList();
                            category =
                                cats.isNotEmpty ? cats.first['name'] : 'Другое';
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Доход')),
                          selected: type == 'income',
                          selectedColor:
                              const Color(0xFF10B981).withValues(alpha: 0.25),
                          onSelected: (v) => setMState(() {
                            type = 'income';
                            final cats = budget.categories
                                .where((c) => c['type'] == 'income')
                                .toList();
                            category =
                                cats.isNotEmpty ? cats.first['name'] : 'Другое';
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Запланировать операцию',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Операция попадет в будущий план на выбранную дату',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: isPlanned,
                    onChanged: (v) => setMState(() => isPlanned = v),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
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
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_month,
                                size: 18,
                                color: Color(0xFF8B5CF6),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isPlanned ? 'Дата плана:' : 'Дата операции:',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          Text(
                            DateFormat(
                              'd MMMM yyyy',
                              'ru',
                            ).format(selectedDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF8B5CF6),
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
                    decoration: InputDecoration(
                      labelText: 'Сумма (${budget.currency})',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Название (например: Кофе / Зарплата)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue:
                        availableCats.any((c) => c['name'] == category)
                            ? category
                            : (availableCats.isNotEmpty
                                ? availableCats.first['name']
                                : null),
                    decoration: const InputDecoration(
                      labelText: 'Категория',
                      border: OutlineInputBorder(),
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
                        backgroundColor: const Color(0xFF7C3AED),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
    BudgetNotifier notifier, {
    String initialType = 'card',
  }) {
    final nameCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0');
    String type = initialType;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor:
              widget.isDarkMode ? const Color(0xFF131826) : Colors.white,
          title: const Text('Новый счет'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Название счета / карты',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: balCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Баланс (${ref.read(budgetProvider).currency})',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Тип'),
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
              child: const Text('Отмена'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final bal = double.tryParse(balCtrl.text.trim()) ?? 0.0;
                if (name.isNotEmpty) {
                  notifier.addAccount(name: name, type: type, balance: bal);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Создать'),
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
  ) {
    final nameCtrl = TextEditingController();
    String activeType = 'expense';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF131826) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      const Text(
                        'Управление категориями',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
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
                              selectedColor: Colors.redAccent.withValues(
                                alpha: 0.25,
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
                              selectedColor: const Color(0xFF10B981)
                                  .withValues(alpha: 0.25),
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
                              decoration: InputDecoration(
                                labelText: activeType == 'expense'
                                    ? 'Новая категория расхода'
                                    : 'Новая категория дохода',
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: Color(0xFF8B5CF6),
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
                            ? const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text(
                                    'Нет категорий в этом разделе',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: cats.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final c = cats[i];
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      c['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                            color: Color(0xFF38BDF8),
                                          ),
                                          onPressed: () async {
                                            await _showEditCategoryDialog(
                                              context,
                                              notifier,
                                              c['id'],
                                              c['name'],
                                            );
                                            setCState(() {});
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.redAccent,
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
  ) async {
    final editCtrl = TextEditingController(text: currentName);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            widget.isDarkMode ? const Color(0xFF131826) : Colors.white,
        title: const Text('Редактировать категорию'),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Название категории'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            onPressed: () async {
              final newName = editCtrl.text.trim();
              if (newName.isNotEmpty) {
                await notifier.editCategory(id: id, newName: newName);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
