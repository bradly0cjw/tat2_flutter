import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../ui/theme/app_theme.dart';

/// 主題設定服務
class ThemeSettingsService extends ChangeNotifier {
  static const String _boxName = 'theme_settings';
  static const String _themeModeKey = 'theme_mode';
  static const String _localeKey = 'locale';
  static const String _themeColorKey = 'theme_color';
  Box? _box;
  
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale; // null 表示跟隨系統
  String _themeColorId = 'blue'; // 預設藍色主題
  
  // 課程顏色服務的回調，用於通知主題色變更
  Function()? _onThemeColorChanged;
  
  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;
  String get themeColorId => _themeColorId;
  
  /// 設定課程顏色服務的回調
  void setCourseColorCallback(Function() callback) {
    _onThemeColorChanged = callback;
  }
  
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _loadThemeMode();
    _loadLocale();
    _loadThemeColor();
  }
  
  void _loadThemeMode() {
    if (_box == null) return;
    
    final savedMode = _box!.get(_themeModeKey, defaultValue: 'system');
    switch (savedMode) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }
  
  void _loadLocale() {
    if (_box == null) return;
    
    final savedLocale = _box!.get(_localeKey);
    if (savedLocale != null) {
      if (savedLocale == 'zh') {
        _locale = const Locale('zh', 'TW');
      } else if (savedLocale == 'en') {
        _locale = const Locale('en', 'US');
      }
    }
    notifyListeners();
  }
  
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    
    if (_box != null) {
      String modeString;
      switch (mode) {
        case ThemeMode.light:
          modeString = 'light';
          break;
        case ThemeMode.dark:
          modeString = 'dark';
          break;
        default:
          modeString = 'system';
      }
      await _box!.put(_themeModeKey, modeString);
    }
    
    notifyListeners();
  }
  
  /// 切換到下一個主題模式
  Future<void> toggleThemeMode() async {
    switch (_themeMode) {
      case ThemeMode.system:
        await setThemeMode(ThemeMode.light);
        break;
      case ThemeMode.light:
        await setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        await setThemeMode(ThemeMode.system);
        break;
    }
  }
  
  String get themeModeString {
    switch (_themeMode) {
      case ThemeMode.light:
        return '淺色模式';
      case ThemeMode.dark:
        return '深色模式';
      default:
        return '跟隨系統';
    }
  }
  
  IconData get themeModeIcon {
    switch (_themeMode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      default:
        return Icons.brightness_auto;
    }
  }
  
  /// 設定語言
  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    
    if (_box != null) {
      if (locale == null) {
        await _box!.delete(_localeKey);
      } else if (locale.languageCode == 'zh') {
        await _box!.put(_localeKey, 'zh');
      } else if (locale.languageCode == 'en') {
        await _box!.put(_localeKey, 'en');
      }
    }
    
    notifyListeners();
  }
  
  String get localeString {
    if (_locale == null) return '跟隨系統';
    if (_locale!.languageCode == 'zh') return '繁體中文';
    if (_locale!.languageCode == 'en') return 'English';
    return '跟隨系統';
  }
  
  IconData get localeIcon {
    if (_locale == null) return Icons.language;
    if (_locale!.languageCode == 'zh') return Icons.translate;
    if (_locale!.languageCode == 'en') return Icons.translate;
    return Icons.language;
  }
  
  /// 載入主題色
  void _loadThemeColor() {
    if (_box == null) return;
    
    final savedColor = _box!.get(_themeColorKey, defaultValue: 'blue');
    _themeColorId = savedColor;
    notifyListeners();
  }
  
  /// 設定主題色
  Future<void> setThemeColor(String colorId) async {
    _themeColorId = colorId;
    
    if (_box != null) {
      await _box!.put(_themeColorKey, colorId);
    }
    
    // 通知課程顏色服務主題色已變更
    _onThemeColorChanged?.call();
    
    notifyListeners();
  }
  
  /// 獲取當前主題色的種子顏色（高飽和度）
  Color getSeedColor() {
    // 直接從 AppTheme.themeColors 獲取，保持單一來源
    return AppTheme.themeColors[_themeColorId]?.seedColor ?? 
           AppTheme.themeColors['blue']!.seedColor;
  }
}
