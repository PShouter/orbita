import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Сервисы
import 'notification_service.dart';
import 'services/sync_service.dart';

// Экраны приложения
import 'auth_screen.dart';
import 'profile_screen.dart';
import 'budget_screen.dart';
import 'shift_schedule_screen.dart';
import 'friends_screen.dart';
import 'app_info_screen.dart';
import 'home_screen.dart';
import 'tasks_screen.dart';
import 'notes_screen.dart';
import 'calendar_screen.dart';
import 'habits_screen.dart';
import 'diary_screen.dart';
import 'vault_screen.dart';
import 'settings_screen.dart';

// Конфигурация Supabase
const String kSupabaseUrl = 'https://zttfujvamtcfkraotxif.supabase.co';
const String kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp0dGZ1anZhbXRjZmtyYW90eGlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA2MDk0ODksImV4cCI6MjEwNjE4NTQ4OX0.xLzvSDMuyuYCGmzyV7EKZhpjKhOc3Sb2JCYnZvMkeVs';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация сервиса локальных уведомлений
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('Notification init notice: $e');
  }

  // Инициализация фоновой синхронизации
  try {
    SyncService.instance.initListener();
  } catch (e) {
    debugPrint('SyncService init notice: $e');
  }

  // Инициализация Supabase
  try {
    await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
  } catch (e) {
    debugPrint('Supabase init notice: $e');
  }

  runApp(const ProviderScope(child: OrbitaApp()));
}

final supabase = Supabase.instance.client;

class OrbitaApp extends StatefulWidget {
  const OrbitaApp({super.key});

  @override
  State<OrbitaApp> createState() => _OrbitaAppState();
}

class _OrbitaAppState extends State<OrbitaApp> {
  bool _isDarkMode = false;
  bool _isAuthenticated = false;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;

    final session = supabase.auth.currentSession;
    final isGuest = prefs.getBool('is_guest_mode') ?? false;

    setState(() {
      _isDarkMode = isDark;
      _isAuthenticated = session != null || isGuest;
      _isCheckingAuth = false;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await prefs.setBool('is_dark_mode', _isDarkMode);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await supabase.auth.signOut();
    await prefs.setBool('is_guest_mode', false);
    setState(() {
      _isAuthenticated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Орбита',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
      home: _isAuthenticated
          ? MainShell(
              isDarkMode: _isDarkMode,
              onToggleTheme: _toggleTheme,
              onLogout: _logout,
            )
          : AuthScreen(
              isDarkMode: _isDarkMode,
              onAuthenticated: () => setState(() => _isAuthenticated = true),
            ),
    );
  }
}

class MainShell extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;

  const MainShell({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onLogout,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _navIndex = 0;
  bool _isBudgetModeActive = false;

  String _userName = 'Пользователь';
  String _customUsername = 'orbita_user';
  String? _userAvatarPath;
  int _daysWithOrbita = 1;
  String? _savedVaultPin;

  final List<Map<String, dynamic>> _taskTemplates = [];
  final List<Map<String, dynamic>> _documents = [];

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_full_name') ?? 'Пользователь';
      _customUsername =
          prefs.getString('user_custom_username') ?? 'orbita_user';
      _userAvatarPath = prefs.getString('user_avatar_path');
      _savedVaultPin = prefs.getString('vault_pin');

      int? regTimestamp = prefs.getInt('registration_timestamp');

      final currentUser = supabase.auth.currentUser;
      if (currentUser?.createdAt != null) {
        final parsedCreated = DateTime.tryParse(currentUser!.createdAt);
        if (parsedCreated != null) {
          regTimestamp = parsedCreated.millisecondsSinceEpoch;
          prefs.setInt('registration_timestamp', regTimestamp);
        }
      }

      final now = DateTime.now();
      final cleanNow = DateTime(now.year, now.month, now.day);

      if (regTimestamp == null) {
        prefs.setInt('registration_timestamp', now.millisecondsSinceEpoch);
        _daysWithOrbita = 1;
      } else {
        final regDate = DateTime.fromMillisecondsSinceEpoch(regTimestamp);
        final cleanReg = DateTime(regDate.year, regDate.month, regDate.day);

        final diff = cleanNow.difference(cleanReg).inDays;
        _daysWithOrbita = (diff >= 0 ? diff : 0) + 1;
      }
    });
  }

