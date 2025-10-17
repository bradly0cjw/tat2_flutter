import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/calendar_event.dart';
import '../models/local_calendar_event.dart';
import '../services/calendar_service.dart';
import '../services/local_event_service.dart';

/// 統一的事件接口（用於同時處理學校事件和本地事件）
class UnifiedEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final bool isLocalEvent; // true = 本地事件, false = 學校事件
  final String color;
  final CalendarEvent? schoolEvent;
  final LocalCalendarEvent? localEvent;

  UnifiedEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    required this.isLocalEvent,
    required this.color,
    this.schoolEvent,
    this.localEvent,
  });

  factory UnifiedEvent.fromSchoolEvent(CalendarEvent event) {
    return UnifiedEvent(
      id: event.id.isNotEmpty ? event.id : event.summary,
      title: event.summary,
      description: event.description,
      startTime: event.start,
      endTime: event.end,
      location: event.location,
      isLocalEvent: false,
      color: '#2196F3', // 學校事件用藍色
      schoolEvent: event,
    );
  }

  factory UnifiedEvent.fromLocalEvent(LocalCalendarEvent event) {
    return UnifiedEvent(
      id: 'local_${event.id}',
      title: event.title,
      description: event.description,
      startTime: event.startTime,
      endTime: event.endTime,
      location: event.location,
      isLocalEvent: true,
      color: event.color,
      localEvent: event,
    );
  }

  String get dateRangeText {
    // 檢查是否有指定時間（不是 00:00）
    final hasStartTime = startTime.hour != 0 || startTime.minute != 0;
    final hasEndTime = endTime.hour != 0 || endTime.minute != 0;
    final hasTime = hasStartTime || hasEndTime;
    
    // 標準化日期比較（去除時間部分）
    final startDate = DateTime(startTime.year, startTime.month, startTime.day);
    final endDate = DateTime(endTime.year, endTime.month, endTime.day);
    
    // 檢查是否為同一天（或結束時間是隔天 00:00，視為同一天的全天事件）
    final isSameDay = startDate.isAtSameMomentAs(endDate) ||
                      (endDate.difference(startDate).inDays == 1 && 
                       endTime.hour == 0 && endTime.minute == 0 && endTime.second == 0);
    
    if (isSameDay) {
      // 同一天
      if (hasTime) {
        return '${startTime.month}/${startTime.day} ${_formatTime(startTime)} - ${_formatTime(endTime)}';
      } else {
        return '${startTime.month}/${startTime.day}';
      }
    }
    return '${startTime.month}/${startTime.day} - ${endTime.month}/${endTime.day}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// 日曆狀態管理
class CalendarProvider with ChangeNotifier {
  final CalendarService _calendarService = CalendarService();
  final LocalEventService _localEventService = LocalEventService();

  // 狀態
  List<CalendarEvent> _schoolEvents = [];
  List<LocalCalendarEvent> _localEvents = [];
  
  // 使用 LinkedHashMap 以日期為 key 儲存統一事件（參考 TAT 的做法）
  final LinkedHashMap<DateTime, List<UnifiedEvent>> _eventsByDate = LinkedHashMap(
    equals: (a, b) => a.year == b.year && a.month == b.month && a.day == b.day,
    hashCode: (date) => date.year * 10000 + date.month * 100 + date.day,
  );
  
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isLoading = false;
  bool _isInitialized = false; // 追蹤是否已初始化
  String? _error;

  // Getters
  List<CalendarEvent> get schoolEvents => _schoolEvents;
  List<LocalCalendarEvent> get localEvents => _localEvents;
  DateTime get focusedDay => _focusedDay;
  DateTime get selectedDay => _selectedDay;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  /// 獲取選中日期的統一事件（從 Map 中取得）
  List<UnifiedEvent> get selectedDayEvents {
    final normalizedDay = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    return _eventsByDate[normalizedDay] ?? [];
  }
  
  /// 獲取指定日期的統一事件（用於日曆標記）
  List<UnifiedEvent> getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _eventsByDate[normalizedDay] ?? [];
  }

  /// 初始化並加載事件
  Future<void> initialize() async {
    await loadEvents();
  }

  /// 加載所有事件（學校 + 本地）
  Future<void> loadEvents({bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 並行載入學校事件和本地事件
      final results = await Future.wait([
        _calendarService.getSchoolEvents(forceRefresh: forceRefresh),
        _localEventService.getAllEvents(),
      ]);

      _schoolEvents = results[0] as List<CalendarEvent>;
      _localEvents = results[1] as List<LocalCalendarEvent>;

      _rebuildEventsByDate();
      _error = null;
      _isInitialized = true; // 標記為已初始化
    } catch (e) {
      _error = '無法載入行事曆資料：$e';
      debugPrint('Error loading calendar events: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 只加載本地事件
  Future<void> loadLocalEvents() async {
    try {
      _localEvents = await _localEventService.getAllEvents();
      _rebuildEventsByDate();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading local events: $e');
    }
  }

  /// 重新構建事件 Map
  void _rebuildEventsByDate() {
    _eventsByDate.clear();

    // 添加學校事件
    for (final event in _schoolEvents) {
      final eventDate = DateTime(event.start.year, event.start.month, event.start.day);
      final unifiedEvent = UnifiedEvent.fromSchoolEvent(event);
      
      if (_eventsByDate.containsKey(eventDate)) {
        _eventsByDate[eventDate]!.add(unifiedEvent);
      } else {
        _eventsByDate[eventDate] = [unifiedEvent];
      }
    }

    // 添加本地事件（考慮重複規則）
    for (final event in _localEvents) {
      _addLocalEventToMap(event);
    }
  }

  /// 將本地事件添加到 Map（處理重複規則）
  void _addLocalEventToMap(LocalCalendarEvent event) {
    if (event.recurrenceType == RecurrenceType.none) {
      // 非重複事件，只添加到開始日期
      final eventDate = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );
      final unifiedEvent = UnifiedEvent.fromLocalEvent(event);
      
      if (_eventsByDate.containsKey(eventDate)) {
        _eventsByDate[eventDate]!.add(unifiedEvent);
      } else {
        _eventsByDate[eventDate] = [unifiedEvent];
      }
    } else {
      // 重複事件，在未來一年內展開所有實例
      final now = DateTime.now();
      final future = now.add(const Duration(days: 365));
      DateTime currentDate = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );

      while (currentDate.isBefore(future)) {
        // 檢查是否超過重複結束日期
        if (event.recurrenceEndDate != null &&
            currentDate.isAfter(event.recurrenceEndDate!)) {
          break;
        }

        if (event.occursOnDate(currentDate)) {
          // 創建這個日期的事件實例
          final instanceEvent = event.copyWith(
            startTime: event.getOccurrenceDate(currentDate),
            endTime: DateTime(
              currentDate.year,
              currentDate.month,
              currentDate.day,
              event.endTime.hour,
              event.endTime.minute,
            ),
          );
          
          final unifiedEvent = UnifiedEvent.fromLocalEvent(instanceEvent);
          
          if (_eventsByDate.containsKey(currentDate)) {
            _eventsByDate[currentDate]!.add(unifiedEvent);
          } else {
            _eventsByDate[currentDate] = [unifiedEvent];
          }
        }

        currentDate = currentDate.add(const Duration(days: 1));
      }
    }
  }

  /// 設置焦點日期
  void setFocusedDay(DateTime day) {
    _focusedDay = day;
    notifyListeners();
  }

  /// 設置選中日期
  void setSelectedDay(DateTime day) {
    _selectedDay = day;
    notifyListeners();
  }

  /// 選擇日期（同時設置焦點和選中）
  void selectDay(DateTime selectedDay, DateTime focusedDay) {
    _selectedDay = selectedDay;
    _focusedDay = focusedDay;
    notifyListeners();
  }

  /// 獲取指定日期的事件數量（用於標記，只計算開始日期）
  int getEventCountForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _eventsByDate[normalizedDay]?.length ?? 0;
  }

  /// 檢查指定日期是否有事件（用於標記）
  bool hasEventsOnDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _eventsByDate.containsKey(normalizedDay) && _eventsByDate[normalizedDay]!.isNotEmpty;
  }

  /// 搜尋事件
  Future<List<UnifiedEvent>> searchEvents(String keyword) async {
    if (keyword.isEmpty) {
      return _eventsByDate.values.expand((list) => list).toList();
    }

    final results = <UnifiedEvent>[];
    
    // 搜尋學校事件
    final schoolResults = await _calendarService.searchEvents(keyword);
    results.addAll(schoolResults.map((e) => UnifiedEvent.fromSchoolEvent(e)));
    
    // 搜尋本地事件
    final localResults = await _localEventService.searchEvents(keyword);
    results.addAll(localResults.map((e) => UnifiedEvent.fromLocalEvent(e)));
    
    return results;
  }

  /// 獲取今天的事件
  List<UnifiedEvent> getTodayEvents() {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    return _eventsByDate[normalizedToday] ?? [];
  }

  /// 獲取即將到來的事件
  List<UnifiedEvent> getUpcomingEvents({int days = 30}) {
    final now = DateTime.now();
    final future = now.add(Duration(days: days));
    final results = <UnifiedEvent>[];

    for (var date = now; date.isBefore(future); date = date.add(const Duration(days: 1))) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final events = _eventsByDate[normalizedDate];
      if (events != null) {
        results.addAll(events);
      }
    }

    return results;
  }

  /// 刷新事件數據
  Future<void> refresh() async {
    await loadEvents(forceRefresh: true);
  }

  /// 清除快取
  void clearCache() {
    _calendarService.clearCache();
    _schoolEvents = [];
    _localEvents = [];
    _eventsByDate.clear();
    _error = null;
    notifyListeners();
  }

  /// 重置日期選擇
  void resetToToday() {
    final today = DateTime.now();
    _selectedDay = today;
    _focusedDay = today;
    notifyListeners();
  }
}
