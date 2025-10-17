import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math' as math;

/// 課程顏色管理服務 - 基於 Material You 動態配色
class CourseColorService extends ChangeNotifier {
  static const String _boxName = 'course_colors';
  Box? _box;
  
  // Material You 風格的配色方案 - 16 種主題漸變色
  // 4×4 排列：橫向色相漸變（冷→暖），縱向明度漸變（淺→深）
  // 淺色模式專用：所有顏色明度 >= 0.75，確保黑色文字清晰可讀
  // 排列說明：
  // Row 1 (最淺): 冷色淺 → 主題淺 → 暖色淺 → 暖色極淺
  // Row 2 (淺): 冷色中淺 → 主題中淺 → 暖色中淺 → 暖色中淺2
  // Row 3 (較淺): 冷色較淺 → 主題較淺 → 暖色較淺 → 暖色較淺2
  // Row 4 (中淺): 冷色中淺2 → 主題中淺2 → 暖色中淺2 → 暖色中淺3
  static final List<Map<String, double>> _themeVariants = [
    // Row 1: 最淺色系（明度最高）
    {'hue': -40, 'sat': 0.40, 'light': 0.85},   // 0. 冷色淺
    {'hue': -15, 'sat': 0.42, 'light': 0.84},   // 1. 主題偏冷淺
    {'hue': 15, 'sat': 0.42, 'light': 0.84},    // 2. 主題偏暖淺
    {'hue': 40, 'sat': 0.40, 'light': 0.85},    // 3. 暖色淺
    
    // Row 2: 淺色系
    {'hue': -30, 'sat': 0.45, 'light': 0.81},   // 4. 冷色中淺
    {'hue': -10, 'sat': 0.47, 'light': 0.80},   // 5. 主題偏冷中淺
    {'hue': 10, 'sat': 0.47, 'light': 0.80},    // 6. 主題偏暖中淺
    {'hue': 30, 'sat': 0.45, 'light': 0.81},    // 7. 暖色中淺
    
    // Row 3: 較淺色系
    {'hue': -25, 'sat': 0.48, 'light': 0.77},   // 8. 冷色較淺
    {'hue': -8, 'sat': 0.50, 'light': 0.76},    // 9. 主題偏冷較淺
    {'hue': 8, 'sat': 0.50, 'light': 0.76},     // 10. 主題偏暖較淺
    {'hue': 25, 'sat': 0.48, 'light': 0.77},    // 11. 暖色較淺
    
    // Row 4: 中淺色系（明度最低仍 >= 0.75）
    {'hue': -35, 'sat': 0.50, 'light': 0.75},   // 12. 冷色中淺
    {'hue': -12, 'sat': 0.52, 'light': 0.75},   // 13. 主題偏冷中淺
    {'hue': 12, 'sat': 0.52, 'light': 0.75},    // 14. 主題偏暖中淺
    {'hue': 35, 'sat': 0.50, 'light': 0.75},    // 15. 暖色中淺
  ];
  
