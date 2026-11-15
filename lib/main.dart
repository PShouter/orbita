import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Сервисы
import 'services/notification_service.dart';
import 'services/permission_service.dart';
import 'services/sync_service.dart';
import 'services/update_service.dart';

// Тема и Дизайн-система
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';

// Провайдеры
import 'providers/profile_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/tasks_provider.dart';
import 'providers/habits_provider.dart';
import 'providers/diary_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/shift_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/gamification_provider.dart';
import 'providers/navigation_tabs_provider.dart';

// Виджеты диалогов
import 'widgets/update_dialog.dart';

// Экраны приложения
import 'screens/auth/auth_screen.dart';
import 'screens/onboarding/permissions_onboarding_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/budget/budget_screen.dart';
import 'screens/shifts/shift_schedule_screen.dart';
import 'screens/friends/friends_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/tasks/tasks_screen.dart';
import 'screens/notes/notes_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/habits/habits_screen.dart';
import 'screens/diary/diary_screen.dart';
import 'screens/vault/vault_screen.dart';
import 'screens/settings/settings_screen.dart';

import 'screens/gamification/orbital_station_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: OrbitaBootstrap()));
}

/// Показывает сплэш, пока идёт инициализация сервисов,
/// чтобы приложение не открывалось с пустым белым экраном.
class OrbitaBootstrap extends StatefulWidget {
  const OrbitaBootstrap({super.key});

  @override
  State<OrbitaBootstrap> createState() => _OrbitaBootstrapState();
}

class _OrbitaBootstrapState extends State<OrbitaBootstrap> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 1. Загрузка переменных окружения из .env
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint('DotEnv load notice: $e');
    }

    // 2. Инициализация уведомлений
    try {
      await NotificationService.instance.init(
        onSelectNotification: (payload) {
          _handleNotificationNavigation(payload);
        },
      );
    } catch (e) {
      debugPrint('Notification init notice: $e');
    }

    // 3. Инициализация Supabase через переменные окружения
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    try {
      if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
        await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      } else {
        debugPrint(
          'Supabase init warning: SUPABASE_URL или SUPABASE_ANON_KEY не найдены в .env',
        );
      }
    } catch (e) {
      debugPrint('Supabase init notice: $e');
    }

    // 4. Инициализация фоновой синхронизации
    try {
      SyncService.instance.initListener();
    } catch (e) {
      debugPrint('SyncService init notice: $e');
    }

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const OrbitaApp();
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OrbitaSplashScreen(),
    );
  }
}

class OrbitaSplashScreen extends StatelessWidget {
  const OrbitaSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D1117),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rocket_launch_rounded,
              size: 56,
              color: Color(0xFF5B8DEF),
            ),
            SizedBox(height: 16),
            Text(
              'Орбита',
              style: TextStyle(
                fontFamily: 'Unbounded',
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE6EDF3),
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 22),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF5B8DEF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _handleNotificationNavigation(String payload) {
  final navState = rootNavigatorKey.currentState;
  if (navState == null) return;

  switch (payload) {
    case 'screen_calendar':
      MainShell.switchTabByKey(AppTabKey.calendar);
      break;
    case 'screen_tasks':
      MainShell.switchTabByKey(AppTabKey.tasks);
      break;
    case 'screen_habits':
      MainShell.switchTabByKey(AppTabKey.habits);
      break;
    case 'screen_notes':
      MainShell.switchTabByKey(AppTabKey.notes);
      break;
    case 'screen_diary':
      MainShell.switchTabByKey(AppTabKey.diary);
      break;
    case 'screen_shifts':
      MainShell.switchTabByKey(AppTabKey.shifts);
      break;
    case 'screen_budget':
      MainShell.openBudgetMode();
      break;
    default:
      break;
  }
}

class OrbitaApp extends ConsumerStatefulWidget {
  const OrbitaApp({super.key});

  @override
  ConsumerState<OrbitaApp> createState() => _OrbitaAppState();
}

