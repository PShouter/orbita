import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../providers/shift_provider.dart';
import '../../theme/app_theme.dart';

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

  void _pickColorForShift(int index, AppColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Выберите цвет смены',
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _palette.map((c) {
                  final isCurrent = _types[index].color == c.toARGB32();
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _types[index] = _types[index].copyWith(
                          color: c.toARGB32(),
                        );
                      });
                      Navigator.pop(ctx);
                    },
                    child: CircleAvatar(
                      backgroundColor: c,
                      radius: 20,
                      child: isCurrent
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
      color: _palette[_types.length % _palette.length].toARGB32(),
      isWork: true,
      startTime: '08:00',
      endTime: '20:00',
    );
    setState(() {
      _types.add(newShift);
    });
  }

  void _save() {
    ref.read(shiftProvider.notifier).updateActiveSchedule(
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
    final colors = context.colors;
    final shiftState = ref.watch(shiftProvider);
    final typesMap = {for (var t in _types) t.id: t};

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(
          'Настройка графика',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        backgroundColor: colors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.text),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Сохранить',
              style: TextStyle(
                fontFamily: 'Onest',
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: colors.accent,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Название графика
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.nested),
            ),
            child: TextField(
              controller: _scheduleNameCtrl,
              style: TextStyle(
                fontFamily: 'Onest',
                color: colors.text,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                labelText: 'Название этого графика',
                labelStyle: TextStyle(
                  fontFamily: 'Onest',
                  color: colors.text.withValues(alpha: 0.6),
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2. Дата начала цикла
          Container(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.nested),
            ),
            child: ListTile(
              leading: Icon(Icons.event, color: colors.accent),
              title: Text(
                'Дата начала цикла',
                style: TextStyle(
                    fontFamily: 'Onest',
                    fontWeight: FontWeight.w600,
                    color: colors.text),
              ),
              subtitle: Text(
                DateFormat('d MMMM yyyy', 'ru').format(_startDate),
                style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.6)),
              ),
              trailing: Icon(Icons.edit_calendar, color: colors.accent),
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
          const SizedBox(height: 20),

          // 3. Шаблоны пресетов
          Text(
            'Готовые шаблоны',
            style: TextStyle(
              fontFamily: 'Unbounded',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['2/2', '3/3', '1/2', '1/3', '5/2'].map((preset) {
              return ActionChip(
                backgroundColor: colors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                  side: BorderSide(color: colors.nested),
                ),
                label: Text(
                  preset,
                  style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: colors.text),
                ),
                onPressed: () => _applyPreset(preset),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // 4. Дни цикла
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Дни цикла',
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              if (_cycle.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _cycle.clear()),
                  child: Text(
                    'Очистить',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
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
                  fontFamily: 'Onest',
                  color: colors.text.withValues(alpha: 0.5),
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
                  backgroundColor: colors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                    side: BorderSide(color: colors.nested),
                  ),
                  avatar: CircleAvatar(
                    backgroundColor: Color(shift.color),
                    child: Text(
                      shift.shortName,
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: ThemeData.estimateBrightnessForColor(
                                    Color(shift.color)) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  label: Text(
                    '${i + 1}: ${shift.name}',
                    style: TextStyle(fontFamily: 'Onest', color: colors.text),
                  ),
                  deleteIconColor: colors.text.withValues(alpha: 0.5),
                  onDeleted: () => setState(() => _cycle.removeAt(i)),
                );
              }),
            ),
          const SizedBox(height: 12),

          // Кнопки добавления смены в цепочку цикла
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _types.map((type) {
              return ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(type.color).withValues(alpha: 0.15),
                  foregroundColor: Color(type.color),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                    side: BorderSide(
                        color: Color(type.color).withValues(alpha: 0.4)),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  type.name,
                  style: const TextStyle(
                      fontFamily: 'Onest', fontWeight: FontWeight.w600),
                ),
                onPressed: () => setState(() => _cycle.add(type.id)),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // 5. Динамический список типов смен
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Типы смен и цвета',
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              TextButton.icon(
                icon: Icon(Icons.add, size: 18, color: colors.accent),
                label: Text(
                  'Добавить смену',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
                onPressed: _addNewShiftType,
              ),
            ],
          ),
          const SizedBox(height: 10),

          ..._types.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.nested),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _pickColorForShift(idx, colors),
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
                      Expanded(
                        child: TextFormField(
                          initialValue: item.name,
                          style: TextStyle(
                            fontFamily: 'Onest',
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Название смены',
                            labelStyle: TextStyle(
                              fontFamily: 'Onest',
                              color: colors.text.withValues(alpha: 0.6),
                            ),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: colors.nested),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: colors.accent, width: 2),
                            ),
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
                      IconButton(
                        tooltip: item.isWork
                            ? 'Смена рабочая'
                            : 'Смена считается выходным',
                        icon: Icon(
                          item.isWork ? Icons.work : Icons.beach_access,
                          color: item.isWork ? colors.warning : colors.success,
                        ),
                        onPressed: () {
                          setState(() {
                            _types[idx] = item.copyWith(isWork: !item.isWork);
                          });
                        },
                      ),
                      if (_types.length > 1)
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: colors.error,
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: item.startTime,
                            style: TextStyle(
                                fontFamily: 'Onest', color: colors.text),
                            decoration: InputDecoration(
                              labelText: 'Начало (например 08:00)',
                              labelStyle: TextStyle(
                                fontFamily: 'Onest',
                                color: colors.text.withValues(alpha: 0.6),
                              ),
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(color: colors.nested),
                              ),
                            ),
                            onChanged: (val) {
                              _types[idx] = item.copyWith(
                                startTime: val.trim(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            initialValue: item.endTime,
                            style: TextStyle(
                                fontFamily: 'Onest', color: colors.text),
                            decoration: InputDecoration(
                              labelText: 'Конец (например 20:00)',
                              labelStyle: TextStyle(
                                fontFamily: 'Onest',
                                color: colors.text.withValues(alpha: 0.6),
                              ),
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(color: colors.nested),
                              ),
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
            );
          }),

          const SizedBox(height: 16),

          // 6. Удаление текущего графика
          if (shiftState.schedules.length > 1)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.delete_forever),
              label: Text(
                'Удалить этот график',
                style: TextStyle(
                  fontFamily: 'Onest',
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: colors.card,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                    title: Text(
                      'Удалить график?',
                      style: TextStyle(
                        fontFamily: 'Unbounded',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    content: Text(
                      'Вы действительно хотите удалить "${_scheduleNameCtrl.text}"?',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.7),
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
                          backgroundColor: colors.error,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
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
                          style: TextStyle(
                            fontFamily: 'Onest',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
