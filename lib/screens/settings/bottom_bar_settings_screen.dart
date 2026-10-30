import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../providers/navigation_tabs_provider.dart';

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
    final activeTabs = ref.watch(navigationTabsProvider);
    final notifier = ref.read(navigationTabsProvider.notifier);

    final bg = isDarkMode ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final cardBg = isDarkMode ? const Color(0xFF161B22) : Colors.white;
    final textPrimary = isDarkMode
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final textSecondary = isDarkMode
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final borderColor = isDarkMode
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

    final inactiveTabs = kAllAvailableTabs
        .where((t) => !activeTabs.contains(t.key))
        .toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Нижняя панель',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.touch_app_outlined,
                  color: Color(0xFF38BDF8),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Кнопки «Главная» и «Еще» всегда закреплены по краям. Вы можете выбрать от 1 до 4 разделов для центральной части панели и настроить их порядок.',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      height: 1.4,
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
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: ListTile(
              leading: _buildTabIcon(
                'assets/icons/home.svg',
                const Color(0xFF38BDF8),
              ),
              title: Text(
                'Главная',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Фиксировано',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text(
            'ЦЕНТРАЛЬНЫЕ РАЗДЕЛЫ (${activeTabs.length}/4)',
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
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
                    const Color(0xFF38BDF8),
                  ),
                  title: Text(
                    meta.title,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        tooltip: 'Убрать',
                        onPressed: () async {
                          final ok = await notifier.toggleTab(tabKey);
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'В центре должен остаться минимум 1 раздел',
                                ),
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
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),

          if (inactiveTabs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Все доступные разделы добавлены в нижнюю панель',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: inactiveTabs.map((meta) {
                  return ListTile(
                    leading: _buildTabIcon(meta.assetIcon, textSecondary),
                    title: Text(
                      meta.title,
                      style: TextStyle(color: textPrimary),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFF10B981),
                        size: 22,
                      ),
                      tooltip: 'Добавить',
                      onPressed: () async {
                        final ok = await notifier.toggleTab(meta.key);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Максимум 4 центральных раздела'),
                            ),
                          );
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