  void _openProfileScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          isDarkMode: widget.isDarkMode,
          userName: _userName,
          customUsername: _customUsername,
          userAvatarPath: _userAvatarPath,
          daysWithOrbita: _daysWithOrbita,
          onLogout: widget.onLogout,
          onDeleteAccount: widget.onLogout,
          onProfileUpdated: (newName, newUsername, newAvatarPath) {
            setState(() {
              _userName = newName;
              _customUsername = newUsername;
              _userAvatarPath = newAvatarPath;
            });
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

  @override
  Widget build(BuildContext context) {
    if (_isBudgetModeActive) {
      return BudgetScreen(
        isDarkMode: widget.isDarkMode,
        onExitBudget: () => setState(() => _isBudgetModeActive = false),
      );
    }

    final isDark = widget.isDarkMode;
    final textPrimary = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(isDark, textPrimary),
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
            onPressed: widget.onToggleTheme,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _openProfileScreen,
              child: SizedBox(
                width: 32,
                height: 32,
                child:
                    _userAvatarPath != null &&
                        File(_userAvatarPath!).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(_userAvatarPath!),
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
                        placeholderBuilder: (_) => CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF2C69D1),
                          child: Icon(
                            Icons.person,
                            size: 18,
                            color: textPrimary,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: _buildCurrentBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) {
          if (i == 6) {
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
        items: [
          BottomNavigationBarItem(
            icon: _buildSvgNavIcon('assets/icons/home.svg', _navIndex == 0),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: _buildSvgNavIcon('assets/icons/calendar.svg', _navIndex == 1),
            label: 'Календарь',
          ),
          BottomNavigationBarItem(
            icon: _buildSvgNavIcon('assets/icons/task.svg', _navIndex == 2),
            label: 'Задачи',
          ),
          BottomNavigationBarItem(
            icon: _buildSvgNavIcon('assets/icons/habits.svg', _navIndex == 3),
            label: 'Привычки',
          ),
          BottomNavigationBarItem(
            icon: _buildSvgNavIcon('assets/icons/note.svg', _navIndex == 4),
            label: 'Заметки',
          ),
          BottomNavigationBarItem(
            icon: _buildSvgNavIcon('assets/icons/diary.svg', _navIndex == 5),
            label: 'Дневник',
          ),
          BottomNavigationBarItem(
            icon: _buildSvgNavIcon('assets/icons/more.svg', false),
            label: 'Еще',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBody() {
    switch (_navIndex) {
      case 0:
        return HomeScreen(
          isDarkMode: widget.isDarkMode,
          userName: _userName,
          daysWithOrbita: _daysWithOrbita,
          onOpenCreateTask: () => setState(() => _navIndex = 2),
          onOpenCreateEvent: () => setState(() => _navIndex = 1),
          onOpenCreateHabit: () => setState(() => _navIndex = 3),
          onOpenBudget: () => setState(() => _isBudgetModeActive = true),
        );
      case 1:
        return CalendarScreen(isDarkMode: widget.isDarkMode);
      case 2:
        return TasksScreen(
          isDarkMode: widget.isDarkMode,
          taskTemplates: _taskTemplates,
          onSaveTemplate: (tpl) {
            setState(() => _taskTemplates.add(tpl));
          },
        );
      case 3:
        return HabitsScreen(isDarkMode: widget.isDarkMode);
      case 4:
        return NotesScreen(isDarkMode: widget.isDarkMode);
      case 5:
        return DiaryScreen(isDarkMode: widget.isDarkMode);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDrawer(bool isDark, Color textPrimary) {
    final Color textSecondary = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

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
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _openProfileScreen();
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
                          _userAvatarPath != null &&
                              File(_userAvatarPath!).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: Image.file(
                                File(_userAvatarPath!),
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
                            _userName,
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
                            '@$_customUsername',
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  ListTile(
                    leading: buildDrawerIcon(
                      'assets/icons/avatar.svg',
                      Icons.person_outline,
                    ),
                    title: Text(
                      'Мой профиль',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _openProfileScreen();
                    },
                  ),
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
                            isDarkMode: widget.isDarkMode,
                            currentUsername: _customUsername,
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: buildDrawerIcon(
                      'assets/icons/work.svg',
                      Icons.calendar_view_month,
                    ),
                    title: Text(
                      'График смен',
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
                          builder: (_) => ShiftScheduleScreen(
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: buildDrawerIcon(
                      'assets/icons/vault.svg',
                      Icons.shield_outlined,
                    ),
                    title: Text(
                      'Сейф',
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
                          builder: (_) => VaultScreen(
                            isDarkMode: widget.isDarkMode,
                            savedVaultPin: _savedVaultPin,
                            documents: _documents,
                            onPinCreated: (p) =>
                                setState(() => _savedVaultPin = p),
                            onSaveDocuments: () {},
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: buildDrawerIcon(
                      'assets/icons/budget.svg',
                      Icons.account_balance_wallet_outlined,
                    ),
                    title: Text(
                      'Бюджет',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _isBudgetModeActive = true);
                    },
                  ),
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
                            isDarkMode: widget.isDarkMode,
                            onToggleTheme: widget.onToggleTheme,
                            userName: _userName,
                            customUsername: _customUsername,
                            onProfileUpdated: (newName, newUsername) {
                              setState(() {
                                _userName = newName;
                                _customUsername = newUsername;
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: buildDrawerIcon(
                      'assets/icons/info.svg',
                      Icons.info_outline,
                    ),
                    title: Text(
                      'О приложении',
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
                          builder: (_) =>
                              AppInfoScreen(isDarkMode: widget.isDarkMode),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.logout,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                    title: const Text(
                      'Выйти из аккаунта',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onLogout();
                    },
                  ),
                ],
              ),
            ),
            Divider(color: borderColor, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Версия: Global Demo 0.3.0',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    'Pavel Krikun',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
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
