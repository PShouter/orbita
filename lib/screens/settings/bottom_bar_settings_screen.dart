import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../providers/navigation_tabs_provider.dart';
import '../../theme/app_theme.dart';

class BottomBarSettingsScreen extends ConsumerWidget {
  final bool isDarkMode;

  const BottomBarSettingsScreen({super.key, required this.isDarkMode});

  Widget _buildTabIcon(String assetPath, Color color) {
    return SvgPicture.asset(
      assetPath,
      width: 22,
      height: 22,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      placeholderBuilder: (_) => Icon(Icons.circle, size: 22, color: color),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final activeTabs = ref.watch(navigationTabsProvider);
    final notifier = ref.read(navigationTabsProvider.notifier);

    final textPrimary = colors.text;
    final textSecondary = colors.text.withValues(alpha: 0.6);
    final cardBg = colors.card;
    final borderColor = colors.nested;

    final inactiveTabs =
        kAllAvailableTabs.where((t) => !activeTabs.contains(t.key)).toList();

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          'Нижняя панель',
          style: TextStyle(
            fontFamily: 'Unbounded',
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: textPrimary),
        actions: [
          IconButton(
            tooltip: 'По умолчанию',
            icon: Icon(Icons.restore, color: textSecondary),
            onPressed: () => notifier.resetToDefaults(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colors.accent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  color: colors.accent,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Кнопки «Главная» и «Еще» всегда закреплены по краям. Вы можете выбрать от 1 до 4 разделов для центральной части панели и настроить их порядок.',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textPrimary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'ЗАКРЕПЛЕНА ПЕРВОЙ',
            style: TextStyle(
              fontFamily: 'Onest',
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: ListTile(
              leading: _buildTabIcon(
                'assets/icons/home.svg',
                colors.accent,
              ),
              title: Text(
                'Главная',
                style: TextStyle(
                  fontFamily: 'Onest',
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.nested.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  'Фиксировано',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontSize: 11,
                    color: textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ЦЕНТРАЛЬНЫЕ РАЗДЕЛЫ (${activeTabs.length}/4)',
            style: TextStyle(
              fontFamily: 'Onest',
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeTabs.length,
              onReorder: notifier.reorder,
              itemBuilder: (ctx, index) {
                final tabKey = activeTabs[index];
                final meta = kAllAvailableTabs.firstWhere(
                  (t) => t.key == tabKey,
                );

                return ListTile(
                  key: ValueKey(tabKey),
                  leading: _buildTabIcon(
                    meta.assetIcon,
                    colors.accent,
                  ),
                  title: Text(
                    meta.title,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: colors.error,
                          size: 20,
                        ),
                        tooltip: 'Убрать',
                        onPressed: () async {
                          final ok = await notifier.toggleTab(tabKey);
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'В центре должен остаться минимум 1 раздел',
                                  style: TextStyle(fontFamily: 'Onest'),
                                ),
                                backgroundColor: colors.error,
                              ),
                            );
                          }
                        },
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: Icon(Icons.drag_handle, color: textSecondary),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ДОСТУПНЫЕ ДЛЯ ДОБАВЛЕНИЯ',
            style: TextStyle(
              fontFamily: 'Onest',
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          if (inactiveTabs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Все доступные разделы добавлены в нижнюю панель',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: inactiveTabs.map((meta) {
                  return ListTile(
                    leading: _buildTabIcon(meta.assetIcon, textSecondary),
                    title: Text(
                      meta.title,
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: colors.success,
                        size: 22,
                      ),
                      tooltip: 'Добавить',
                      onPressed: () async {
                        final ok = await notifier.toggleTab(meta.key);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Максимум 4 центральных раздела',
                                style: TextStyle(fontFamily: 'Onest'),
                              ),
                              backgroundColor: colors.warning,
                            ),
                          );
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
