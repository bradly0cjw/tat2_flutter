import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/grade.dart';
import '../models/semester_grade_stats.dart';

/// 成績本地緩存服務
class GradesCacheService {
  static const String _gradesKey = 'cached_grades';
  static const String _statsKey = 'cached_semester_stats';
  static const String _ranksKey = 'cached_ranks';
  static const String _timestampKey = 'grades_cache_timestamp';
  static const Duration _cacheExpiry = Duration(hours: 24); // 緩存 24 小時
  
  /// 檢查緩存是否過期
  Future<bool> isCacheExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_timestampKey);
      
      if (timestamp == null) return true;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      
      return now.difference(cacheTime) > _cacheExpiry;
    } catch (e) {
      debugPrint('[GradesCache] 檢查緩存過期失敗: $e');
      return true;
    }
  }
  
  /// 保存成績到緩存（包含完整的 extra 數據）
  Future<bool> saveGrades(List<Grade> grades) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 確保 toJson 包含所有數據
      final gradesJson = grades.map((g) {
        final json = g.toJson();
        // 確保 extra 數據也被序列化
        if (g.extra != null) {
          json['extra'] = g.extra;
        }
        return json;
      }).toList();
      
      final jsonString = json.encode(gradesJson);
      
      await prefs.setString(_gradesKey, jsonString);
      await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
      
      return true;
    } catch (e) {
      debugPrint('[GradesCache] 保存成績緩存失敗: $e');
      return false;
    }
  }
  
  /// 保存學期統計到緩存
  Future<bool> saveSemesterStats(List<SemesterGradeStats> stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = stats.map((s) => s.toJson()).toList();
      final jsonString = json.encode(statsJson);
      
      await prefs.setString(_statsKey, jsonString);
      
      return true;
    } catch (e) {
      debugPrint('[GradesCache] 保存學期統計緩存失敗: $e');
      return false;
    }
  }
  
  /// 從緩存讀取成績
  Future<List<Grade>?> loadGrades() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_gradesKey);
      
      if (jsonString == null) {
        return null;
      }
      
      final List<dynamic> gradesJson = json.decode(jsonString);
      final grades = gradesJson.map((g) => Grade.fromJson(g)).toList();
      
      return grades;
    } catch (e) {
      debugPrint('[GradesCache] 讀取成績緩存失敗: $e');
      return null;
    }
  }
  
  /// 從緩存讀取學期統計
  Future<List<SemesterGradeStats>?> loadSemesterStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_statsKey);
      
      if (jsonString == null) {
        return null;
      }
      
      final List<dynamic> statsJson = json.decode(jsonString);
      final stats = statsJson.map((s) => SemesterGradeStats.fromJson(s)).toList();
      
      return stats;
    } catch (e) {
      debugPrint('[GradesCache] 讀取學期統計緩存失敗: $e');
      return null;
    }
  }
  
  /// 保存排名到緩存
  Future<bool> saveRanks(Map<String, Map<String, dynamic>> ranks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(ranks);
      
      await prefs.setString(_ranksKey, jsonString);
      
      return true;
    } catch (e) {
      debugPrint('[GradesCache] 保存排名緩存失敗: $e');
      return false;
    }
  }
  
  /// 從緩存讀取排名
  Future<Map<String, Map<String, dynamic>>?> loadRanks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_ranksKey);
      
      if (jsonString == null) {
        return null;
      }
      
      final Map<String, dynamic> decoded = json.decode(jsonString);
      final ranks = decoded.map((key, value) => 
        MapEntry(key, Map<String, dynamic>.from(value))
      );
      
      return ranks;
    } catch (e) {
      debugPrint('[GradesCache] 讀取排名緩存失敗: $e');
      return null;
    }
  }
  
  /// 清除緩存
  Future<bool> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_gradesKey);
      await prefs.remove(_statsKey);
      await prefs.remove(_ranksKey);
      await prefs.remove(_timestampKey);
      
      return true;
    } catch (e) {
      debugPrint('[GradesCache] 清除緩存失敗: $e');
      return false;
    }
  }
}
