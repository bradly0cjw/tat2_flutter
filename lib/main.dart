import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'src/services/ntut_api_service.dart';
import 'src/services/auth_service.dart';
import 'src/services/backend_api_service.dart';
import 'src/services/theme_settings_service.dart';
import 'src/services/navigation_config_service.dart';
import 'src/services/course_color_service.dart';
import 'src/providers/auth_provider_v2.dart';
import 'src/providers/calendar_provider.dart';
import 'src/core/auth/auth_manager.dart';
import 'src/adapters/ntut_school_adapter.dart';
import 'src/l10n/app_localizations.dart';
import 'ui/screens/login_screen.dart';
import 'src/pages/home_page.dart';
import 'ui/theme/app_theme.dart';

// 注意：HomePage 需要被導入到 LoginScreen 中
export 'src/pages/home_page.dart';

void main() async {
  // 確保 Flutter 綁定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 Hive 本地儲存
  await Hive.initFlutter();
  
  // 載入環境變數（.env 可能不存在，不強制要求）
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('無法載入 .env 檔案（將使用預設值）: $e');
  }
  
  // 初始化各項服務
  final themeSettings = ThemeSettingsService();
  await themeSettings.init();
  
  final navigationConfig = NavigationConfigService();
  await navigationConfig.init();
  
  final courseColorService = CourseColorService();
  await courseColorService.init();
  
  // 連接主題服務和課程顏色服務
  // 當主題色變更時，自動通知課程顏色服務重新渲染
  themeSettings.setCourseColorCallback(() {
    courseColorService.notifyThemeChanged();
  });
  
  runApp(MyApp(
    themeSettings: themeSettings,
    navigationConfig: navigationConfig,
    courseColorService: courseColorService,
  ));
}

class MyApp extends StatefulWidget {
  final ThemeSettingsService themeSettings;
  final NavigationConfigService navigationConfig;
  final CourseColorService courseColorService;
  
  const MyApp({
    super.key,
    required this.themeSettings,
    required this.navigationConfig,
    required this.courseColorService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final NtutApiService ntutApi;
  late final BackendApiService backendService;
  late final NtutSchoolAdapter schoolAdapter;
  late final AuthManager authManager;
  late final AuthService authService;
  late final AuthProviderV2 authProvider;

  @override
  void initState() {
    super.initState();
    
    // 創建核心服務實例
    ntutApi = NtutApiService();
    backendService = BackendApiService();
    
    // 創建 SchoolAdapter 和 AuthManager
    schoolAdapter = NtutSchoolAdapter(
      apiService: ntutApi,
      backendService: backendService,
    );
    authManager = AuthManager(schoolAdapter);
    
    // 創建向後兼容的 AuthService（注入 AuthManager）
    authService = AuthService(ntutApi, authManager: authManager);
    
    // 創建 Provider
    authProvider = AuthProviderV2(authManager: authManager);
    
    // 註冊生命週期監聽
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // 移除生命週期監聽
    WidgetsBinding.instance.removeObserver(this);
    
    // 清理 AuthManager 資源
    authManager.dispose();
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    debugPrint('[App] 生命週期變化: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App 從後台恢復到前台
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        // App 進入後台
        debugPrint('[App] 進入後台');
        break;
      case AppLifecycleState.inactive:
        // App 處於非活動狀態（例如來電）
        break;
      case AppLifecycleState.detached:
        // App 即將終止
        break;
      case AppLifecycleState.hidden:
        // App 被隱藏
        break;
    }
  }

  /// 當 App 從後台恢復時執行
  Future<void> _onAppResumed() async {
    debugPrint('[App] 從後台恢復');
    
    // 如果已登入，檢查 Session 是否過期
    if (authManager.isLoggedIn) {
      debugPrint('[App] 檢查 Session 狀態...');
      
      if (authManager.isSessionLikelyExpired) {
        debugPrint('[App] Session 可能已過期，嘗試自動刷新');
        
        try {
          final result = await authManager.relogin();
          if (result.success) {
            debugPrint('[App] Session 刷新成功');
          } else {
            debugPrint('[App] Session 刷新失敗: ${result.message}');
          }
        } catch (e) {
          debugPrint('[App] Session 刷新異常: $e');
        }
      } else {
        // Session 尚未過期，簡單檢查一下
        try {
          final isValid = await authManager.checkSession();
          if (!isValid) {
            debugPrint('[App] Session 無效，已嘗試自動刷新');
          }
        } catch (e) {
          debugPrint('[App] Session 檢查異常: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return MultiProvider(
      providers: [
        // 核心抽象層（推薦使用）
        Provider<AuthManager>.value(value: authManager),
        ChangeNotifierProvider<AuthProviderV2>.value(value: authProvider),
        
        // UI 服務層
        ChangeNotifierProvider<ThemeSettingsService>.value(value: widget.themeSettings),
        ChangeNotifierProvider<NavigationConfigService>.value(value: widget.navigationConfig),
        ChangeNotifierProvider<CourseColorService>.value(value: widget.courseColorService),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
        
        // 向後兼容層（舊代碼使用，新代碼請避免直接使用）
        Provider<NtutApiService>.value(value: ntutApi),
        Provider<BackendApiService>.value(value: backendService),
        Provider<AuthService>.value(value: authService),
      ],
      child: Consumer<ThemeSettingsService>(
        builder: (context, themeService, child) {
          final seedColor = themeService.getSeedColor();
          
          return MaterialApp(
            title: 'NTUT 課表查詢',
            theme: AppTheme.lightTheme(seedColor: seedColor),
            darkTheme: AppTheme.darkTheme(seedColor: seedColor),
            themeMode: themeService.themeMode,
            locale: themeService.locale,
            supportedLocales: const [
              Locale('zh', 'TW'), // 繁體中文
              Locale('en', 'US'), // 英文
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const HomePage(),
            routes: {
              '/login': (context) => const LoginScreen(),
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
