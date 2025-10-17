import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calendar_event.dart';

/// 日曆服務
/// 負責管理學校行事曆和課程事件
class CalendarService {
  static const String _calendarJsonUrl = 
      'https://gnehs.github.io/ntut-course-crawler-node/calendar.json';
  
  static const String _cacheKey = 'calendar_events_cache';
  static const String _cacheTimeKey = 'calendar_events_cache_time';

  /// 學校事件快取（記憶體快取）
  List<CalendarEvent>? _cachedSchoolEvents;
  DateTime? _lastFetchTime;

  /// 快取有效期（24小時）
  static const Duration _cacheValidDuration = Duration(hours: 24);

  /// 獲取學校行事曆事件
  Future<List<CalendarEvent>> getSchoolEvents({bool forceRefresh = false}) async {
    // 檢查記憶體快取是否有效
    if (!forceRefresh && 
        _cachedSchoolEvents != null && 
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheValidDuration) {
      return _cachedSchoolEvents!;
    }

    // 嘗試從本地儲存讀取
    if (!forceRefresh) {
      final localEvents = await _loadFromLocalStorage();
      if (localEvents != null) {
        _cachedSchoolEvents = localEvents;
        return localEvents;
      }
    }

    // 從網路獲取
    try {
      final response = await http.get(Uri.parse(_calendarJsonUrl));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        
        // 去重：使用 Map 以 uid 為 key 來過濾重複事件
        final Map<String, CalendarEvent> eventMap = {};
        
        for (var json in jsonList) {
          try {
            final event = CalendarEvent.fromJson(json);
            if (event.summary.isNotEmpty) {
              // 如果已存在相同 ID，保留第一個（或比較時間選擇最新的）
              if (!eventMap.containsKey(event.id)) {
                eventMap[event.id] = event;
              }
            }
          } catch (e) {
            print('Error parsing event: $e');
            continue;
          }
        }
        
        _cachedSchoolEvents = eventMap.values.toList()
          ..sort((a, b) => a.start.compareTo(b.start)); // 按時間排序
        
        _lastFetchTime = DateTime.now();
        
        // 儲存到本地
        await _saveToLocalStorage(_cachedSchoolEvents!);
        
        return _cachedSchoolEvents!;
      } else {
        throw Exception('Failed to load calendar events: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching calendar events: $e');
      
      // 如果有記憶體快取，返回快取的數據
      if (_cachedSchoolEvents != null) {
        return _cachedSchoolEvents!;
      }
      
      // 最後嘗試從本地儲存讀取（即使過期也返回）
      final localEvents = await _loadFromLocalStorage();
      if (localEvents != null) {
        return localEvents;
      }
      
      rethrow;
    }
  }
  
  /// 從本地儲存載入事件
  Future<List<CalendarEvent>?> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTimeStr = prefs.getString(_cacheTimeKey);
      final cacheData = prefs.getString(_cacheKey);
      
      if (cacheTimeStr == null || cacheData == null) {
        return null;
      }
      
      final cacheTime = DateTime.parse(cacheTimeStr);
      
      // 檢查快取是否過期
      if (DateTime.now().difference(cacheTime) > _cacheValidDuration) {
        return null;
      }
      
      final List<dynamic> jsonList = json.decode(cacheData);
      _lastFetchTime = cacheTime;
      
      return jsonList
          .map((json) => CalendarEvent.fromJson(json))
          .where((event) => event.summary.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error loading from local storage: $e');
      return null;
    }
  }
  
  /// 儲存事件到本地儲存
  Future<void> _saveToLocalStorage(List<CalendarEvent> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = events.map((e) => e.toJson()).toList();
      
      await prefs.setString(_cacheKey, json.encode(jsonList));
      await prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Error saving to local storage: $e');
    }
  }

  /// 獲取指定月份的事件
  Future<List<CalendarEvent>> getEventsForMonth(DateTime month) async {
    final events = await getSchoolEvents();
    
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    
    return events.where((event) {
      return event.start.isAfter(firstDay.subtract(const Duration(days: 1))) &&
             event.start.isBefore(lastDay.add(const Duration(days: 1)));
    }).toList();
  }

  /// 獲取指定日期的事件
  Future<List<CalendarEvent>> getEventsForDay(DateTime day) async {
    final events = await getSchoolEvents();
    
    return events.where((event) => event.isOnDate(day)).toList();
  }

  /// 搜尋事件
  Future<List<CalendarEvent>> searchEvents(String keyword) async {
    final events = await getSchoolEvents();
    
    final lowerKeyword = keyword.toLowerCase();
    return events.where((event) {
      return event.summary.toLowerCase().contains(lowerKeyword) ||
             (event.description?.toLowerCase().contains(lowerKeyword) ?? false);
    }).toList();
  }

  /// 獲取今天的事件
  Future<List<CalendarEvent>> getTodayEvents() async {
    return getEventsForDay(DateTime.now());
  }

  /// 獲取本週的事件
  Future<List<CalendarEvent>> getThisWeekEvents() async {
    final now = DateTime.now();
    final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));
    
    final events = await getSchoolEvents();
    
    return events.where((event) {
      return event.start.isAfter(firstDayOfWeek.subtract(const Duration(days: 1))) &&
             event.start.isBefore(lastDayOfWeek.add(const Duration(days: 1)));
    }).toList();
  }

  /// 獲取即將到來的事件（未來30天）
  Future<List<CalendarEvent>> getUpcomingEvents({int days = 30}) async {
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: days));
    
    final events = await getSchoolEvents();
    
    return events.where((event) {
      return event.start.isAfter(now) && event.start.isBefore(futureDate);
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  /// 清除快取
  Future<void> clearCache() async {
    _cachedSchoolEvents = null;
    _lastFetchTime = null;
    
    // 同時清除本地儲存
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimeKey);
    } catch (e) {
      print('Error clearing local storage: $e');
    }
  }

  /// 獲取事件統計
  Future<Map<String, int>> getEventStatistics() async {
    final events = await getSchoolEvents();
    
    final now = DateTime.now();
    final thisMonth = events.where((e) => 
      e.start.year == now.year && e.start.month == now.month
    ).length;
    
    final upcoming = events.where((e) => e.start.isAfter(now)).length;
    
    return {
      'total': events.length,
      'thisMonth': thisMonth,
      'upcoming': upcoming,
    };
  }
}
