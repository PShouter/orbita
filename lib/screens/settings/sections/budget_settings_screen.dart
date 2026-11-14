import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/budget_provider.dart';
import '../../../theme/app_theme.dart';

class BudgetSettingsScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;
  const BudgetSettingsScreen({super.key, required this.isDarkMode});

  @override
  ConsumerState<BudgetSettingsScreen> createState() =>
      _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends ConsumerState<BudgetSettingsScreen> {
  String _currency = '₽';
  int _salaryDay = 1;
  bool _includeDebtsInFreeMoney = true;

  bool _showDailySafeLimit = true;
  bool _warnOnOverspend = true;

  bool _remindPlannedOps = true;
  TimeOfDay _plannedRemindTime = const TimeOfDay(hour: 9, minute: 0);
  bool _eveningExpenseCheck = true;
  TimeOfDay _eveningCheckTime = const TimeOfDay(hour: 21, minute: 0);
  String _soundTitle = 'По умолчанию (системный)';

  bool _hideBalancesOnHome = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currency = prefs.getString('budget_currency') ?? '₽';
      _salaryDay = prefs.getInt('budget_salary_day') ?? 1;
      _includeDebtsInFreeMoney = prefs.getBool('budget_include_debts') ?? true;

      _showDailySafeLimit = prefs.getBool('budget_show_daily_limit') ?? true;
      _warnOnOverspend = prefs.getBool('budget_warn_overspend') ?? true;

      _remindPlannedOps = prefs.getBool('budget_remind_planned') ?? true;
      final planTimeStr = prefs.getString('budget_planned_time') ?? '09:00';
      final planParts = planTimeStr.split(':');
      _plannedRemindTime = TimeOfDay(
        hour: int.tryParse(planParts[0]) ?? 9,
        minute: int.tryParse(planParts[1]) ?? 0,
      );

      _eveningExpenseCheck = prefs.getBool('budget_evening_check') ?? true;
      final eveTimeStr = prefs.getString('budget_evening_time') ?? '21:00';
      final eveParts = eveTimeStr.split(':');
      _eveningCheckTime = TimeOfDay(
        hour: int.tryParse(eveParts[0]) ?? 21,
        minute: int.tryParse(eveParts[1]) ?? 0,
      );

      _soundTitle = prefs.getString('budget_notif_sound_title') ??
          'По умолчанию (системный)';
      _hideBalancesOnHome = prefs.getBool('budget_hide_balances') ?? false;
    });
  }

  Future<void> _updateString(
    String key,
    String val,
    void Function() onSet,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, val);
    setState(onSet);
    ref.read(budgetProvider.notifier).loadAll();
    HapticFeedback.selectionClick();
  }

  Future<void> _updateInt(String key, int val, void Function() onSet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, val);
    setState(onSet);
    ref.read(budgetProvider.notifier).loadAll();
    HapticFeedback.selectionClick();
  }

  Future<void> _updateBool(String key, bool val, void Function() onSet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
    setState(onSet);
    ref.read(budgetProvider.notifier).loadAll();
    HapticFeedback.selectionClick();
  }

  Future<void> _pickTime({
    required TimeOfDay initialTime,
    required String prefKey,
    required void Function(TimeOfDay) onSelected,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        prefKey,
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
      );
      setState(() => onSelected(picked));
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _pickNotificationSound(AppColorsExtension colors) async {
    final options = [
      'По умолчанию (системный)',
      'Звон монет (Орбита)',
      'Колокольчик банка',
      'Электронный клик',
      'Без звука',
    ];

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Сигнал напоминания',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((sound) {
            return RadioListTile<String>(
              title: Text(
                sound,
                style: TextStyle(fontFamily: 'Onest', color: colors.text),
              ),
              value: sound,
              groupValue: _soundTitle,
              activeColor: colors.accent,
              onChanged: (val) => Navigator.pop(ctx, val),
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('budget_notif_sound_title', selected);
      setState(() => _soundTitle = selected);
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _exportMonthlyReportPdf() async {
    final budget = ref.read(budgetProvider);
    final pdf = pw.Document();
    final now = DateTime.now();
    final monthName = DateFormat('LLLL yyyy', 'ru').format(now);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Финансовый отчет: $monthName',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Остаток на счетах: ${budget.totalAccountsBalance.toInt()} $_currency',
                ),
                pw.Text(
                  'Свободные деньги: ${budget.freeMoney.toInt()} $_currency',
                ),
                pw.Divider(thickness: 1.5),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Операции месяца:',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  headers: ['Дата', 'Название', 'Категория', 'Тип', 'Сумма'],
                  data: budget.transactions.take(40).map((t) {
                    final isExp = t['type'] == 'expense';
                    final date = t['date'] as DateTime;
                    return [
                      DateFormat('dd.MM.yyyy').format(date),
                      t['title'] ?? '',
                      t['category'] ?? '',
                      isExp ? 'Расход' : 'Доход',
                      '${isExp ? "-" : "+"}${(t['amount'] as num).toInt()} $_currency',
                    ];
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Финансовый_отчет_${now.month}_${now.year}.pdf',
    );
  }

  Future<void> _exportMonthlyReportCsv(AppColorsExtension colors) async {
    final budget = ref.read(budgetProvider);
    final now = DateTime.now();

    final buffer = StringBuffer();
    buffer.writeln('Дата;Название;Категория;Тип;Сумма;Валюта');

    for (final t in budget.transactions) {
      final date = t['date'] as DateTime;
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final title = t['title'] ?? '';
      final cat = t['category'] ?? '';
      final isExp = t['type'] == 'expense';
      final amt = (t['amount'] as num).toDouble();

      buffer.writeln(
        '$dateStr;$title;$cat;${isExp ? "Расход" : "Доход"};$amt;$_currency',
      );
    }

    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    await FileSaver.instance.saveAs(
      name: 'Бюджет_${now.month}_${now.year}.csv',
      bytes: bytes,
      mimeType: MimeType.csv,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Отчет CSV успешно сохранен',
            style: TextStyle(fontFamily: 'Onest'),
          ),
          backgroundColor: colors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cardBg = colors.card;
    final textPrimary = colors.text;
    final textSecondary = colors.text.withValues(alpha: 0.6);
    final borderColor = colors.nested;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(
          'Настройки бюджета',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        backgroundColor: colors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          _buildSectionHeader('ОСНОВНЫЕ ПАРАМЕТРЫ', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.currency_ruble,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Основная валюта',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Используется для расчетов и балансов',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: DropdownButton<String>(
                    value: _currency,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items: const ['₽', '\$', '€', '₸', 'Br']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _updateString(
                          'budget_currency',
                          v,
                          () => _currency = v,
                        );
                      }
                    },
                  ),
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: Icon(
                    Icons.calendar_month_outlined,
                    color: colors.accent,
                  ),
                  title: Text(
                    'День начала фин. месяца',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'День зарплаты: $_salaryDay число каждого месяца',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: DropdownButton<int>(
                    value: _salaryDay,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items: List.generate(31, (i) => i + 1)
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text('$e-е')),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _updateInt(
                          'budget_salary_day',
                          v,
                          () => _salaryDay = v,
                        );
                      }
                    },
                  ),
                ),
                Divider(height: 1, color: borderColor),
                SwitchListTile(
                  secondary: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: colors.warning,
                  ),
                  title: Text(
                    'Вычитать долги и кредиты',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Учитывать задолженности при расчете «Свободных денег»',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: colors.accent,
                  activeTrackColor: colors.accent.withValues(alpha: 0.3),
                  value: _includeDebtsInFreeMoney,
                  onChanged: (v) => _updateBool(
                    'budget_include_debts',
                    v,
                    () => _includeDebtsInFreeMoney = v,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('ЛИМИТЫ И КОНТРОЛЬ ТРАТ', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.speed, color: colors.success),
                  title: Text(
                    'Показывать «Безопасно в день»',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Рекомендуемый дневной бюджет до конца периода',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: colors.accent,
                  activeTrackColor: colors.accent.withValues(alpha: 0.3),
                  value: _showDailySafeLimit,
                  onChanged: (v) => _updateBool(
                    'budget_show_daily_limit',
                    v,
                    () => _showDailySafeLimit = v,
                  ),
                ),
                Divider(height: 1, color: borderColor),
                SwitchListTile(
                  secondary: Icon(
                    Icons.notification_important_outlined,
                    color: colors.error,
                  ),
                  title: Text(
                    'Предупреждать о перерасходе',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Оповещать, если дневные траты превысили норму',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: colors.accent,
                  activeTrackColor: colors.accent.withValues(alpha: 0.3),
                  value: _warnOnOverspend,
                  onChanged: (v) => _updateBool(
                    'budget_warn_overspend',
                    v,
                    () => _warnOnOverspend = v,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('НАПОМИНАНИЯ', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    Icons.event_note_outlined,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Напоминание о запланированных платежах',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Уведомлять в день оплаты счетов и поступлений',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: colors.accent,
                  activeTrackColor: colors.accent.withValues(alpha: 0.3),
                  value: _remindPlannedOps,
                  onChanged: (v) => _updateBool(
                    'budget_remind_planned',
                    v,
                    () => _remindPlannedOps = v,
                  ),
                ),
                if (_remindPlannedOps) ...[
                  Divider(height: 1, color: borderColor),
                  ListTile(
                    leading: const SizedBox(width: 24),
                    title: Text(
                      'Время утреннего напоминания',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    trailing: Text(
                      '${_plannedRemindTime.hour.toString().padLeft(2, '0')}:${_plannedRemindTime.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontFamily: 'Unbounded',
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () => _pickTime(
                      initialTime: _plannedRemindTime,
                      prefKey: 'budget_planned_time',
                      onSelected: (t) => _plannedRemindTime = t,
                    ),
                  ),
                ],
                Divider(height: 1, color: borderColor),
                SwitchListTile(
                  secondary: Icon(
                    Icons.nights_stay_outlined,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Вечерний запрос внесения трат',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Напоминать записать расходы за прошедший день',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: colors.accent,
                  activeTrackColor: colors.accent.withValues(alpha: 0.3),
                  value: _eveningExpenseCheck,
                  onChanged: (v) => _updateBool(
                    'budget_evening_check',
                    v,
                    () => _eveningExpenseCheck = v,
                  ),
                ),
                if (_eveningExpenseCheck) ...[
                  Divider(height: 1, color: borderColor),
                  ListTile(
                    leading: const SizedBox(width: 24),
                    title: Text(
                      'Время вечернего напоминания',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    trailing: Text(
                      '${_eveningCheckTime.hour.toString().padLeft(2, '0')}:${_eveningCheckTime.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontFamily: 'Unbounded',
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () => _pickTime(
                      initialTime: _eveningCheckTime,
                      prefKey: 'budget_evening_time',
                      onSelected: (t) => _eveningCheckTime = t,
                    ),
                  ),
                ],
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: Icon(
                    Icons.music_note_outlined,
                    color: colors.warning,
                  ),
                  title: Text(
                    'Сигнал уведомления',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _soundTitle,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing:
                      Icon(Icons.chevron_right, size: 20, color: textSecondary),
                  onTap: () => _pickNotificationSound(colors),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('ПРИВАТНОСТЬ И ЭКСПОРТ', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    Icons.visibility_off_outlined,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Скрывать балансы («Режим приватности»)',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Маскировать суммы на главном экране звездочками ••••',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: colors.accent,
                  activeTrackColor: colors.accent.withValues(alpha: 0.3),
                  value: _hideBalancesOnHome,
                  onChanged: (v) => _updateBool(
                    'budget_hide_balances',
                    v,
                    () => _hideBalancesOnHome = v,
                  ),
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: Icon(
                    Icons.picture_as_pdf_outlined,
                    color: colors.error,
                  ),
                  title: Text(
                    'Экспорт отчета в PDF',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Финансовая выписка за текущий месяц для печати',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(Icons.download_outlined,
                      size: 22, color: colors.accent),
                  onTap: _exportMonthlyReportPdf,
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: Icon(
                    Icons.table_chart_outlined,
                    color: colors.success,
                  ),
                  title: Text(
                    'Экспорт в Excel / CSV',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Таблица всех операций за текущий месяц',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(Icons.file_download_outlined,
                      size: 22, color: colors.accent),
                  onTap: () => _exportMonthlyReportCsv(colors),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Onest',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
