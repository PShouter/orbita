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

import '../../../providers/shift_provider.dart';
import '../../../theme/app_theme.dart';

class ShiftsSettingsScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;
  const ShiftsSettingsScreen({super.key, required this.isDarkMode});

  @override
  ConsumerState<ShiftsSettingsScreen> createState() =>
      _ShiftsSettingsScreenState();
}

class _ShiftsSettingsScreenState extends ConsumerState<ShiftsSettingsScreen> {
  // 1. Синхронизация
  bool _syncWithMainCalendar = true;
  int _syncHorizonMonths = 3;

  // 2. Напоминания
  bool _remindEveningBefore = true;
  TimeOfDay _eveningReminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _remindBeforeShift = true;
  int _remindBeforeMinutes = 90;
  String _soundTitle = 'По умолчанию (системный)';

  // 3. Отображение
  bool _highlightWeekends = true;
  bool _showTimeInDayCell = false;
  bool _showMonthlyStats = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _syncWithMainCalendar =
          prefs.getBool('shifts_sync_main_calendar') ?? true;
      _syncHorizonMonths = prefs.getInt('shifts_sync_horizon_months') ?? 3;

      _remindEveningBefore = prefs.getBool('shifts_remind_evening') ?? true;
      final eveTimeStr = prefs.getString('shifts_evening_time') ?? '20:00';
      final eveParts = eveTimeStr.split(':');
      _eveningReminderTime = TimeOfDay(
        hour: int.tryParse(eveParts[0]) ?? 20,
        minute: int.tryParse(eveParts[1]) ?? 0,
      );

      _remindBeforeShift = prefs.getBool('shifts_remind_before') ?? true;
      _remindBeforeMinutes = prefs.getInt('shifts_remind_before_minutes') ?? 90;
      _soundTitle = prefs.getString('shifts_notif_sound_title') ??
          'По умолчанию (системный)';