class _OrbitaAppState extends ConsumerState<OrbitaApp> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initAuthListener();
  }

  void _initAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        if (event == AuthChangeEvent.signedOut ||
            (event == AuthChangeEvent.tokenRefreshed && session == null)) {
          ref.read(profileProvider.notifier).logout();
        }
      },
      onError: (error) {
        debugPrint('Auth state error: $error');
        if (error is AuthException &&
            (error.statusCode == '401' ||
                error.message.contains('JWT expired'))) {
          Supabase.instance.client.auth.signOut();
          ref.read(profileProvider.notifier).logout();
        }
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final themeState = ref.watch(themeProvider);

    if (profile.isCheckingAuth) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // Определение активной палитры темы
    AppColorsExtension activePalette;
    if (themeState.followSystem) {
      final brightness = MediaQuery.platformBrightnessOf(context);
      activePalette = (brightness == Brightness.dark)
          ? AppColorsExtension.space
          : AppColorsExtension.dawn;
    } else {
      switch (themeState.currentTheme) {
        case AppThemeType.space:
          activePalette = AppColorsExtension.space;
          break;
        case AppThemeType.dawn:
          activePalette = AppColorsExtension.dawn;
          break;
        case AppThemeType.aurora:
          activePalette = AppColorsExtension.aurora;
          break;
        case AppThemeType.sunset:
          activePalette = AppColorsExtension.sunset;
          break;
        case AppThemeType.amoled:
          activePalette = AppColorsExtension.amoled;
          break;
      }
    }

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Орбита',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru', 'RU'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru', 'RU')],
      theme: buildThemeData(activePalette),
      // Глобальный пересчет масштабирования шрифта
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(themeState.scaleFactor)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: profile.isAuthenticated
          ? FutureBuilder<bool>(
              future: PermissionService.shouldShowOnboarding(),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final shouldShow = snapshot.data ?? false;
                if (shouldShow) {
                  return PermissionsOnboardingScreen(
                    onComplete: () {
                      rootNavigatorKey.currentState?.pushReplacement(
                        MaterialPageRoute(builder: (_) => const MainShell()),
                      );
                    },
                  );
                }
                return const MainShell();
              },
            )
          : AuthScreen(
              isDarkMode: activePalette.isDark,
              onAuthenticated: () async {
                ref.read(profileProvider.notifier).markAuthenticated();
                try {
                  await SyncService.instance.pullAllFromCloud(
                    forceReplace: true,
                  );
                  ref.read(calendarProvider.notifier).loadEvents();
                  ref.read(tasksProvider.notifier).loadTasks();
                  ref.read(habitsProvider.notifier).loadHabits();
                  ref.read(diaryProvider.notifier).loadDiaries();
                  ref.read(notesProvider.notifier).loadNotes();
                  ref.read(shiftProvider.notifier).loadSchedules();
                  ref.read(budgetProvider.notifier).loadAll();
                  ref.read(gamificationProvider.notifier).loadData();
                } catch (e) {
                  debugPrint('Ошибка первоначальной выгрузки: $e');
                }
              },
            ),
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  static _MainShellState? _instance;

  static void switchTab(int index) {
    _instance?.setNavIndex(index);
  }

  static void switchTabByKey(AppTabKey key) {
    _instance?.switchToKey(key);
  }

  static void openBudgetMode() {
    _instance?.setBudgetMode(true);
  }

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _navIndex = 0;
  bool _isBudgetModeActive = false;

  @override
  void initState() {
    super.initState();
    MainShell._instance = this;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final release = await UpdateService.instance.checkForUpdate();
        if (release != null && mounted) {
          showDialog(
            context: context,
            barrierDismissible: !release.isMandatory,
            builder: (_) => UpdateDialog(releaseInfo: release),
          );
        }
      } catch (e) {
        debugPrint('Ошибка фоновой проверки обновлений: $e');
      }
    });
  }

  @override
  void dispose() {
    if (MainShell._instance == this) {
      MainShell._instance = null;
    }
    super.dispose();
  }

  void setNavIndex(int index) {
    setState(() {
      _isBudgetModeActive = false;
      _navIndex = index;
    });
  }

  void switchToKey(AppTabKey key) {
    final activeTabs = ref.read(navigationTabsProvider);
    final idx = activeTabs.indexOf(key);
    if (idx != -1) {
      setNavIndex(idx + 1);
    } else {
      final isDark = context.colors.isDark;
      final widget = _getScreenWidget(key, isDark);
      if (widget != null) {
        rootNavigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => widget),
        );
      }
    }
  }

  void setBudgetMode(bool active) {
    setState(() {
      _isBudgetModeActive = active;
    });
  }

  void _openProfileScreen(ProfileState profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          isDarkMode: context.colors.isDark,
          userName: profile.userName,
          customUsername: profile.customUsername,
          userAvatarPath: profile.avatarPath,
          daysWithOrbita: profile.daysWithOrbita,
          onLogout: () => ref.read(profileProvider.notifier).logout(),
          onDeleteAccount: () => ref.read(profileProvider.notifier).logout(),
          onProfileUpdated: (newName, newUsername, newAvatarPath) {
            ref.read(profileProvider.notifier).updateProfile(
                  newName: newName,
                  newUsername: newUsername,
                  newAvatarPath: newAvatarPath,
                );
          },
        ),
      ),
    );
  }

  void _showNotificationsMenu(BuildContext context, AppColorsExtension colors) {
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.right - 280,
        position.top + 45,
        16,
        0,
      ),
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.nested),
      ),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Уведомления',
                style: TextStyle(
                  fontFamily: 'Onest',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: colors.text,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Орбита',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'sync',
          child: Row(
            children: [
              Icon(Icons.cloud_done, size: 18, color: colors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Синхронизация активна',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    Text(
                      'Все модули подключены к облаку',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 10,
                        color: colors.text.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'focus',
          child: Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: colors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Фокус дня обновлен',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    Text(
                      'Продуктивного дня на Орбите!',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 10,
                        color: colors.text.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSvgNavIcon(
    String path,
    bool isSelected,
    AppColorsExtension colors,
  ) {
    final Color color =
        isSelected ? colors.accent : colors.text.withValues(alpha: 0.4);
    return SvgPicture.asset(
      path,
      width: 20,
      height: 20,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      placeholderBuilder: (_) => Icon(Icons.circle, size: 20, color: color),
    );
  }

  Widget? _getScreenWidget(AppTabKey key, bool isDark) {
    switch (key) {
      case AppTabKey.calendar:
        return CalendarScreen(isDarkMode: isDark);
      case AppTabKey.tasks:
        return TasksScreen(isDarkMode: isDark);
      case AppTabKey.habits:
        return HabitsScreen(isDarkMode: isDark);
      case AppTabKey.notes:
        return NotesScreen(isDarkMode: isDark);
      case AppTabKey.diary:
        return DiaryScreen(isDarkMode: isDark);
      case AppTabKey.shifts:
        return ShiftScheduleScreen(isDarkMode: isDark);
      case AppTabKey.vault:
        return VaultScreen(isDarkMode: isDark);
      case AppTabKey.budget:
        return BudgetScreen(
          isDarkMode: isDark,
          onExitBudget: () => setNavIndex(0),
        );
      case AppTabKey.station:
        return OrbitalStationScreen(isDarkMode: isDark);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final profileNotifier = ref.read(profileProvider.notifier);
    final activeTabs = ref.watch(navigationTabsProvider);
    final colors = context.colors;
    final isDark = colors.isDark;

    if (_isBudgetModeActive) {
      return BudgetScreen(
        isDarkMode: isDark,
        onExitBudget: () => setState(() => _isBudgetModeActive = false),
      );
    }

    final maxValidIndex = activeTabs.length;
    if (_navIndex > maxValidIndex) {
      _navIndex = 0;
    }

    Widget currentScreen;
    if (_navIndex == 0) {
      currentScreen = HomeScreen(
        isDarkMode: isDark,
        onOpenCreateTask: () => switchToKey(AppTabKey.tasks),
        onOpenCreateEvent: () => switchToKey(AppTabKey.calendar),
        onOpenCreateHabit: () => switchToKey(AppTabKey.habits),
        onOpenBudget: () => setState(() => _isBudgetModeActive = true),
      );
    } else {
      final tabKey = activeTabs[_navIndex - 1];
      currentScreen =
          _getScreenWidget(tabKey, isDark) ?? const SizedBox.shrink();
    }

    final navItems = <BottomNavigationBarItem>[];

    // 1. Главная
    navItems.add(
      BottomNavigationBarItem(
        icon: _buildSvgNavIcon(
            'assets/icons/norm/home.svg',
            _navIndex == 0,
            colors,
          ),
        label: 'Главная',
      ),
    );

    // 2. Центральные настраиваемые вкладки
    for (int i = 0; i < activeTabs.length; i++) {
      final tabKey = activeTabs[i];
      final meta = kAllAvailableTabs.firstWhere((t) => t.key == tabKey);
      navItems.add(
        BottomNavigationBarItem(
          icon: _buildSvgNavIcon(meta.assetIcon, _navIndex == (i + 1), colors),
          label: meta.title,
        ),
      );
    }

    // 3. Еще (открывает Drawer)
    navItems.add(
      BottomNavigationBarItem(
        icon: _buildSvgNavIcon(
            'assets/icons/norm/more.svg',
            false,
            colors,
          ),
        label: 'Еще',
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.bg,
      drawer: _buildDrawer(profile, profileNotifier, colors),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: colors.bg,
        elevation: 0,
        titleSpacing: 16,
        title: Text(
          'ОРБИТА',
          style: TextStyle(
            fontFamily: 'Ethnocentric',
            color: colors.text,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          // 2-й справа налево: Уведомления
          Builder(
            builder: (btnContext) {
              return IconButton(
                tooltip: 'Уведомления',
                icon: SvgPicture.asset(
                  'assets/icons/norm/Notification.svg',
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(colors.text, BlendMode.srcIn),
                  placeholderBuilder: (_) => Icon(
                    Icons.notifications_none_outlined,
                    color: colors.text,
                    size: 22,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showNotificationsMenu(btnContext, colors);
                },
              );
            },
          ),

          // 1-й справа налево: Профиль
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openProfileScreen(profile),
              child: SizedBox(
                width: 34,
                height: 34,
                child: profile.avatarPath != null &&
                        File(profile.avatarPath!).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: Image.file(
                          File(profile.avatarPath!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : CircleAvatar(
                        radius: 17,
                        backgroundColor: colors.accent.withValues(alpha: 0.2),
                        child: SvgPicture.asset(
                          'assets/icons/norm/profile.svg',
                          width: 20,
                          height: 20,
                          colorFilter:
                              ColorFilter.mode(colors.text, BlendMode.srcIn),
                          placeholderBuilder: (_) =>
                              Icon(Icons.person, size: 20, color: colors.text),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: currentScreen,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) {
          if (i == activeTabs.length + 1) {
            _scaffoldKey.currentState?.openDrawer();
          } else {
            setState(() => _navIndex = i);
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: colors.card,
        selectedItemColor: colors.accent,
        unselectedItemColor: colors.text.withValues(alpha: 0.4),
        selectedLabelStyle: const TextStyle(
          fontFamily: 'Onest',
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Onest'),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: navItems,
      ),
    );
  }

  Widget _buildDrawer(
    ProfileState profile,
    ProfileNotifier notifier,
    AppColorsExtension colors,
  ) {
    final dynamicDrawerTabs = ref.watch(drawerTabsProvider);
    final activeBottomTabs = ref.watch(navigationTabsProvider);

    Widget buildDrawerIcon(String assetPath, IconData fallbackIcon) {
      return SvgPicture.asset(
        assetPath,
        width: 22,
        height: 22,
        colorFilter: ColorFilter.mode(colors.text, BlendMode.srcIn),
        placeholderBuilder: (_) =>
            Icon(fallbackIcon, size: 22, color: colors.text),
      );
    }

    return Drawer(
      backgroundColor: colors.bg,
      child: SafeArea(
        child: Column(
          children: [
            // 1. Профиль
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _openProfileScreen(profile);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: colors.card,
                  border: Border(bottom: BorderSide(color: colors.nested)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: profile.avatarPath != null &&
                              File(profile.avatarPath!).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: Image.file(
                                File(profile.avatarPath!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : SvgPicture.asset(
                              'assets/icons/norm/profile.svg',
                              width: 52,
                              height: 52,
                              colorFilter: ColorFilter.mode(
                                colors.text,
                                BlendMode.srcIn,
                              ),
                              placeholderBuilder: (_) => CircleAvatar(
                                radius: 26,
                                backgroundColor: colors.accent,
                                child: const Icon(
                                  Icons.person,
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.userName,
                            style: TextStyle(
                              fontFamily: 'Onest',
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '@${profile.customUsername}',
                            style: TextStyle(
                              fontFamily: 'Onest',
                              fontSize: 13,
                              color: colors.accent,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: colors.text.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Список пунктов бокового меню
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  // 1. Профиль
                  ListTile(
                    leading: buildDrawerIcon(
                      'assets/icons/norm/profile.svg',
                      Icons.person_outline,
                    ),
                    title: Text(
                      'Профиль',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _openProfileScreen(profile);
                    },
                  ),

                  // 2. Орбитальная станция
                  if (!activeBottomTabs.contains(AppTabKey.station))
                    ListTile(
                      leading: Icon(
                        Icons.radar_outlined,
                        color: colors.accent,
                        size: 22,
                      ),
                      title: Text(
                        'Орбитальная станция',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrbitalStationScreen(isDarkMode: colors.isDark),
                          ),
                        );
                      },
                    ),

                  // 3. Друзья
                  ListTile(
                    leading: buildDrawerIcon(
                      'assets/icons/svg-icons/profiles-and-users-filled/users-profiles-01.svg',
                      Icons.people_outline,
                    ),
                    title: Text(
                      'Друзья',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FriendsScreen(
                            isDarkMode: colors.isDark,
                            currentUsername: profile.customUsername,
                          ),
                        ),
                      );
                    },
                  ),

                  // 4. Сообщения
                  ListTile(
                    leading: buildDrawerIcon(
                      'assets/icons/norm/message.svg',
                      Icons.chat_bubble_outline_rounded,
                    ),
                    title: Row(
                      children: [
                        Text(
                          'Сообщения',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            color: colors.text.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Скоро',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Раздел сообщений в разработке'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),

                  const Divider(),

                  // 5–12. Динамические разделы
                  ...dynamicDrawerTabs.map((tabMeta) {
                    return ListTile(
                      leading: buildDrawerIcon(
                        tabMeta.assetIcon,
                        Icons.circle_outlined,
                      ),
                      title: Text(
                        tabMeta.title,
                        style: TextStyle(
                          fontFamily: 'Onest',
                          color: colors.text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        if (tabMeta.key == AppTabKey.budget) {
                          setState(() => _isBudgetModeActive = true);
                        } else {
                          final screen = _getScreenWidget(
                            tabMeta.key,
                            colors.isDark,
                          );
                          if (screen != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => screen),
                            );
                          }
                        }
                      },
                    );
                  }),

                  const Divider(),

                  // 13. Настройки
                  ListTile(
                    leading: buildDrawerIcon(
                      'assets/icons/norm/settings.svg',
                      Icons.settings_outlined,
                    ),
                    title: Text(
                      'Настройки',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                            isDarkMode: colors.isDark,
                            onToggleTheme: () => notifier.toggleTheme(),
                            userName: profile.userName,
                            customUsername: profile.customUsername,
                            onProfileUpdated: (newName, newUsername) {
                              notifier.updateProfile(
                                newName: newName,
                                newUsername: newUsername,
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Divider(color: colors.nested, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Версия: Demo 0.4.2',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Pavel Krikun',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
