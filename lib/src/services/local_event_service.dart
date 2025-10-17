import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/local_calendar_event.dart';

/// 本地日曆事件服務（負責資料庫操作）
class LocalEventService {
  static final LocalEventService _instance = LocalEventService._internal();
  factory LocalEventService() => _instance;
  LocalEventService._internal();

  Database? _database;

  /// 取得資料庫實例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 資料庫版本號（更新資料庫結構時需要遞增）
  static const int _databaseVersion = 1;

  /// 初始化資料庫
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'qaq_calendar.db');

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 創建資料表
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE local_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        location TEXT,
        is_all_day INTEGER NOT NULL DEFAULT 0,
        recurrence_type INTEGER NOT NULL DEFAULT 0,
        recurrence_end_date TEXT,
        color TEXT NOT NULL DEFAULT '#2196F3',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 創建索引以提升查詢效能
    await db.execute('''
      CREATE INDEX idx_start_time ON local_events(start_time)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_end_time ON local_events(end_time)
    ''');
  }

  /// 升級資料庫（支援版本遷移）
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading database from version $oldVersion to $newVersion');
    
    // 版本 1 -> 2 的升級範例（未來使用）
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE local_events ADD COLUMN new_field TEXT');
    // }
    
    // 版本 2 -> 3 的升級範例（未來使用）
    // if (oldVersion < 3) {
    //   await db.execute('CREATE TABLE new_table (...)');
    // }
  }

  /// 新增事件（帶錯誤處理）
  Future<int> insertEvent(LocalCalendarEvent event) async {
    try {
      final db = await database;
      final id = await db.insert(
        'local_events',
        event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Inserted event with id: $id, title: ${event.title}');
      return id;
    } catch (e) {
      debugPrint('Error inserting event: $e');
      debugPrint('Event data: ${event.toMap()}');
      rethrow;
    }
  }

  /// 更新事件（帶錯誤處理）
  Future<int> updateEvent(LocalCalendarEvent event) async {
    if (event.id == null) {
      throw ArgumentError('Event id cannot be null for update');
    }

    try {
      final db = await database;
      final count = await db.update(
        'local_events',
        event.copyWith(updatedAt: DateTime.now()).toMap(),
        where: 'id = ?',
        whereArgs: [event.id],
      );
      debugPrint('Updated $count event(s), id: ${event.id}');
      return count;
    } catch (e) {
      debugPrint('Error updating event: $e');
      rethrow;
    }
  }

  /// 刪除事件（帶錯誤處理）
  Future<int> deleteEvent(int id) async {
    try {
      final db = await database;
      final count = await db.delete(
        'local_events',
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('Deleted $count event(s), id: $id');
      return count;
    } catch (e) {
      debugPrint('Error deleting event: $e');
      rethrow;
    }
  }

  /// 取得所有事件（帶容錯處理）
  Future<List<LocalCalendarEvent>> getAllEvents() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'local_events',
        orderBy: 'start_time ASC',
      );

      final events = <LocalCalendarEvent>[];
      for (var map in maps) {
        try {
          events.add(LocalCalendarEvent.fromMap(map));
        } catch (e) {
          debugPrint('Error parsing event: $e, data: $map');
          // 跳過無法解析的事件，繼續處理其他事件
        }
      }
      
      debugPrint('Loaded ${events.length} events from database');
      return events;
    } catch (e) {
      debugPrint('Error getting all events: $e');
      rethrow;
    }
  }

  /// 取得指定日期範圍的事件
  Future<List<LocalCalendarEvent>> getEventsInRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_events',
      where: 'start_time <= ? AND end_time >= ?',
      whereArgs: [end.toIso8601String(), start.toIso8601String()],
      orderBy: 'start_time ASC',
    );

    final events = List.generate(maps.length, (i) {
      return LocalCalendarEvent.fromMap(maps[i]);
    });

    // 過濾出真正在範圍內的事件（考慮重複規則）
    return events.where((event) {
      if (event.recurrenceType == RecurrenceType.none) {
        return true; // SQL 查詢已經過濾
      }

      // 檢查重複事件是否在範圍內發生
      final currentDate = DateTime(start.year, start.month, start.day);
      final endDate = DateTime(end.year, end.month, end.day);
      
      DateTime checkDate = currentDate;
      while (checkDate.isBefore(endDate) || checkDate.isAtSameMomentAs(endDate)) {
        if (event.occursOnDate(checkDate)) {
          return true;
        }
        checkDate = checkDate.add(const Duration(days: 1));
      }
      
      return false;
    }).toList();
  }

  /// 取得指定日期的事件
  Future<List<LocalCalendarEvent>> getEventsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    return await getEventsInRange(startOfDay, endOfDay);
  }

  /// 取得指定月份的事件
  Future<List<LocalCalendarEvent>> getEventsForMonth(DateTime month) async {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    
    return await getEventsInRange(firstDay, lastDay);
  }

  /// 搜尋事件
  Future<List<LocalCalendarEvent>> searchEvents(String keyword) async {
    if (keyword.isEmpty) return await getAllEvents();

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_events',
      where: 'title LIKE ? OR description LIKE ? OR location LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%', '%$keyword%'],
      orderBy: 'start_time ASC',
    );

    return List.generate(maps.length, (i) {
      return LocalCalendarEvent.fromMap(maps[i]);
    });
  }

  /// 取得即將到來的事件
  Future<List<LocalCalendarEvent>> getUpcomingEvents({int days = 30}) async {
    final now = DateTime.now();
    final future = now.add(Duration(days: days));
    
    return await getEventsInRange(now, future);
  }

  /// 取得今天的事件
  Future<List<LocalCalendarEvent>> getTodayEvents() async {
    return await getEventsForDate(DateTime.now());
  }

  /// 取得本週的事件
  Future<List<LocalCalendarEvent>> getThisWeekEvents() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    
    return await getEventsInRange(weekStart, weekEnd);
  }

  /// 取得事件數量統計
  Future<int> getEventCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM local_events'),
    );
    return count ?? 0;
  }

  /// 清空所有事件
  Future<int> deleteAllEvents() async {
    final db = await database;
    return await db.delete('local_events');
  }

  /// 關閉資料庫
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
