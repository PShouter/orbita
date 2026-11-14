import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/permission_service.dart';
import '../../theme/app_theme.dart';

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
      'subtitle':
          'Чтобы вовремя получать напоминания о задачах, сменном графике и привычках',
      'button': 'Разрешить уведомления',
      'colorType': 'accent',
    },
    {
      'icon': Icons.alarm_on_outlined,
      'title': 'Точные будильники',
      'subtitle':
          'Гарантирует доставку напоминаний минута в минуту, даже если телефон находится в спящем режиме',
      'button': 'Включить точные сигналы',
      'colorType': 'accent',
    },
    {
      'icon': Icons.photo_library_outlined,
      'title': 'Доступ к галерее',
      'subtitle':
          'Необходим для прикрепления изображений к заметкам и безопасного хранения документов в Сейфе',
      'button': 'Открыть доступ к фото',
      'colorType': 'success',
    },
    {
      'icon': Icons.battery_charging_full_outlined,
      'title': 'Фоновая работа',
      'subtitle':
          'Отключение жестких ограничений батареи Android позволит виджетам и синхронизации работать бесперебойно',
      'button': 'Разрешить работу в фоне',
      'colorType': 'warning',
    },
  ];

  Color _resolveStepColor(String colorType, AppColorsExtension colors) {
    switch (colorType) {
      case 'success':
        return colors.success;
      case 'warning':
        return colors.warning;
      case 'accent':
      default:
        return colors.accent;
    }
  }

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
    final colors = context.colors;
    final step = _steps[_currentStep];
    final Color stepColor = _resolveStepColor(step['colorType'] as String, colors);

    return Scaffold(
      backgroundColor: colors.bg,
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
                                ? colors.accent
                                : colors.nested.withValues(alpha: 0.8)),
                        borderRadius: BorderRadius.circular(13),
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
                    color: stepColor.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
                child: Icon(
                  step['icon'] as IconData,
                  size: 46,
                  color: stepColor,
                ),
              ),
              const SizedBox(height: 32),

              // Название шага
              Text(
                step['title'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  color: colors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
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
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.65),
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
                    foregroundColor:
                        ThemeData.estimateBrightnessForColor(stepColor) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isProcessing ? null : _handleStepAction,
                  child: _isProcessing
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color:
                                ThemeData.estimateBrightnessForColor(stepColor) ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          step['button'] as String,
                          style: const TextStyle(
                            fontFamily: 'Onest',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Кнопка пропустить
              TextButton(
                onPressed: _isProcessing ? null : _skipStep,
                child: Text(
                  'Пропустить этот шаг',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}