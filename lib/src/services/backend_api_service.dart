import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/student.dart';
import '../models/course.dart';
import '../models/grade.dart';
import '../models/empty_classroom.dart';

/// Backend API Service
/// 提供後端 API 的數據同步功能
class BackendApiService {
  final http.Client _client;

  BackendApiService({http.Client? client}) : _client = client ?? http.Client();

  /// HTTP Headers
  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
      };

  /// 上傳數據到 Backend
  /// 
  /// [studentId] 學號
  /// [student] 學生資料
  /// [courses] 課表資料
  /// [grades] 成績資料
  /// 
  /// Returns: {success: bool, synced: {...}, errors: [...]}
  Future<Map<String, dynamic>> syncData({
    required String studentId,
    Student? student,
    List<Course>? courses,
    List<Grade>? grades,
  }) async {
    try {
      print('[Backend API] 上傳數據到 Backend: $studentId');

      final url = Uri.parse('${AppConfig.backendUrl}${AppConfig.syncDataEndpoint}');
      final body = {
        'studentId': studentId,
        if (student != null) 'profile': student.toJson(),
        if (courses != null) 'courses': courses.map((c) => c.toJson()).toList(),
        if (grades != null) 'grades': grades.map((g) => g.toJson()).toList(),
      };

      debugPrint('[Backend API] 上傳數據: ${body.keys.toList()}');

      final response = await _client.post(
        url,
        headers: _headers,
        body: json.encode(body),
      );

      debugPrint('[Backend API] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('[Backend API] 同步成功: ${data['synced']}');
        return data;
      }

      return {
        'success': false,
        'error': 'HTTP ${response.statusCode}: ${response.body}',
      };
    } catch (e) {
      print('[Backend API] 上傳數據失敗: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 從 Backend 讀取學生資料
  Future<Student?> getProfile(String studentId) async {
    try {
      final url = Uri.parse(
        '${AppConfig.backendUrl}${AppConfig.profileEndpoint.replaceAll(':studentId', studentId)}',
      );
      final response = await _client.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Student.fromJson(data['profile']);
      }

      return null;
    } catch (e) {
      print('[Backend API] 讀取學生資料失敗: $e');
      return null;
    }
  }

  /// 從 Backend 讀取課表
  Future<List<Course>> getCourses(String studentId, {String? semester}) async {
    try {
      final url = Uri.parse(
        '${AppConfig.backendUrl}${AppConfig.coursesEndpoint.replaceAll(':studentId', studentId)}',
      ).replace(queryParameters: semester != null ? {'semester': semester} : null);
      
      final response = await _client.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final courses = (data['courses'] as List)
            .map((c) => Course.fromJson(c))
            .toList();
        return courses;
      }

      return [];
    } catch (e) {
      print('[Backend API] 讀取課表失敗: $e');
      return [];
    }
  }

  /// 從 Backend 讀取成績
  Future<List<Grade>> getGrades(String studentId, {String? semester}) async {
    try {
      final url = Uri.parse(
        '${AppConfig.backendUrl}${AppConfig.gradesEndpoint.replaceAll(':studentId', studentId)}',
      ).replace(queryParameters: semester != null ? {'semester': semester} : null);
      
      final response = await _client.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final grades = (data['grades'] as List)
            .map((g) => Grade.fromJson(g))
            .toList();
        return grades;
      }

      return [];
    } catch (e) {
      print('[Backend API] 讀取成績失敗: $e');
      return [];
    }
  }

  /// 查詢空教室
  /// 
  /// [dayOfWeek] 星期 ('mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun')
  /// [periods] 時段陣列 (例如 ['1', '2', '3'])
  /// [year] 學年度
  /// [semester] 學期
  /// [keyword] 搜尋關鍵字（教室名稱）
  Future<EmptyClassroomResponse?> getEmptyClassrooms({
    required String dayOfWeek,
    List<String>? periods,
    String? year,
    String? semester,
    String? keyword,
  }) async {
    try {
      print('[Backend API] 查詢空教室: $dayOfWeek, periods: $periods');

      final queryParams = {
        'dayOfWeek': dayOfWeek,
        if (periods != null && periods.isNotEmpty) 'periods': json.encode(periods),
        if (year != null) 'year': year,
        if (semester != null) 'semester': semester,
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      };

      final url = Uri.parse('${AppConfig.backendUrl}/courses/empty-classrooms')
          .replace(queryParameters: queryParams);

      debugPrint('[Backend API] Request URL: $url');

      final response = await _client.get(url, headers: _headers);

      debugPrint('[Backend API] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = EmptyClassroomResponse.fromJson(data);
        print('[Backend API] 找到 ${result.count} 間空教室');
        return result;
      }

      print('[Backend API] 查詢空教室失敗: ${response.statusCode}');
      return null;
    } catch (e) {
      print('[Backend API] 查詢空教室失敗: $e');
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}

