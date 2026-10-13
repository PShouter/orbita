import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'providers/shift_provider.dart';

class ShiftConstructorScreen extends ConsumerStatefulWidget {
  const ShiftConstructorScreen({super.key});

  @override
  ConsumerState<ShiftConstructorScreen> createState() =>
      _ShiftConstructorScreenState();
}

class _ShiftConstructorScreenState
    extends ConsumerState<ShiftConstructorScreen> {
  static const _uuid = Uuid();
  late TextEditingController _scheduleNameCtrl;
  late DateTime _startDate;
  late List<ShiftType> _types;
  late List<String> _cycle;

  static const List<Color> _palette = [
    Colors.redAccent,
    Colors.pinkAccent,
    Colors.purpleAccent,
    Colors.deepPurpleAccent,
    Colors.indigoAccent,
    Colors.blueAccent,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.amber,
    Colors.orangeAccent,
    Colors.deepOrangeAccent,
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    final schedule = ref.read(shiftProvider).activeSchedule;

    _scheduleNameCtrl = TextEditingController(
      text: schedule?.name ?? 'Основная работа',
    );
    _startDate = schedule?.startDate ?? DateTime.now();
    _types = List<ShiftType>.from(
      schedule?.customShiftTypes ?? [defaultWorkShift, defaultRestShift],
    );
    _cycle = List<String>.from(schedule?.cycleShiftIds ?? []);
  }

  @override
  void dispose() {
    _scheduleNameCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(String name) {
    final workShifts = _types.where((t) => t.isWork).toList();
    final restShifts = _types.where((t) => !t.isWork).toList();

    if (workShifts.isEmpty || restShifts.isEmpty) return;

    final workId = workShifts.first.id;
    final restId = restShifts.first.id;

    setState(() {
      switch (name) {
        case '2/2':
          _cycle = [workId, workId, restId, restId];
          break;
        case '3/3':
          _cycle = [workId, workId, workId, restId, restId, restId];
          break;
        case '1/2':
          _cycle = [workId, restId, restId];
          break;
        case '1/3':
          _cycle = [workId, restId, restId, restId];
          break;
        case '5/2':
          _cycle = [workId, workId, workId, workId, workId, restId, restId];
          break;
      }
    });
  }

  void _pickColorForShift(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Выберите цвет смены',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _palette.map((c) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _types[index] = _types[index].copyWith(color: c.value);
                      });
                      Navigator.pop(ctx);
                    },
                    child: CircleAvatar(
                      backgroundColor: c,
                      radius: 20,
                      child: (_types[index].color == c.value)
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addNewShiftType() {
    final newId = _uuid.v4();
    final newShift = ShiftType(
      id: newId,
      name: 'Новая смена',
      shortName: 'С',
      color: _palette[_types.length % _palette.length].value,
      isWork: true,
      startTime: '08:00',
      endTime: '20:00',
    );
    setState(() {
      _types.add(newShift);
    });
  }

  void _save() {
    ref
        .read(shiftProvider.notifier)
        .updateActiveSchedule(
          name: _scheduleNameCtrl.text.trim().isEmpty
              ? 'График'
              : _scheduleNameCtrl.text.trim(),
          startDate: _startDate,
          cycleShiftIds: _cycle,
          customShiftTypes: _types,
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final shiftState = ref.watch(shiftProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);

    final typesMap = {for (var t in _types) t.id: t};

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Настройка графика'),
        backgroundColor: bg,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Сохранить',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Название графика
          Card(
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _scheduleNameCtrl,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                decoration: const InputDecoration(
                  labelText: 'Название этого графика',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Дата начала цикла
          Card(
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.event, color: Color(0xFF38BDF8)),
              title: const Text('Дата начала цикла'),
              subtitle: Text(
                DateFormat('d MMMM yyyy', 'ru').format(_startDate),
              ),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
            ),
          ),
          const SizedBox(height: 16),

          // 3. Шаблоны пресетов
          const Text(
            'Готовые шаблоны',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['2/2', '3/3', '1/2', '1/3', '5/2'].map((preset) {
              return ActionChip(
                label: Text(preset),
                onPressed: () => _applyPreset(preset),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 4. Дни цикла
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Последовательность дней цикла',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (_cycle.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _cycle.clear()),
                  child: const Text(
                    'Очистить',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
            ],
          ),
          if (_cycle.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Цикл не задан (календарь будет пустым)',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_cycle.length, (i) {
                final shift = typesMap[_cycle[i]] ?? defaultRestShift;
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: Color(shift.color),
                    child: Text(
                      shift.shortName,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  label: Text('${i + 1}: ${shift.name}'),
                  onDeleted: () => setState(() => _cycle.removeAt(i)),
                );
              }),
            ),
          const SizedBox(height: 8),

          // Кнопки добавления смены в цепочку цикла
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _types.map((type) {
              return ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(type.color).withValues(alpha: 0.15),
                  foregroundColor: Color(type.color),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(type.name),
                onPressed: () => setState(() => _cycle.add(type.id)),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // 5. Динамический список типов смен
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Типы смен и цвета',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Добавить смену'),
                onPressed: _addNewShiftType,
              ),
            ],
          ),
          const SizedBox(height: 8),

          ..._types.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;

            return Card(
              color: cardBg,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Кружок выбора цвета смены
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _pickColorForShift(idx),
                          child: CircleAvatar(
                            backgroundColor: Color(item.color),
                            radius: 18,
                            child: const Icon(
                              Icons.palette_outlined,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Название смены
                        Expanded(
                          child: TextFormField(
                            initialValue: item.name,
                            decoration: const InputDecoration(
                              labelText: 'Название смены',
                              border: UnderlineInputBorder(),
                            ),
                            onChanged: (val) {
                              final trimmed = val.trim();
                              _types[idx] = item.copyWith(
                                name: trimmed.isEmpty ? 'Смена' : trimmed,
                                shortName: trimmed.isNotEmpty
                                    ? trimmed[0].toUpperCase()
                                    : 'С',
                              );
                            },
                          ),
                        ),
                        // Переключатель: Рабочая / Выходной
                        IconButton(
                          tooltip: item.isWork
                              ? 'Смена рабочая'
                              : 'Смена считается выходным',
                          icon: Icon(
                            item.isWork ? Icons.work : Icons.beach_access,
                            color: item.isWork ? Colors.amber : Colors.green,
                          ),
                          onPressed: () {
                            setState(() {
                              _types[idx] = item.copyWith(isWork: !item.isWork);
                            });
                          },
                        ),
                        if (_types.length > 1)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _cycle.removeWhere((id) => id == item.id);
                                _types.removeAt(idx);
                              });
                            },
                          ),
                      ],
                    ),
                    if (item.isWork) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: item.startTime,
                              decoration: const InputDecoration(
                                labelText: 'Начало (например 08:00)',
                              ),
                              onChanged: (val) {
                                _types[idx] = item.copyWith(
                                  startTime: val.trim(),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: item.endTime,
                              decoration: const InputDecoration(
                                labelText: 'Конец (например 20:00)',
                              ),
                              onChanged: (val) {
                                _types[idx] = item.copyWith(
                                  endTime: val.trim(),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          // 6. Удаление текущего графика (если их больше 1)
          if (shiftState.schedules.length > 1)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Удалить этот график'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Удалить график?'),
                    content: Text(
                      'Вы действительно хотите удалить "${_scheduleNameCtrl.text}"?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Отмена'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ref
                              .read(shiftProvider.notifier)
                              .deleteActiveSchedule();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Удалить',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
