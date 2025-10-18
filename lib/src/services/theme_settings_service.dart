import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../ui/theme/app_theme.dart';

/// 課表風格枚舉
enum CourseTableStyle {
  material3, // Material 3 風格（懸浮卡片）
  classic,   // 經典風格（表格式、緊湊）
  tat,       // TAT 傳統風格
}

/// 課程配色風格枚舉
enum CourseColorStyle {
  tat,      // TAT 配色（馬卡龍色系）
  theme,    // 主題配色（根據主題色生成）
  rainbow,  // 彩虹配色（通用彩虹色）
}

/// 主題設定服務
class ThemeSettingsService extends ChangeNotifier {
  static const String _boxName = 'theme_settings';
  static const String _themeModeKey = 'theme_mode';
  static const String _localeKey = 'locale';
  static const String _themeColorKey = 'theme_color';
  static const String _courseTableStyleKey = 'course_table_style';
  static const String _courseColorStyleKey = 'course_color_style';
  Box? _box;
  
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale; // null 表示跟隨系統
  String _themeColorId = 'blue'; // 預設藍色主題
  CourseTableStyle _courseTableStyle = CourseTableStyle.material3; // 預設 Material 3 風格
  CourseColorStyle _courseColorStyle = CourseColorStyle.theme; // 預設主題配色
  
  // 課程顏色服務的回調，用於通知主題色變更
  Function()? _onThemeColorChanged;
  
  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;
  String get themeColorId => _themeColorId;
  CourseTableStyle get courseTableStyle => _courseTableStyle;
  CourseColorStyle get courseColorStyle => _courseColorStyle;
  
  /// 設定課程顏色服務的回調
  void setCourseColorCallback(Function() callback) {
    _onThemeColorChanged = callback;
  }
  
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _loadThemeMode();
    _loadLocale();
    _loadThemeColor();
    _loadCourseTableStyle();
    _loadCourseColorStyle();
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
  
  /// 載入課表風格
  void _loadCourseTableStyle() {
    if (_box == null) return;
    
    final savedStyle = _box!.get(_courseTableStyleKey, defaultValue: 'material3');
    switch (savedStyle) {
      case 'classic':
        _courseTableStyle = CourseTableStyle.classic;
        break;
      case 'tat':
        _courseTableStyle = CourseTableStyle.tat;
        break;
      default:
        _courseTableStyle = CourseTableStyle.material3;
    }
    notifyListeners();
  }
  
  /// 設定課表風格
  Future<void> setCourseTableStyle(CourseTableStyle style) async {
    _courseTableStyle = style;
    
    if (_box != null) {
      String styleString;
      switch (style) {
        case CourseTableStyle.classic:
          styleString = 'classic';
          break;
        case CourseTableStyle.tat:
          styleString = 'tat';
          break;
        default:
          styleString = 'material3';
      }
      await _box!.put(_courseTableStyleKey, styleString);
    }
    
    notifyListeners();
  }
  
  /// 獲取課表風格名稱
  String get courseTableStyleName {
    switch (_courseTableStyle) {
      case CourseTableStyle.material3:
        return 'Material 3 風格';
      case CourseTableStyle.classic:
        return '經典風格';
      case CourseTableStyle.tat:
        return 'TAT 傳統風格';
    }
  }
  
  /// 獲取課表風格描述
  String get courseTableStyleDescription {
    switch (_courseTableStyle) {
      case CourseTableStyle.material3:
        return '懸浮卡片設計，現代化視覺';
      case CourseTableStyle.classic:
        return '表格式佈局，緊湊簡潔';
      case CourseTableStyle.tat:
        return '傳統風格（開發中）';
    }
  }
  
  /// 獲取課表風格圖示
  IconData get courseTableStyleIcon {
    switch (_courseTableStyle) {
      case CourseTableStyle.material3:
        return Icons.layers;
      case CourseTableStyle.classic:
        return Icons.grid_on;
      case CourseTableStyle.tat:
        return Icons.table_chart;
    }
  }
  
  /// 載入課程配色風格
  void _loadCourseColorStyle() {
    if (_box == null) return;
    
    final savedStyle = _box!.get(_courseColorStyleKey, defaultValue: 'theme');
    switch (savedStyle) {
      case 'tat':
        _courseColorStyle = CourseColorStyle.tat;
        break;
      case 'rainbow':
        _courseColorStyle = CourseColorStyle.rainbow;
        break;
      default:
        _courseColorStyle = CourseColorStyle.theme;
    }
    notifyListeners();
  }
  
  /// 設定課程配色風格
  Future<void> setCourseColorStyle(CourseColorStyle style) async {
    _courseColorStyle = style;
    
    if (_box != null) {
      String styleString;
      switch (style) {
        case CourseColorStyle.tat:
          styleString = 'tat';
          break;
        case CourseColorStyle.rainbow:
          styleString = 'rainbow';
          break;
        default:
          styleString = 'theme';
      }
      await _box!.put(_courseColorStyleKey, styleString);
    }
    
    // 通知課程顏色服務配色風格已變更
    _onThemeColorChanged?.call();
    
    notifyListeners();
  }
  
  /// 獲取課程配色風格名稱
  String get courseColorStyleName {
    switch (_courseColorStyle) {
      case CourseColorStyle.tat:
        return 'TAT 配色';
      case CourseColorStyle.theme:
        return '主題配色';
      case CourseColorStyle.rainbow:
        return '彩虹配色';
    }
  }
  
  /// 獲取課程配色風格描述
  String get courseColorStyleDescription {
    switch (_courseColorStyle) {
      case CourseColorStyle.tat:
        return '柔和的馬卡龍色系';
      case CourseColorStyle.theme:
        return '根據主題色生成';
      case CourseColorStyle.rainbow:
        return '經典彩虹色系';
    }
  }
  
  /// 獲取課程配色風格圖示
  IconData get courseColorStyleIcon {
    switch (_courseColorStyle) {
      case CourseColorStyle.tat:
        return Icons.palette_outlined;
      case CourseColorStyle.theme:
        return Icons.color_lens;
      case CourseColorStyle.rainbow:
        return Icons.gradient;
    }
  }
}
