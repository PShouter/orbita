import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Сервисы
import 'services/notification_service.dart';
import 'services/permission_service.dart';
import 'services/sync_service.dart';
import 'services/update_service.dart';

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

const String kSupabaseUrl = 'https://zttfujvamtcfkraotxif.supabase.co';
const String kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp0dGZ1anZhbXRjZmtyYW90eGlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA2MDk0ODksImV4cCI6MjEwNjE4NTQ4OX0.xLzvSDMuyuYCGmzyV7EKZhpjKhOc3Sb2JCYnZvMkeVs';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await NotificationService.instance.init(
      onSelectNotification: (payload) {
        _handleNotificationNavigation(payload);
      },
    );
  } catch (e) {
    debugPrint('Notification init notice: $e');
  }

  try {
    await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
  } catch (e) {
    debugPrint('Supabase init notice: $e');
  }

  try {
    SyncService.instance.initListener();
  } catch (e) {
    debugPrint('SyncService init notice: $e');
  }

  runApp(const ProviderScope(child: OrbitaApp()));
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

    if (profile.isCheckingAuth) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Орбита',
      debugShowCheckedModeBanner: false,
      themeMode: profile.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('ru', 'RU'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru', 'RU')],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF6F8FA),
        cardColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C69D1),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        cardColor: const Color(0xFF161B22),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
          surface: const Color(0xFF161B22),
        ),
      ),
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
              isDarkMode: profile.isDarkMode,
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
      final isDark = ref.read(profileProvider).isDarkMode;
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
          isDarkMode: profile.isDarkMode,
          userName: profile.userName,
          customUsername: profile.customUsername,
          userAvatarPath: profile.avatarPath,
          daysWithOrbita: profile.daysWithOrbita,
          onLogout: () => ref.read(profileProvider.notifier).logout(),
          onDeleteAccount: () => ref.read(profileProvider.notifier).logout(),
          onProfileUpdated: (newName, newUsername, newAvatarPath) {
            ref
                .read(profileProvider.notifier)
                .updateProfile(
                  newName: newName,
                  newUsername: newUsername,
                  newAvatarPath: newAvatarPath,
                );
          },
        ),
      ),
    );
  }

  Widget _buildSvgNavIcon(String path, bool isSelected) {
    final Color color = isSelected ? const Color(0xFF38BDF8) : Colors.grey;
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

    if (_isBudgetModeActive) {
      return BudgetScreen(
        isDarkMode: profile.isDarkMode,
        onExitBudget: () => setState(() => _isBudgetModeActive = false),
      );
    }

    final isDark = profile.isDarkMode;
    final textPrimary = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);

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
        icon: _buildSvgNavIcon('assets/icons/home.svg', _navIndex == 0),
        label: 'Главная',
      ),
    );

    // 2. Центральные настраиваемые вкладки
    for (int i = 0; i < activeTabs.length; i++) {
      final tabKey = activeTabs[i];
      final meta = kAllAvailableTabs.firstWhere((t) => t.key == tabKey);
      navItems.add(
        BottomNavigationBarItem(
          icon: _buildSvgNavIcon(meta.assetIcon, _navIndex == (i + 1)),
          label: meta.title,
        ),
      );
    }

    // 3. Еще (открывает Drawer)
    navItems.add(
      BottomNavigationBarItem(
        icon: _buildSvgNavIcon('assets/icons/more.svg', false),
        label: 'Еще',
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(profile, profileNotifier, isDark, textPrimary),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: const Row(
          children: [
            Icon(Icons.rocket_launch, color: Colors.orangeAccent, size: 22),
            SizedBox(width: 8),
            Text(
              'Орбита',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'Включить светлую тему' : 'Включить тёмную тему',
            icon: SvgPicture.asset(
              isDark
                  ? 'assets/icons/light theme.svg'
                  : 'assets/icons/dark theme.svg',
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(textPrimary, BlendMode.srcIn),
              placeholderBuilder: (_) => Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                size: 22,
                color: textPrimary,
              ),
            ),
            onPressed: () => profileNotifier.toggleTheme(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openProfileScreen(profile),
              child: SizedBox(
                width: 32,
                height: 32,
                child:
                    profile.avatarPath != null &&
                        File(profile.avatarPath!).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(profile.avatarPath!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : SvgPicture.asset(
                        'assets/icons/avatar.svg',
                        width: 32,
                        height: 32,
                        colorFilter: ColorFilter.mode(
                          textPrimary,
                          BlendMode.srcIn,
                        ),
                        placeholderBuilder: (_) => const CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(0xFF2C69D1),
                          child: Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.white,
                          ),
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
        selectedItemColor: const Color(0xFF38BDF8),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: navItems,
      ),
    );
  }

  Widget _buildDrawer(
    ProfileState profile,
    ProfileNotifier notifier,
    bool isDark,
    Color textPrimary,
  ) {
    final Color textSecondary = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

    final dynamicDrawerTabs = ref.watch(drawerTabsProvider);
    final activeBottomTabs = ref.watch(navigationTabsProvider);

    Widget buildDrawerIcon(String assetPath, IconData fallbackIcon) {
      return SvgPicture.asset(
        assetPath,
        width: 22,
        height: 22,
        colorFilter: ColorFilter.mode(textPrimary, BlendMode.srcIn),
        placeholderBuilder: (_) =>
            Icon(fallbackIcon, size: 22, color: textPrimary),
      );
    }

    return Drawer(
      backgroundColor: isDark
          ? const Color(0xFF0D1117)
          : const Color(0xFFF6F8FA),
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
                  color: cardBg,
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child:
                          profile.avatarPath != null &&
                              File(profile.avatarPath!).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: Image.file(
                                File(profile.avatarPath!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : SvgPicture.asset(
                              'assets/icons/avatar.svg',
                              width: 52,
                              height: 52,
                              colorFilter: ColorFilter.mode(
                                textPrimary,
                                BlendMode.srcIn,
                              ),
                              placeholderBuilder: (_) => const CircleAvatar(
                                radius: 26,
                                backgroundColor: Color(0xFF2C69D1),
                                child: Icon(
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
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '@${profile.customUsername}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: textSecondary, size: 20),
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
                      'assets/icons/avatar.svg',
                      Icons.person_outline,
                    ),
                    title: Text(
                      'Профиль',
                      style: TextStyle(
                        color: textPrimary,
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
                      leading: const Icon(
                        Icons.radar_outlined,
                        color: Color(0xFF38BDF8),
                        size: 22,
                      ),
                      title: Text(
                        'Орбитальная станция',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrbitalStationScreen(isDarkMode: isDark),
                          ),
                        );
                      },
                    ),

                  // 3. Друзья
                  ListTile(
                    leading: buildDrawerIcon(
                      'assets/icons/friends.svg',
                      Icons.people_outline,
                    ),
                    title: Text(
                      'Друзья',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FriendsScreen(
                            isDarkMode: isDark,
                            currentUsername: profile.customUsername,
                          ),
                        ),
                      );
                    },
                  ),

                  // 4. Сообщения
                  ListTile(
                    leading: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.grey,
                      size: 22,
                    ),
                    title: Row(
                      children: [
                        Text(
                          'Сообщения',
                          style: TextStyle(
                            color: textSecondary,
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
                          color: textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        if (tabMeta.key == AppTabKey.budget) {
                          setState(() => _isBudgetModeActive = true);
                        } else {
                          final screen = _getScreenWidget(tabMeta.key, isDark);
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
                      'assets/icons/settings.svg',
                      Icons.settings_outlined,
                    ),
                    title: Text(
                      'Настройки',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                            isDarkMode: isDark,
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
            Divider(color: borderColor, height: 1),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Версия: Demo 0.3.7',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    'Pavel Krikun',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
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
