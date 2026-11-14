import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/habits_provider.dart';
import '../../theme/app_theme.dart';

class HabitEditScreen extends ConsumerStatefulWidget {
  final String type; // 'boolean' | 'numerical'
  final HabitItem? initialHabit;

  const HabitEditScreen({super.key, required this.type, this.initialHabit});

  @override
  ConsumerState<HabitEditScreen> createState() => _HabitEditScreenState();
}

class _HabitEditScreenState extends ConsumerState<HabitEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _questionController;
  late TextEditingController _descriptionController;
  late TextEditingController _targetValueController;
  late TextEditingController _unitController;

  late TextEditingController _everyNDaysController;
  late TextEditingController _timesCountController;
  late TextEditingController _windowDaysController;

  late Color _selectedColor;
  late String _frequencyType;
  late List<int> _frequencyDays;
  TimeOfDay? _reminderTime;

  static const List<Color> _palette = [
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF06B6D4),
    Color(0xFF38BDF8),
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    final h = widget.initialHabit;

    _titleController = TextEditingController(text: h?.title ?? '');
    _questionController = TextEditingController(text: h?.question ?? '');
    _descriptionController = TextEditingController(text: h?.description ?? '');
    _targetValueController = TextEditingController(
      text: h != null
          ? h.targetValue.toStringAsFixed(
              h.targetValue.truncateToDouble() == h.targetValue ? 0 : 1,
            )
          : (widget.type == 'numerical' ? '2000' : '1'),
    );
    _unitController = TextEditingController(
      text: h?.unit ?? (widget.type == 'numerical' ? 'мл' : ''),
    );

    int initialCount = h?.frequencyCount ?? 1;
    _everyNDaysController = TextEditingController(
      text: '${initialCount > 0 ? initialCount : 2}',
    );
    _timesCountController = TextEditingController(
      text: '${initialCount > 0 ? initialCount : 3}',
    );

    int initialWindow = 7;
    if (h?.frequencyDays != null &&
        h!.frequencyDays.isNotEmpty &&
        h.frequencyType == 'z_in_n_days') {
      initialWindow = h.frequencyDays.first;
    }
    _windowDaysController = TextEditingController(text: '$initialWindow');

    _selectedColor = h?.color ?? const Color(0xFF38BDF8);

    if (h?.frequencyType == 'x_per_week') {
      _frequencyType = 'z_per_week';
    } else {
      _frequencyType = h?.frequencyType ?? 'daily';
    }

    _frequencyDays =
        h?.frequencyDays != null && h!.frequencyType == 'specific_days'
            ? List<int>.from(h.frequencyDays)
            : [1, 2, 3, 4, 5];

    if (h?.reminderTime != null && h!.reminderTime!.contains(':')) {
      final parts = h.reminderTime!.split(':');
      _reminderTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _questionController.dispose();
    _descriptionController.dispose();
    _targetValueController.dispose();
    _unitController.dispose();
    _everyNDaysController.dispose();
    _timesCountController.dispose();
    _windowDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isNumerical = widget.type == 'numerical';
    final isEdit = widget.initialHabit != null;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          isEdit
              ? 'Редактировать привычку'
              : (isNumerical ? 'Новая измеримая привычка' : 'Новая привычка'),
          style: TextStyle(
            fontFamily: 'Unbounded',
            color: colors.text,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: colors.text),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Сохранить',
              style: TextStyle(
                fontFamily: 'Onest',
                color: colors.accent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTextField(
            controller: _titleController,
            label: 'Название',
            hint: 'Например: Чтение, Вода, Зарядка',
            autofocus: !isEdit,
            colors: colors,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _questionController,
            label: 'Вопрос',
            hint: 'Например: Читал ли ты сегодня?',
            colors: colors,
          ),
          const SizedBox(height: 16),
          if (isNumerical) ...[
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _targetValueController,
                    label: 'Цель',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    colors: colors,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextField(
                    controller: _unitController,
                    label: 'Единица измерения',
                    hint: 'мл, стр, минут',
                    colors: colors,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          _buildColorPicker(colors),
          const SizedBox(height: 20),
          _buildFrequencySection(colors),
          const SizedBox(height: 20),
          _buildReminderTile(colors),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _descriptionController,
            label: 'Заметки',
            hint: 'Дополнительные пояснения или мотивация',
            maxLines: 3,
            colors: colors,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required AppColorsExtension colors,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool autofocus = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Onest',
            color: colors.text.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          autofocus: autofocus,
          keyboardType: keyboardType,
          style: TextStyle(
            fontFamily: 'Onest',
            color: colors.text,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'Onest',
              color: colors.text.withValues(alpha: 0.35),
              fontSize: 14,
            ),
            filled: true,
            fillColor: colors.card,
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker(AppColorsExtension colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Цвет',
          style: TextStyle(
            fontFamily: 'Onest',
            color: colors.text.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _palette.map((color) {
            final isSelected = _selectedColor.toARGB32() == color.toARGB32();
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: colors.text, width: 3)
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: ThemeData.estimateBrightnessForColor(color) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        size: 20,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFrequencySection(AppColorsExtension colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Частота',
          style: TextStyle(
            fontFamily: 'Onest',
            color: colors.text.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.nested),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _frequencyType,
                dropdownColor: colors.card,
                style: TextStyle(
                  fontFamily: 'Onest',
                  color: colors.text,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: colors.nested.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Каждый день')),
                  DropdownMenuItem(
                    value: 'every_n_days',
                    child: Text('Каждые N дней'),
                  ),
                  DropdownMenuItem(
                    value: 'z_per_week',
                    child: Text('Z раз в неделю'),
                  ),
                  DropdownMenuItem(
                    value: 'z_per_month',
                    child: Text('Z раз в месяц'),
                  ),
                  DropdownMenuItem(
                    value: 'z_in_n_days',
                    child: Text('Z раз в N дней'),
                  ),
                  DropdownMenuItem(
                    value: 'specific_days',
                    child: Text('Определенные дни недели'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _frequencyType = val);
                  }
                },
              ),
              if (_frequencyType == 'every_n_days') ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'Каждые ',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(
                      width: 65,
                      child: _buildNumberInput(_everyNDaysController, colors),
                    ),
                    Text(
                      ' дня / дней',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
              if (_frequencyType == 'z_per_week') ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    SizedBox(
                      width: 65,
                      child: _buildNumberInput(_timesCountController, colors),
                    ),
                    Text(
                      ' раз(а) в неделю',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
              if (_frequencyType == 'z_per_month') ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    SizedBox(
                      width: 65,
                      child: _buildNumberInput(_timesCountController, colors),
                    ),
                    Text(
                      ' раз(а) в месяц',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
              if (_frequencyType == 'z_in_n_days') ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: _buildNumberInput(_timesCountController, colors),
                    ),
                    Text(
                      ' раз(а) каждые ',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: _buildNumberInput(_windowDaysController, colors),
                    ),
                    Text(
                      ' дн.',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
              if (_frequencyType == 'specific_days') ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _dayChip(1, 'Пн', colors),
                    _dayChip(2, 'Вт', colors),
                    _dayChip(3, 'Ср', colors),
                    _dayChip(4, 'Чт', colors),
                    _dayChip(5, 'Пт', colors),
                    _dayChip(6, 'Сб', colors),
                    _dayChip(7, 'Вс', colors),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNumberInput(
    TextEditingController controller,
    AppColorsExtension colors,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(
        fontFamily: 'Unbounded',
        color: colors.accent,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        filled: true,
        fillColor: colors.nested.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _dayChip(int dayIndex, String label, AppColorsExtension colors) {
    final isSelected = _frequencyDays.contains(dayIndex);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            if (_frequencyDays.length > 1) _frequencyDays.remove(dayIndex);
          } else {
            _frequencyDays.add(dayIndex);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? colors.accent : colors.nested.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Onest',
            color: isSelected
                ? (colors.isDark ? Colors.black : Colors.white)
                : colors.text.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildReminderTile(AppColorsExtension colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.nested),
      ),
      child: ListTile(
        leading: Icon(
          Icons.notifications_none,
          color: colors.text.withValues(alpha: 0.7),
        ),
        title: Text(
          'Напоминание',
          style: TextStyle(
            fontFamily: 'Onest',
            fontWeight: FontWeight.w600,
            color: colors.text,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          _reminderTime != null
              ? '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
              : 'Не установлено',
          style: TextStyle(
            fontFamily: 'Onest',
            color: _reminderTime != null
                ? colors.accent
                : colors.text.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
        trailing: _reminderTime != null
            ? IconButton(
                icon: Icon(
                  Icons.close,
                  color: colors.text.withValues(alpha: 0.5),
                  size: 20,
                ),
                onPressed: () => setState(() => _reminderTime = null),
              )
            : null,
        onTap: () async {
          final t = await showTimePicker(
            context: context,
            initialTime: _reminderTime ?? const TimeOfDay(hour: 9, minute: 0),
          );
          if (t != null) setState(() => _reminderTime = t);
        },
      ),
    );
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final targetVal = double.tryParse(_targetValueController.text) ?? 1.0;
    final reminderStr = _reminderTime != null
        ? '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
        : null;

    int freqCount = 1;
    List<int> freqDays = [];

    switch (_frequencyType) {
      case 'daily':
        freqCount = 1;
        break;
      case 'every_n_days':
        freqCount = int.tryParse(_everyNDaysController.text) ?? 2;
        break;
      case 'z_per_week':
      case 'z_per_month':
        freqCount = int.tryParse(_timesCountController.text) ?? 3;
        break;
      case 'z_in_n_days':
        freqCount = int.tryParse(_timesCountController.text) ?? 2;
        final window = int.tryParse(_windowDaysController.text) ?? 7;
        freqDays = [window];
        break;
      case 'specific_days':
        freqDays = List<int>.from(_frequencyDays);
        break;
    }

    ref.read(habitsProvider.notifier).saveHabit(
          id: widget.initialHabit?.id,
          title: title,
          question: _questionController.text.trim().isEmpty
              ? null
              : _questionController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          color: _selectedColor,
          type: widget.type,
          targetValue: targetVal,
          unit: _unitController.text.trim().isEmpty
              ? null
              : _unitController.text.trim(),
          frequencyType: _frequencyType,
          frequencyDays: freqDays,
          frequencyCount: freqCount,
          reminderTime: reminderStr,
        );

    Navigator.pop(context);
  }
}
