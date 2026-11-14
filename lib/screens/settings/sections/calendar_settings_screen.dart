import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../theme/app_theme.dart';

class CalendarSettingsScreen extends StatefulWidget {
  final bool isDarkMode;

  const CalendarSettingsScreen({super.key, required this.isDarkMode});

  @override
  State<CalendarSettingsScreen> createState() => _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState extends State<CalendarSettingsScreen> {
  String _initialView = 'Месяц';
  bool _showWeekNumbers = false;

  String _notificationSoundTitle = 'По умолчанию (системный)';
  String _vibrationMode = 'Всегда';
  bool _enableLedIndicator = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _initialView = prefs.getString('cal_initial_view') ?? 'Месяц';
      _showWeekNumbers = prefs.getBool('cal_show_week_numbers') ?? false;

      _notificationSoundTitle = prefs.getString('cal_notif_sound_title') ??
          'По умолчанию (системный)';
      _vibrationMode = prefs.getString('cal_vibration_mode') ?? 'Всегда';
      _enableLedIndicator = prefs.getBool('cal_enable_led') ?? true;
    });
  }

  Future<void> _setInitialView(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cal_initial_view', val);
    setState(() => _initialView = val);
  }

  Future<void> _setShowWeekNumbers(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cal_show_week_numbers', val);
    setState(() => _showWeekNumbers = val);
  }

  Future<void> _setVibrationMode(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cal_vibration_mode', val);
    setState(() => _vibrationMode = val);
  }

  Future<void> _setEnableLed(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cal_enable_led', val);
    setState(() => _enableLedIndicator = val);
  }

  Future<void> _pickNotificationSound(AppColorsExtension colors) async {
    final options = [
      'По умолчанию (системный)',
      'Космический сигнал (Орбита)',
      'Колокольчик',
      'Электронный пульс',
      'Без звука',
    ];

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(
            'Сигнал уведомления',
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
                groupValue: _notificationSoundTitle,
                activeColor: colors.accent,
                onChanged: (val) => Navigator.pop(ctx, val),
              );
            }).toList(),
          ),
        );
      },
    );

    if (selected != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cal_notif_sound_title', selected);
      setState(() => _notificationSoundTitle = selected);
      HapticFeedback.selectionClick();
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
          'Настройки календаря',
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
          _buildSectionHeader('ВНЕШНИЙ ВИД', textSecondary),
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
                    Icons.calendar_view_month,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Начальный вид',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Вид календаря при открытии: $_initialView',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: DropdownButton<String>(
                    value: _initialView,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items: const ['Месяц', 'День']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _setInitialView(v);
                    },
                  ),
                ),
                Divider(height: 1, color: borderColor),
                CheckboxListTile(
                  secondary: Icon(
                    Icons.format_list_numbered,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Номера недель',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Отображать порядковый номер недели в сетке года',
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
                  value: _showWeekNumbers,
                  onChanged: (v) => _setShowWeekNumbers(v ?? false),
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
                ListTile(
                  leading: Icon(
                    Icons.music_note_outlined,
                    color: colors.accent,
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
                    _notificationSoundTitle,
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
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: Icon(Icons.vibration, color: colors.warning),
                  title: Text(
                    'Вибрация',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _vibrationMode,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: DropdownButton<String>(
                    value: _vibrationMode,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items: const [
                      'Всегда',
                      'Только в беззвучном режиме',
                      'Никогда',
                    ]
                        .map(
                          (e) => DropdownMenuItem(value: e, child: Text(e)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _setVibrationMode(v);
                    },
                  ),
                ),
                Divider(height: 1, color: borderColor),
                CheckboxListTile(
                  secondary: Icon(
                    Icons.lightbulb_outline,
                    color: colors.success,
                  ),
                  title: Text(
                    'Светодиодный индикатор',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Мигать светодиодом телефона при поступлении напоминания',
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
                  value: _enableLedIndicator,
                  onChanged: (v) => _setEnableLed(v ?? false),
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
