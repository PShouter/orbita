import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final AppReleaseInfo releaseInfo;

  const UpdateDialog({super.key, required this.releaseInfo});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  int _downloadPercent = 0;
  String _statusText = '';
  StreamSubscription<OtaEvent>? _otaSubscription;

  @override
  void dispose() {
    _otaSubscription?.cancel();
    super.dispose();
  }

  void _startOtaUpdate() {
    setState(() {
      _isDownloading = true;
      _downloadPercent = 0;
      _statusText = 'Подготовка к загрузке...';
    });

    try {
      _otaSubscription = UpdateService.instance
          .downloadAndInstall(apkUrl: widget.releaseInfo.apkUrl)
          .listen(
            (OtaEvent event) {
              if (!mounted) return;
              setState(() {
                switch (event.status) {
                  case OtaStatus.DOWNLOADING:
                    _downloadPercent =
                        int.tryParse(event.value ?? '0') ?? _downloadPercent;
                    _statusText = 'Загрузка: $_downloadPercent%';
                    break;
                  case OtaStatus.INSTALLING:
                    _statusText = 'Запуск установки пакета...';
                    break;
                  case OtaStatus.ALREADY_RUNNING_ERROR:
                    _statusText = 'Загрузка уже выполняется.';
                    break;
                  case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                    _isDownloading = false;
                    _statusText = 'Не выдано разрешение на установку APK.';
                    break;
                  case OtaStatus.INTERNAL_ERROR:
                  case OtaStatus.DOWNLOAD_ERROR:
                    _isDownloading = false;
                    _statusText = 'Сбой загрузки: проверьте соединение.';
                    break;
                  default:
                    break;
                }
              });
            },
            onError: (e) {
              if (!mounted) return;
              setState(() {
                _isDownloading = false;
                _statusText = 'Ошибка: $e';
              });
            },
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _statusText = 'Ошибка запуска: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.releaseInfo;

    return PopScope(
      canPop: !info.isMandatory && !_isDownloading,
      child: AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.system_update_alt_rounded,
                color: Color(0xFF38BDF8),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Новая версия!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Орбита ${info.versionName}',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Что нового:',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  info.releaseNotes,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              if (_isDownloading) ...[
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _downloadPercent > 0
                        ? (_downloadPercent / 100.0)
                        : null,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF38BDF8),
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _statusText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else if (_statusText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _statusText,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!info.isMandatory && !_isDownloading)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Позже',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          if (!_isDownloading)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _startOtaUpdate,
              child: const Text(
                'Обновить',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