  // 通用彩虹色系 - 16 種獨立於主題的標準色
  // 色相均勻分布在色輪上，提供最大的辨識度
  // 淺色模式：明度 >= 0.75，確保黑色文字清晰可讀
  static final List<Map<String, double>> _universalColors = [
    {'hue': 0, 'sat': 0.50, 'light': 0.78},     // 紅色
    {'hue': 15, 'sat': 0.50, 'light': 0.78},    // 橙紅
    {'hue': 30, 'sat': 0.50, 'light': 0.78},    // 橙色
    {'hue': 45, 'sat': 0.50, 'light': 0.78},    // 金橙
    {'hue': 60, 'sat': 0.48, 'light': 0.80},    // 黃色
    {'hue': 80, 'sat': 0.48, 'light': 0.78},    // 黃綠
    {'hue': 100, 'sat': 0.48, 'light': 0.78},   // 萊姆綠
    {'hue': 120, 'sat': 0.48, 'light': 0.75},   // 綠色
    {'hue': 150, 'sat': 0.48, 'light': 0.75},   // 青綠
    {'hue': 180, 'sat': 0.48, 'light': 0.75},   // 青色
    {'hue': 200, 'sat': 0.48, 'light': 0.78},   // 天藍
    {'hue': 220, 'sat': 0.50, 'light': 0.78},   // 藍色
    {'hue': 240, 'sat': 0.50, 'light': 0.78},   // 深藍
    {'hue': 270, 'sat': 0.50, 'light': 0.78},   // 紫色
    {'hue': 300, 'sat': 0.50, 'light': 0.78},   // 品紅
    {'hue': 330, 'sat': 0.50, 'light': 0.78},   // 玫瑰紅
  ];
  
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }
  
  /// 獲取課程顏色 - Material You 風格
  /// 
  /// 根據課程 ID 和名稱生成和諧的顏色，並根據主題自動調整
  /// [isDark] 是否為深色模式
  /// [seedColor] 主題的種子顏色，用於生成和諧的配色
  Color getCourseColor(
    String courseId, 
    String courseName, {
    bool isDark = false,
    Color? seedColor,
  }) {
    // 如果服務未初始化，返回預設藍色
    if (_box == null) {
      return seedColor ?? const Color(0xFF2196F3);
    }
    
    final key = _getCourseKey(courseId, courseName);
    final colorIndex = _box!.get(key);
    
    // 如果已有儲存的顏色索引，直接使用
    if (colorIndex != null && colorIndex is int) {
      return _generateColorFromIndex(
        colorIndex,
        isDark: isDark,
        seedColor: seedColor,
      );
    }
    
    // 如果沒有儲存，智能分配一個新顏色並保存
    // 獲取已使用的顏色索引
    final usedIndices = _getUsedColorIndices();
    
    // 使用優化序列
    final optimizedSequence = [
      0, 10, 4, 14, 2, 8, 6, 12, 1, 11, 5, 15, 3, 9, 7, 13,
    ];
    
    int selectedIndex;
    
    // 如果還有未使用的顏色，選擇第一個未使用的
    if (usedIndices.length < optimizedSequence.length) {
      selectedIndex = optimizedSequence.firstWhere(
        (index) => !usedIndices.contains(index),
        orElse: () {
          // 如果優化序列都用完了，使用 hash 分配
          final hash = courseName.hashCode.abs();
          return optimizedSequence[hash % optimizedSequence.length];
        },
      );
    } else {
      // 所有顏色都用過了，使用與現有顏色差異最大的
      final hash = courseName.hashCode.abs();
      final preferredIndex = optimizedSequence[hash % optimizedSequence.length];
      selectedIndex = _selectMostDistinctColorIndex(usedIndices, preferredIndex);
    }
    
    // 保存選擇的索引
    _box!.put(key, selectedIndex);
    
    return _generateColorFromIndex(
      selectedIndex,
      isDark: isDark,
      seedColor: seedColor,
    );
  }
  
  /// 根據索引生成顏色
  /// 索引 0-15: 主題漸變色，16-31: 通用彩虹色
  Color _generateColorFromIndex(
    int index, {
    bool isDark = false,
    Color? seedColor,
  }) {
    final totalColors = _themeVariants.length + _universalColors.length;
    final validIndex = index % totalColors;
    
    // 前 16 個：主題漸變色
    if (validIndex < _themeVariants.length) {
      final variant = _themeVariants[validIndex];
      
      // 獲取主題色的 HSL 值
      final seedHsl = seedColor != null 
          ? HSLColor.fromColor(seedColor)
          : HSLColor.fromColor(const Color(0xFF2196F3));
      
      // 基於主題色相加上變體的偏移
      final finalHue = (seedHsl.hue + variant['hue']!) % 360;
      
      // 根據亮暗模式調整飽和度和明度
      // 深色模式：降低飽和度和亮度，讓顏色更柔和
      final saturation = isDark 
          ? (variant['sat']! * 0.65).clamp(0.30, 0.50)
          : variant['sat']!;
      final lightness = isDark 
          ? (variant['light']! * 0.70).clamp(0.35, 0.50)
          : variant['light']!;
      
      return HSLColor.fromAHSL(
        1.0,
        finalHue,
        saturation,
        lightness,
      ).toColor();
    }
    
    // 後 16 個：通用彩虹色（不受主題影響）
    final universalIndex = validIndex - _themeVariants.length;
    final color = _universalColors[universalIndex];
    
    // 根據亮暗模式調整
    // 深色模式：降低飽和度和亮度，讓顏色更柔和
    final saturation = isDark 
        ? (color['sat']! * 0.65).clamp(0.30, 0.50)
        : color['sat']!;
    final lightness = isDark 
        ? (color['light']! * 0.70).clamp(0.35, 0.50)
        : color['light']!;
    
    return HSLColor.fromAHSL(
      1.0,
      color['hue']!,
      saturation,
      lightness,
    ).toColor();
  }
  
  /// 生成 Material You 風格的課程顏色
  /// 使用智能分配策略，確保相鄰課程顏色差異明顯
  Color _generateMaterialYouColor(
    String courseId,
    String courseName, {
    bool isDark = false,
    Color? seedColor,
  }) {
    // 使用課程名稱的 hash 來選擇顏色
    final hash = courseName.hashCode.abs();
    
    // 使用優化的顏色序列，確保相鄰顏色差異大
    // 策略：交替選擇不同明度和色相的顏色
    final optimizedSequence = [
      0,   // 冷色淺
      10,  // 主題偏暖（中深）
      4,   // 冷色中淺
      14,  // 主題偏暖深
      2,   // 主題偏暖淺
      8,   // 冷色中深
      6,   // 主題偏暖中淺
      12,  // 冷色深
      1,   // 主題偏冷淺
      11,  // 暖色中深
      5,   // 主題偏冷中淺
      15,  // 暖色深
      3,   // 暖色淺
      9,   // 主題偏冷（中深）
      7,   // 暖色中淺
      13,  // 主題偏冷深
    ];
    
    // 使用優化序列選擇顏色索引
    final sequenceIndex = hash % optimizedSequence.length;
    final colorIndex = optimizedSequence[sequenceIndex];
    
    return _generateColorFromIndex(
      colorIndex,
      isDark: isDark,
      seedColor: seedColor,
    );
  }
  
  /// 獲取已使用的顏色索引列表
  List<int> _getUsedColorIndices() {
    if (_box == null) return [];
    
    final usedIndices = <int>[];
    for (final key in _box!.keys) {
      final value = _box!.get(key);
      if (value is int) {
        usedIndices.add(value);
      }
    }
    return usedIndices;
  }
  
  /// 智能選擇顏色：選擇與已使用顏色差異最大的顏色
  int _selectMostDistinctColorIndex(List<int> usedIndices, int preferredIndex) {
    if (usedIndices.isEmpty) {
      return preferredIndex;
    }
    
    // 如果首選索引未被使用，直接返回
    if (!usedIndices.contains(preferredIndex)) {
      return preferredIndex;
    }
    
    // 計算顏色差異度的策略：
    // 1. 色相差異（橫向）：相鄰列差異小，相隔2列以上差異大
    // 2. 明度差異（縱向）：相鄰行差異小，相隔2行以上差異大
    int bestIndex = preferredIndex;
    double maxMinDistance = 0;
    
    // 遍歷所有可能的顏色索引
    for (int candidate = 0; candidate < _themeVariants.length; candidate++) {
      // 計算與所有已使用顏色的最小距離
      double minDistance = double.infinity;
      
      for (final usedIndex in usedIndices) {
        final distance = _calculateColorDistance(candidate, usedIndex);
        if (distance < minDistance) {
          minDistance = distance;
        }
      }
      
      // 選擇與已使用顏色距離最大的候選顏色
      if (minDistance > maxMinDistance) {
        maxMinDistance = minDistance;
        bestIndex = candidate;
      }
    }
    
    return bestIndex;
  }
  
  /// 計算兩個顏色索引之間的視覺差異度
  /// 考慮色相（橫向）和明度（縱向）的差異
  double _calculateColorDistance(int index1, int index2) {
    // 將索引轉換為 4x4 網格座標
    final row1 = index1 ~/ 4;
    final col1 = index1 % 4;
    final row2 = index2 ~/ 4;
    final col2 = index2 % 4;
    
    // 橫向差異（色相）：權重較高
    final colDiff = (col1 - col2).abs();
    
    // 縱向差異（明度）：權重稍低
    final rowDiff = (row1 - row2).abs();
    
    // 綜合距離：色相差異權重 1.5，明度差異權重 1.0
    return colDiff * 1.5 + rowDiff * 1.0;
  }
  
  /// 設定課程顏色（通過索引）
  /// 
  /// [colorIndex] 顏色索引 (0-15)，存儲索引而非具體顏色值
  /// 這樣當主題色改變時，課程顏色會自動跟著調整
  Future<void> setCourseColorIndex(
    String courseId, 
    String courseName, 
    int colorIndex,
  ) async {
    if (_box == null) return;
    
    final key = _getCourseKey(courseId, courseName);
    await _box!.put(key, colorIndex);
    notifyListeners();
  }
  
  /// 根據顏色找到對應的索引（用於選擇器）
  int? getColorIndex(
    String courseId,
    String courseName,
    Color color, {
    bool isDark = false,
    Color? seedColor,
  }) {
    // 檢查是否有存儲的索引
    if (_box != null) {
      final key = _getCourseKey(courseId, courseName);
      final storedIndex = _box!.get(key);
      if (storedIndex != null && storedIndex is int) {
        return storedIndex;
      }
    }
    
    // 如果沒有存儲，嘗試找到最接近的顏色索引
    final availableColors = getAvailableColors(
      isDark: isDark,
      seedColor: seedColor,
    );
    
    for (int i = 0; i < availableColors.length; i++) {
      if (availableColors[i].value == color.value) {
        return i;
      }
    }
    
    return null;
  }
  
  /// 重置課程顏色為預設值（自動分配）
  Future<void> resetCourseColor(String courseId, String courseName) async {
    if (_box == null) return;
    
    final key = _getCourseKey(courseId, courseName);
    await _box!.delete(key);
    notifyListeners();
  }
  
  /// 清除所有顏色設定
  Future<void> clearAll() async {
    if (_box == null) return;
    await _box!.clear();
    notifyListeners();
  }
  
  /// 通知主題色已變更，需要重新生成顏色
  void notifyThemeChanged() {
    notifyListeners();
  }
  
  /// 重新智能分配所有課程顏色
  /// 清除所有自訂顏色，使用智能策略確保顏色不重複且差異明顯
  /// [courses] 可選的課程列表。如果未提供，會從現有儲存的 key 中提取
  Future<void> reassignAllColors([List<Map<String, dynamic>>? courses]) async {
    if (_box == null) return;
    
    // 如果沒有提供課程列表，從現有的 keys 中提取
    List<Map<String, dynamic>> courseList = courses ?? [];
    if (courseList.isEmpty) {
      final keys = _box!.keys.toList();
      
      // 創建一個 Set 來去重
      final uniqueCourses = <String, Map<String, dynamic>>{};
      
      for (final key in keys) {
        if (key is String && key.contains('_')) {
          // 使用 indexOf 來正確分割 courseId 和 courseName
          final firstUnderscoreIndex = key.indexOf('_');
          if (firstUnderscoreIndex > 0 && firstUnderscoreIndex < key.length - 1) {
            final courseId = key.substring(0, firstUnderscoreIndex);
            final courseName = key.substring(firstUnderscoreIndex + 1);
            
            // 使用 key 作為唯一標識，避免重複
            uniqueCourses[key] = {
              'courseId': courseId,
              'courseName': courseName,
              'key': key,
            };
          }
        }
      }
      
      courseList = uniqueCourses.values.toList();
      
      // 按照課程名稱排序，確保每次順序一致
      courseList.sort((a, b) {
        final nameA = a['courseName'] ?? '';
        final nameB = b['courseName'] ?? '';
        return nameA.compareTo(nameB);
      });
    }
    
    // 清除所有現有顏色設定
    await _box!.clear();
    
    // 調試輸出
    print('🎨 重新分配顏色給 ${courseList.length} 個課程：');
    for (int i = 0; i < courseList.length; i++) {
      print('  [$i] ${courseList[i]['courseName']}');
    }
    
    // 如果沒有課程，直接返回
    if (courseList.isEmpty) {
      notifyListeners();
      return;
    }
    
    // 使用智能分配策略
    await _intelligentAssignColors(courseList);
    notifyListeners();
  }
  
  /// 智能分配顏色：確保每個課程的顏色都盡可能不同
  Future<void> _intelligentAssignColors(List<Map<String, dynamic>> courses) async {
    if (_box == null || courses.isEmpty) return;
    
    // 優化的顏色序列，確保相鄰顏色差異大
    final optimizedSequence = [
      0,   // 冷色淺
      10,  // 主題偏暖（中深）
      4,   // 冷色中淺
      14,  // 主題偏暖深
      2,   // 主題偏暖淺
      8,   // 冷色中深
      6,   // 主題偏暖中淺
      12,  // 冷色深
      1,   // 主題偏冷淺
      11,  // 暖色中深
      5,   // 主題偏冷中淺
      15,  // 暖色深
      3,   // 暖色淺
      9,   // 主題偏冷（中深）
      7,   // 暖色中淺
      13,  // 主題偏冷深
    ];
    
    // 按順序為每個課程分配優化序列中的顏色
    // 前 16 個課程保證完全不重複
    // 超過 16 個時，重複使用優化序列
    print('🎨 開始智能分配顏色...');
    for (int i = 0; i < courses.length; i++) {
      final course = courses[i];
      final courseId = course['courseId'] ?? '';
      final courseName = course['courseName'] ?? '';
      
      if (courseId.isEmpty || courseName.isEmpty) {
        print('  ⚠️  跳過空課程 [$i]');
        continue;
      }
      
      // 直接按順序使用優化序列中的顏色
      final selectedIndex = optimizedSequence[i % optimizedSequence.length];
      await setCourseColorIndex(courseId, courseName, selectedIndex);
      
      print('  ✓ [$i] $courseName → 顏色索引 $selectedIndex');
    }
    print('🎨 顏色分配完成！');
  }
  
  /// 隨機分配所有課程顏色（使用主題色 0-15）
  /// [courses] 課程列表，格式: [{'courseId': '...', 'courseName': '...'}]
  Future<void> randomAssignColors(List<Map<String, dynamic>> courses) async {
    if (_box == null) return;
    
    final random = math.Random();
    for (final course in courses) {
      final courseId = course['courseId'] ?? '';
      final courseName = course['courseName'] ?? '';
      if (courseId.isEmpty || courseName.isEmpty) continue;
      
      // 隨機選擇主題色（0-15）
      final randomIndex = random.nextInt(_themeVariants.length);
      await setCourseColorIndex(courseId, courseName, randomIndex);
    }
    
    notifyListeners();
  }
  
  String _getCourseKey(String courseId, String courseName) {
    return '${courseId}_$courseName';
  }
  
  /// 調試：獲取所有已存儲的課程顏色索引
  Map<String, int> getAllCourseColorIndices() {
    if (_box == null) return {};
    
    final result = <String, int>{};
    for (final key in _box!.keys) {
      if (key is String) {
        final value = _box!.get(key);
        if (value is int) {
          // 提取課程名稱
          final firstUnderscoreIndex = key.indexOf('_');
          if (firstUnderscoreIndex > 0) {
            final courseName = key.substring(firstUnderscoreIndex + 1);
            result[courseName] = value;
          }
        }
      }
    }
    return result;
  }
  
  /// 獲取所有可選顏色 - Material You 風格
  /// 
  /// 生成 32 種顏色：前 16 種主題漸變色 + 後 16 種通用彩虹色
  List<Color> getAvailableColors({bool isDark = false, Color? seedColor}) {
    final colors = <Color>[];
    
    // 獲取主題色的 HSL 值
    final seedHsl = seedColor != null 
        ? HSLColor.fromColor(seedColor)
        : HSLColor.fromColor(const Color(0xFF2196F3));
    
    // 第一組：16 種主題漸變色
    for (int i = 0; i < _themeVariants.length; i++) {
      final variant = _themeVariants[i];
      
      // 基於主題色相加上變體的偏移
      final finalHue = (seedHsl.hue + variant['hue']!) % 360;
      
      // 根據亮暗模式調整
      final saturation = isDark 
          ? (variant['sat']! * 0.85).clamp(0.45, 0.75)
          : variant['sat']!;
      final lightness = isDark 
          ? (variant['light']! * 0.85).clamp(0.40, 0.60)
          : variant['light']!;
      
      final color = HSLColor.fromAHSL(
        1.0,
        finalHue,
        saturation,
        lightness,
      ).toColor();
      
      colors.add(color);
    }
    
    // 第二組：16 種通用彩虹色
    for (int i = 0; i < _universalColors.length; i++) {
      final color = _universalColors[i];
      
      // 根據亮暗模式調整
      // 深色模式：降低飽和度和亮度，讓顏色更柔和
      final saturation = isDark 
          ? (color['sat']! * 0.65).clamp(0.30, 0.50)
          : color['sat']!;
      final lightness = isDark 
          ? (color['light']! * 0.70).clamp(0.35, 0.50)
          : color['light']!;
      
      final universalColor = HSLColor.fromAHSL(
        1.0,
        color['hue']!,
        saturation,
        lightness,
      ).toColor();
      
      colors.add(universalColor);
    }
    
    return colors;
  }
  
  /// 獲取課程顏色的容器色（用於卡片背景）
  /// 這會返回一個較淺的版本，適合作為背景
  Color getCourseContainerColor(
    String courseId,
    String courseName, {
    bool isDark = false,
    Color? seedColor,
  }) {
    final baseColor = getCourseColor(
      courseId,
      courseName,
      isDark: isDark,
      seedColor: seedColor,
    );
    
    return isDark 
        ? baseColor.withOpacity(0.35)
        : baseColor.withOpacity(0.25);
  }
  
  /// 獲取在課程顏色背景上的文字顏色
  /// 自動判斷應該使用深色還是淺色文字以確保可讀性
  Color getOnCourseColor(
    String courseId,
    String courseName, {
    bool isDark = false,
    Color? seedColor,
  }) {
    // 淺色模式：強制使用黑色文字（所有背景色都已優化為淺色）
    // 深色模式：根據亮度自動判斷
    if (!isDark) {
      return Colors.black87;
    }
    
    final baseColor = getCourseColor(
      courseId,
      courseName,
      isDark: isDark,
      seedColor: seedColor,
    );
    
    // 計算顏色的相對亮度
    final luminance = baseColor.computeLuminance();
    
    // 深色模式：如果背景色較亮使用深色文字，反之使用淺色文字
    return luminance > 0.4 ? Colors.black87 : Colors.white;
  }
  
  /// 獲取課程漸層顏色列表
  /// 返回適合做漸層的三個顏色（起始色 -> 中間色 -> 結束色）
  /// 
  /// 使用統一的透明度疊加策略，確保淺色/深色模式都有一致且適度的漸層效果
  /// 
  /// 漸層策略：
  /// - 使用透明度疊加而非明度調整，視覺效果更自然
  /// - 在基礎色上疊加 2% 和 5% 的白色（淺色）或黑色（深色）
  /// - 確保所有顏色的漸層強度都一致
  List<Color> getCourseGradientColors(
    String courseId,
    String courseName, {
    bool isDark = false,
    Color? seedColor,
  }) {
    final baseColor = getCourseColor(
      courseId,
      courseName,
      isDark: isDark,
      seedColor: seedColor,
    );
    
    // 使用顏色混合而非 HSL 調整，確保視覺效果統一
    // 透明度疊加：模擬在顏色上面覆蓋一層半透明的白色/黑色
    Color blendColor(Color base, Color overlay, double opacity) {
      return Color.alphaBlend(
        overlay.withOpacity(opacity),
        base,
      );
    }
    
    if (isDark) {
      // 深色模式：疊加白色，營造柔和的高光效果
      return [
        baseColor, // 基礎色
        blendColor(baseColor, Colors.white, 0.04), // 疊加 4% 白色
        blendColor(baseColor, Colors.white, 0.08), // 疊加 8% 白色
      ];
    } else {
      // 淺色模式：疊加黑色，營造微妙的陰影效果
      return [
        baseColor, // 基礎色
        blendColor(baseColor, Colors.black, 0.05), // 疊加 5% 黑色
        blendColor(baseColor, Colors.black, 0.10), // 疊加 10% 黑色
      ];
    }
  }
}
