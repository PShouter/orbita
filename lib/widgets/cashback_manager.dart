import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CashbackManager extends StatefulWidget {
  final bool isDark;
  final Color cardColor;
  final Color nestedColor;
  final Color textColor;
  final Color accentColor;

  const CashbackManager({
    super.key,
    required this.isDark,
    required this.cardColor,
    required this.nestedColor,
    required this.textColor,
    required this.accentColor,
  });

  @override
  State<CashbackManager> createState() => _CashbackManagerState();
}

class _BankCondition {
  String name;
  List<Map<String, dynamic>> rates;

  _BankCondition({required this.name, required this.rates});

  Map<String, dynamic> toJson() => {
        'name': name,
        'rates': rates,
      };

  static _BankCondition fromJson(Map<String, dynamic> json) => _BankCondition(
        name: json['name'] as String? ?? '',
        rates: List<Map<String, dynamic>>.from(
          (json['rates'] as List? ?? []).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        ),
      );
}

class _CashbackManagerState extends State<CashbackManager> {
  static const String _prefsKey = 'budget_cashback_banks';

  List<_BankCondition> _banks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        _banks = decoded
            .map((e) => _BankCondition.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        _banks = [];
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_banks.map((b) => b.toJson()).toList()),
    );
    if (mounted) setState(() {});
  }

  void _addBank(String name) {
    setState(() {
      _banks.add(
        _BankCondition(name: name, rates: const []),
      );
    });
    _save();
  }

  void _deleteBank(_BankCondition bank) {
    setState(() {
      _banks.remove(bank);
    });
    _save();
  }

  void _promptAddBank() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Новый банк',
          style: TextStyle(
            color: widget.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: widget.textColor),
          decoration: InputDecoration(
            hintText: 'Название банка',
            hintStyle: TextStyle(color: widget.textColor.withValues(alpha: 0.4)),
            labelText: 'Банк',
            labelStyle: TextStyle(color: widget.textColor.withValues(alpha: 0.6)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) _addBank(name);
              Navigator.pop(ctx);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _editRates(_BankCondition bank) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setMState) {
            final catCtrl = TextEditingController();
            final localRates = List<Map<String, dynamic>>.from(bank.rates);

            void commitRates() {
              bank.rates = List<Map<String, dynamic>>.from(localRates);
              _save();
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Кэшбэк · ${bank.name}',
                      style: TextStyle(
                        color: widget.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Введите процент возврата по категориям',
                      style: TextStyle(
                        color: widget.textColor.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final item in localRates) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['category'] as String? ?? '',
                              style: TextStyle(
                                color: widget.textColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 90,
                            child: TextField(
                              controller: TextEditingController(
                                text: item['percent']?.toString() ?? '0',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              style: TextStyle(color: widget.textColor),
                              decoration: InputDecoration(
                                suffixText: '%',
                                suffixStyle: TextStyle(
                                  color: widget.textColor
                                      .withValues(alpha: 0.5),
                                ),
                                isDense: true,
                                filled: true,
                                fillColor:
                                    widget.nestedColor.withValues(alpha: 0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: widget.nestedColor),
                                ),
                              ),
                              onChanged: (val) {
                                final v = double.tryParse(
                                      val.replaceAll(',', '.'),
                                    ) ??
                                    0;
                                item['percent'] = v;
                                commitRates();
                              },
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 18,
                              color: widget.textColor.withValues(alpha: 0.5),
                            ),
                            onPressed: () {
                              localRates.remove(item);
                              setMState(() {});
                              commitRates();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: catCtrl,
                            style: TextStyle(color: widget.textColor),
                            decoration: InputDecoration(
                              hintText: 'Новая категория',
                              hintStyle: TextStyle(
                                color: widget.textColor.withValues(alpha: 0.4),
                              ),
                              isDense: true,
                              filled: true,
                              fillColor:
                                  widget.nestedColor.withValues(alpha: 0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: widget.nestedColor),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: widget.accentColor,
                            side: BorderSide(color: widget.accentColor),
                          ),
                          onPressed: () {
                            final name = catCtrl.text.trim();
                            if (name.isEmpty) return;
                            if (localRates.any(
                              (r) =>
                                  (r['category'] as String? ?? '') == name,
                            )) {
                              return;
                            }
                            localRates.add({'category': name, 'percent': 0});
                            catCtrl.clear();
                            setMState(() {});
                            commitRates();
                          },
                          child: const Text('Добавить'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: widget.accentColor,
                              side: BorderSide(color: widget.accentColor),
                            ),
                            onPressed: () {
                              _save();
                              Navigator.pop(ctx);
                            },
                            child: const Text('Сохранить'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                            ),
                            onPressed: () {
                              _deleteBank(bank);
                              Navigator.pop(ctx);
                            },
                            child: const Text('Удалить банк'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Кэшбэк',
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: widget.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Свои банки и проценты по категориям',
                style: TextStyle(
                  fontFamily: 'Onest',
                  color: widget.textColor.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              if (_banks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: widget.cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: widget.nestedColor),
                  ),
                  child: Column(
                    children: [
                      const Text('💳', style: TextStyle(fontSize: 34)),
                      const SizedBox(height: 10),
                      Text(
                        'У вашего бюджета пока нет банков',
                        style: TextStyle(
                          color: widget.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Добавьте свои банки и укажите процент кэшбэка по категориям',
                        style: TextStyle(
                          color: widget.textColor.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ..._banks.map(
                  (bank) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => _editRates(bank),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: widget.cardColor,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: widget.nestedColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: widget.accentColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.account_balance,
                                color: widget.accentColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bank.name,
                                    style: TextStyle(
                                      color: widget.textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    bank.rates.isEmpty
                                        ? 'Категории не заданы'
                                        : '${bank.rates.length} категорий',
                                    style: TextStyle(
                                      color: widget.textColor.withValues(alpha: 0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: widget.textColor.withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: widget.isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _promptAddBank,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    'Добавить банк',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          );
  }
}