import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/permission_service.dart';

class PermissionsOnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const PermissionsOnboardingScreen({super.key, required this.onComplete});

  @override
  State<PermissionsOnboardingScreen> createState() =>
      _PermissionsOnboardingScreenState();
}

class _PermissionsOnboardingScreenState
    extends State<PermissionsOnboardingScreen> {
  int _currentStep = 0;
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _steps = [
    {
      'icon': Icons.notifications_active_outlined,
      'title': 'Уведомления Орбиты',
      'subtitle': 'Чтобы вовремя получать напоминания о задачах, сменном графике и привычках',
      'button': 'Разрешить уведомления',
      'color': Color(0xFF38BDF8),
    },
    {
      'icon': Icons.alarm_on_outlined,
      'title': 'Точные будильники',
      'subtitle': 'Гарантирует доставку напоминаний минута в минуту, даже если телефон находится в спящем режиме',
      'button': 'Включить точные сигналы',
      'color': Color(0xFF8B5CF6),
    },
    {
      'icon': Icons.photo_library_outlined,
      'title': 'Доступ к галерее',
      'subtitle': 'Необходим для прикрепления изображений к заметкам и безопасного хранения документов в Сейфе',
      'button': 'Открыть доступ к фото',
      'color': Color(0xFF10B981),
    },
    {
      'icon': Icons.battery_charging_full_outlined,
      'title': 'Фоновая работа',
      'subtitle': 'Отключение жестких ограничений батареи Android позволит виджетам и синхронизации работать бесперебойно',
      'button': 'Разрешить работу в фоне',
      'color': Color(0xFFF59E0B),
    },
  ];

  Future<void> _handleStepAction() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();

    try {
      if (_currentStep == 0) {
        await PermissionService.requestNotifications();
      } else if (_currentStep == 1) {
        await PermissionService.requestExactAlarms();
      } else if (_currentStep == 2) {
        await PermissionService.requestPhotos();
      } else if (_currentStep == 3) {
        await PermissionService.requestIgnoreBatteryOptimizations();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      await _finishOnboarding();
    }
  }

  Future<void> _skipStep() async {
    HapticFeedback.selectionClick();
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      await _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    await PermissionService.markOnboardingCompleted();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final Color stepColor = step['color'] as Color;

    return Scaffold(
      backgroundColor: const Color(0xFF07090E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Верхний индикатор шагов
              Row(
                children: List.generate(_steps.length, (idx) {
                  final isDone = idx < _currentStep;
                  final isCurrent = idx == _currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? stepColor
                            : (isDone
                                  ? const Color(0xFF38BDF8)
                                  : Colors.white12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const Spacer(),

              // Анимированная центральная иконка
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: stepColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: stepColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  step['icon'] as IconData,
                  size: 48,
                  color: stepColor,
                ),
              ),
              const SizedBox(height: 32),

              // Название шага
              Text(
                step['title'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Поясняющий текст
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  step['subtitle'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const Spacer(),

              // Кнопка подтверждения действия
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: stepColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isProcessing ? null : _handleStepAction,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          step['button'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Кнопка пропустить
              TextButton(
                onPressed: _isProcessing ? null : _skipStep,
                child: const Text(
                  'Пропустить этот шаг',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