      _highlightWeekends = prefs.getBool('shifts_highlight_weekends') ?? true;
      _showTimeInDayCell = prefs.getBool('shifts_show_time_in_cell') ?? false;
      _showMonthlyStats = prefs.getBool('shifts_show_monthly_stats') ?? true;
    });
  }

  Future<void> _updateBool(String key, bool val, void Function() onSet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
    setState(onSet);
    HapticFeedback.selectionClick();
  }

  Future<void> _updateInt(String key, int val, void Function() onSet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, val);
    setState(onSet);
    HapticFeedback.selectionClick();
  }

  Future<void> _pickEveningTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eveningReminderTime,
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
        'shifts_evening_time',
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
      );
      setState(() => _eveningReminderTime = picked);
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _pickNotificationSound(AppColorsExtension colors) async {
    final options = [
      'По умолчанию (системный)',
      'Космическая вахта (Орбита)',
      'Короткий гудок',
      'Электронный будильник',
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
      await prefs.setString('shifts_notif_sound_title', selected);
      setState(() => _soundTitle = selected);
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _exportSchedulePdf() async {
    final schedule = ref.read(shiftProvider).activeSchedule;
    if (schedule == null) return;

    final pdf = pw.Document();
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
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
                  'График смен: ${schedule.name}',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Период: $monthName',
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.Divider(thickness: 1.5),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  headers: ['Число', 'День недели', 'Смена', 'Время'],
                  data: List.generate(daysInMonth, (i) {
                    final d = DateTime(now.year, now.month, i + 1);
                    final shift = schedule.getShiftForDate(d);
                    final weekday = DateFormat('EEEE', 'ru').format(d);
                    return [
                      '${i + 1}',
                      weekday,
                      shift?.name ?? '—',
                      (shift != null && shift.isWork)
                          ? '${shift.startTime} - ${shift.endTime}'
                          : (shift?.isWork == false ? 'Выходной' : '—'),
                    ];
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'График_${schedule.name}_${now.month}_${now.year}.pdf',
    );
  }

  Future<void> _exportScheduleCsv(AppColorsExtension colors) async {
    final schedule = ref.read(shiftProvider).activeSchedule;
    if (schedule == null) return;

    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);

    final buffer = StringBuffer();
    buffer.writeln('Число;День недели;Смена;Рабочая;Начало;Конец;Часы');

    for (int i = 1; i <= daysInMonth; i++) {
      final d = DateTime(now.year, now.month, i);
      final shift = schedule.getShiftForDate(d);
      final weekday = DateFormat('EEEE', 'ru').format(d);

      final shiftName = shift?.name ?? '';
      final isWork = shift?.isWork == true ? 'Да' : 'Нет';
      final start = shift?.startTime ?? '';
      final end = shift?.endTime ?? '';
      final hours = shift?.durationHours.toStringAsFixed(1) ?? '0.0';

      buffer.writeln('$i;$weekday;$shiftName;$isWork;$start;$end;$hours');
    }

    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    await FileSaver.instance.saveAs(
      name: 'Табель_${schedule.name}_${now.month}_${now.year}.csv',
      bytes: bytes,
      mimeType: MimeType.csv,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Табель в формате CSV успешно выгружен',
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
          'Настройки графика смен',
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
          // 1. СИНХРОНИЗАЦИЯ С КАЛЕНДАРЁМ
          _buildSectionHeader('СИНХРОНИЗАЦИЯ С КАЛЕНДАРЁМ', textSecondary),
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
                    Icons.sync_alt,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Дублировать смены в календарь',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Рабочие смены автоматически появятся в календаре Орбиты',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: colors.accent,
                  activeTrackColor: colors.accent.withValues(alpha: 0.3),
                  value: _syncWithMainCalendar,
                  onChanged: (v) => _updateBool(
                    'shifts_sync_main_calendar',
                    v,
                    () => _syncWithMainCalendar = v,
                  ),
                ),
                if (_syncWithMainCalendar) ...[
                  Divider(height: 1, color: borderColor),
                  ListTile(
                    leading: const SizedBox(width: 24),
                    title: Text(
                      'Горизонт синхронизации',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'На сколько вперед переносить график',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: DropdownButton<int>(
                      value: _syncHorizonMonths,
                      underline: const SizedBox(),
                      dropdownColor: cardBg,
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 месяц')),
                        DropdownMenuItem(value: 3, child: Text('3 месяца')),
                        DropdownMenuItem(value: 6, child: Text('6 месяцев')),
                        DropdownMenuItem(value: 12, child: Text('1 год')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          _updateInt(
                            'shifts_sync_horizon_months',
                            v,
                            () => _syncHorizonMonths = v,
                          );
                          ref
                              .read(shiftProvider.notifier)
                              .syncAllSchedulesToCalendar(v);
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. НАПОМИНАНИЯ
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
                    Icons.nightlight_outlined,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Напоминание накануне вечером',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Напомнить о завтрашней рабочей смене',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: colors.accent,
                  activeTrackColor: colors.accent.withValues(alpha: 0.3),
                  value: _remindEveningBefore,
                  onChanged: (v) => _updateBool(
                    'shifts_remind_evening',
                    v,
                    () => _remindEveningBefore = v,
                  ),
                ),
                if (_remindEveningBefore) ...[
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
                      '${_eveningReminderTime.hour.toString().padLeft(2, '0')}:${_eveningReminderTime.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontFamily: 'Unbounded',
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    onTap: _pickEveningTime,
                  ),
                ],
                Divider(height: 1, color: borderColor),
                SwitchListTile(
                  secondary: Icon(Icons.alarm, color: colors.warning),
                  title: Text(
                    'Напоминание перед началом смены',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Заблаговременный сигнал перед выходом на работу',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: colors.accent,
                  activeTrackColor: colors.accent.withValues(alpha: 0.3),
                  value: _remindBeforeShift,
                  onChanged: (v) => _updateBool(
                    'shifts_remind_before',
                    v,
                    () => _remindBeforeShift = v,
                  ),
                ),
                if (_remindBeforeShift) ...[
                  Divider(height: 1, color: borderColor),
                  ListTile(
                    leading: const SizedBox(width: 24),
                    title: Text(
                      'За сколько предупреждать',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    trailing: DropdownButton<int>(
                      value: _remindBeforeMinutes,
                      underline: const SizedBox(),
                      dropdownColor: cardBg,
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      items: const [
                        DropdownMenuItem(value: 30, child: Text('За 30 мин')),
                        DropdownMenuItem(value: 60, child: Text('За 1 час')),
                        DropdownMenuItem(value: 90, child: Text('За 1.5 часа')),
                        DropdownMenuItem(value: 120, child: Text('За 2 часа')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          _updateInt(
                            'shifts_remind_before_minutes',
                            v,
                            () => _remindBeforeMinutes = v,
                          );
                        }
                      },
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

          // 3. ОТОБРАЖЕНИЕ И СЕТКА
          _buildSectionHeader('ОТОБРАЖЕНИЕ И СЕТКА', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                CheckboxListTile(
                  secondary: Icon(
                    Icons.weekend_outlined,
                    color: colors.error,
                  ),
                  title: Text(
                    'Выделять календарные выходные',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Подсвечивать субботы и воскресенья в шапке календаря',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeColor: colors.accent,
                  checkColor: colors.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  value: _highlightWeekends,
                  onChanged: (v) => _updateBool(
                    'shifts_highlight_weekends',
                    v ?? true,
                    () => _highlightWeekends = v ?? true,
                  ),
                ),
                Divider(height: 1, color: borderColor),
                CheckboxListTile(
                  secondary: Icon(
                    Icons.access_time_outlined,
                    color: colors.success,
                  ),
                  title: Text(
                    'Показывать время смены в ячейке',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Отображать часы (например, 08:00) внутри блока дня',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeColor: colors.accent,
                  checkColor: colors.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  value: _showTimeInDayCell,
                  onChanged: (v) => _updateBool(
                    'shifts_show_time_in_cell',
                    v ?? false,
                    () => _showTimeInDayCell = v ?? false,
                  ),
                ),
                Divider(height: 1, color: borderColor),
                CheckboxListTile(
                  secondary: Icon(
                    Icons.query_stats,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Нижняя панель статистики',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Показывать число рабочих/выходных дней и сумму часов за месяц',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeColor: colors.accent,
                  checkColor: colors.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  value: _showMonthlyStats,
                  onChanged: (v) => _updateBool(
                    'shifts_show_monthly_stats',
                    v ?? true,
                    () => _showMonthlyStats = v ?? true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. ЭКСПОРТ И ПЕЧАТЬ
          _buildSectionHeader('ЭКСПОРТ И ПЕЧАТЬ', textSecondary),
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
                    Icons.picture_as_pdf_outlined,
                    color: colors.error,
                  ),
                  title: Text(
                    'Экспорт графика в PDF',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Создать табель для печати на текущий месяц',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(Icons.download_outlined,
                      size: 22, color: colors.accent),
                  onTap: _exportSchedulePdf,
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
                    'Выгрузка таблицы рабочих часов в файл',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(Icons.file_download_outlined,
                      size: 22, color: colors.accent),
                  onTap: () => _exportScheduleCsv(colors),
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
