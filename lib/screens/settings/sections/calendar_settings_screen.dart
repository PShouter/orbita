import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarSettingsScreen extends StatefulWidget {
  final bool isDarkMode;

  const CalendarSettingsScreen({super.key, required this.isDarkMode});

  @override
  State<CalendarSettingsScreen> createState() => _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState extends State<CalendarSettingsScreen> {
  // Внешний вид
  String _initialView = 'Месяц'; // 'Месяц' | 'День'
  bool _showWeekNumbers = false;

  // Напоминания
  String _notificationSoundTitle = 'По умолчанию (системный)';
  String _vibrationMode =
      'Всегда'; // 'Всегда' | 'Только в беззвучном режиме' | 'Никогда'
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

      _notificationSoundTitle =
          prefs.getString('cal_notif_sound_title') ??
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

  // Диалог выбора системного звука напоминания
  Future<void> _pickNotificationSound() async {
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
          backgroundColor: widget.isDarkMode
              ? const Color(0xFF161B22)
              : Colors.white,
          title: const Text('Сигнал уведомления'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((sound) {
              return RadioListTile<String>(
                title: Text(sound),
                value: sound,
                groupValue: _notificationSoundTitle,
                activeColor: const Color(0xFF38BDF8),
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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Настройки календаря'),
        backgroundColor: cardBg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. ВНЕШНИЙ ВИД
          _buildSectionHeader('ВНЕШНИЙ ВИД', textSecondary),
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
                    Icons.calendar_view_month,
                    color: Color(0xFF38BDF8),
                  ),
                  title: Text(
                    'Начальный вид',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Вид календаря при открытии: $_initialView',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: _initialView,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
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
                  secondary: const Icon(
                    Icons.format_list_numbered,
                    color: Color(0xFF38BDF8),
                  ),
                  title: Text(
                    'Номера недель',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Отображать порядковый номер недели в сетке года',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  activeColor: const Color(0xFF38BDF8),
                  value: _showWeekNumbers,
                  onChanged: (v) => _setShowWeekNumbers(v ?? false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. НАПОМИНАНИЯ
          _buildSectionHeader('НАПОМИНАНИЯ', textSecondary),
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
                    Icons.music_note_outlined,
                    color: Colors.purpleAccent,
                  ),
                  title: Text(
                    'Сигнал уведомления',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _notificationSoundTitle,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: _pickNotificationSound,
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: const Icon(Icons.vibration, color: Colors.amber),
                  title: Text(
                    'Вибрация',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _vibrationMode,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: _vibrationMode,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items:
                        const [
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
                  secondary: const Icon(
                    Icons.lightbulb_outline,
                    color: Color(0xFF10B981),
                  ),
                  title: Text(
                    'Светодиодный индикатор',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Мигать светодиодом телефона при поступлении напоминания',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  activeColor: const Color(0xFF38BDF8),
                  value: _enableLedIndicator,
                  onChanged: (v) => _setEnableLed(v ?? false),
                ),
              ],
            ),
          ),
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
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
