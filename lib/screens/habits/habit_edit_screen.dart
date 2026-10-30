import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/habits_provider.dart';

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

  // Контроллеры для гибкой настройки частоты
  late TextEditingController _everyNDaysController; // Для "Каждые N дней"
  late TextEditingController _timesCountController; // Число Z (раз)
  late TextEditingController _windowDaysController; // Число N (дней)

  late Color _selectedColor;
  late String _frequencyType;
  // Значения: 'daily', 'every_n_days', 'z_per_week', 'z_per_month', 'z_in_n_days', 'specific_days'

  late List<int> _frequencyDays;
  TimeOfDay? _reminderTime;

  static const List<Color> _palette = [
    Color(0xFFEF4444), // red
    Color(0xFFF97316), // orange
    Color(0xFFF59E0B), // amber
    Color(0xFF10B981), // emerald
    Color(0xFF06B6D4), // cyan
    Color(0xFF38BDF8), // sky blue
    Color(0xFF6366F1), // indigo
    Color(0xFF8B5CF6), // violet
    Color(0xFFEC4899), // pink
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

    // Инициализация полей частоты
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

    // Нормализация типа частоты при старых сохраненных значениях
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
    final isNumerical = widget.type == 'numerical';
    final isEdit = widget.initialHabit != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          isEdit
              ? 'Редактировать привычку'
              : (isNumerical ? 'Новая измеримая привычка' : 'Новая привычка'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Сохранить',
              style: TextStyle(
                color: Color(0xFF38BDF8),
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
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _questionController,
            label: 'Вопрос',
            hint: 'Например: Читал ли ты сегодня?',
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
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextField(
                    controller: _unitController,
                    label: 'Единица измерения',
                    hint: 'мл, стр, минут',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          _buildColorPicker(),
          const SizedBox(height: 20),

          _buildFrequencySection(),
          const SizedBox(height: 20),

          _buildReminderTile(),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _descriptionController,
            label: 'Заметки',
            hint: 'Дополнительные пояснения или мотивация',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
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
          style: const TextStyle(
            color: Colors.white70,
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
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Цвет',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
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
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Секция частоты с выпадающим списком
  Widget _buildFrequencySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Частота',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Выпадающий список вариантов
              DropdownButtonFormField<String>(
                initialValue: _frequencyType,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
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

              // Динамические настройки под выбранный пункт:
              if (_frequencyType == 'every_n_days') ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      'Каждые ',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    SizedBox(
                      width: 65,
                      child: _buildNumberInput(_everyNDaysController),
                    ),
                    const Text(
                      ' дня / дней',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
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
                      child: _buildNumberInput(_timesCountController),
                    ),
                    const Text(
                      ' раз(а) в неделю',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
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
                      child: _buildNumberInput(_timesCountController),
                    ),
                    const Text(
                      ' раз(а) в месяц',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
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
                      child: _buildNumberInput(_timesCountController),
                    ),
                    const Text(
                      ' раз(а) каждые ',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    SizedBox(
                      width: 60,
                      child: _buildNumberInput(_windowDaysController),
                    ),
                    const Text(
                      ' дн.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ],

              if (_frequencyType == 'specific_days') ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _dayChip(1, 'Пн'),
                    _dayChip(2, 'Вт'),
                    _dayChip(3, 'Ср'),
                    _dayChip(4, 'Чт'),
                    _dayChip(5, 'Пт'),
                    _dayChip(6, 'Сб'),
                    _dayChip(7, 'Вс'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNumberInput(TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        color: Color(0xFF38BDF8),
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _dayChip(int dayIndex, String label) {
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8) : Colors.white10,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildReminderTile() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: const Icon(Icons.notifications_none, color: Colors.white70),
        title: const Text(
          'Напоминание',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        subtitle: Text(
          _reminderTime != null
              ? '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
              : 'Не установлено',
          style: TextStyle(
            color: _reminderTime != null
                ? const Color(0xFF38BDF8)
                : Colors.white38,
            fontSize: 13,
          ),
        ),
        trailing: _reminderTime != null
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
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
        freqDays = [window]; // Сохраняем интервал N в freqDays
        break;
      case 'specific_days':
        freqDays = List<int>.from(_frequencyDays);
        break;
    }

    ref
        .read(habitsProvider.notifier)
        .saveHabit(
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
