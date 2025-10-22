import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/empty_classroom.dart';

/// 課程搜索服務
/// 提供課程搜尋、學院資訊、學程資訊、空教室查詢等功能
/// 使用 qaq-api-v2 後端 API
class CourseSearchService {
  late final Dio _dio;

  // 從環境變數讀取後端 URL，如果沒有則使用預設值
  // 使用 Cloudflare Workers 部署的 API
  static String get backendUrl {
    final baseUrl = dotenv.env['BACKEND_URL'] ?? 'https://qaq-api-v2.ntut.org/api';
    return '$baseUrl/courses';
  }

  CourseSearchService({Dio? dio}) {
    _dio = dio ?? Dio(BaseOptions(
      baseUrl: backendUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));
  }

  /// 搜尋課程
  /// 
  /// [keyword] 關鍵字（課程名稱、教師、課號）
  /// [year] 學年度
  /// [semester] 學期
  /// [category] 博雅類別
  /// [college] 學院
  /// [timeSlots] 上課時間篩選
  /// [gradeCode] 班級代碼
  /// [programCode] 學程代碼
  /// [programType] 學程類型
  Future<List<Map<String, dynamic>>> searchCourses({
    String? keyword,
    String year = '114',
    String semester = '1',
    String? category,
    String? college,
    List<Map<String, dynamic>>? timeSlots,
    String? gradeCode,
    String? programCode,
    String? programType,
  }) async {
    try {
      print('[CourseSearch] 搜尋課程: keyword=$keyword, year=$year, semester=$semester, college=$college');

      final queryParams = <String, dynamic>{
        'year': year,
        'semester': semester,
      };

      if (keyword != null && keyword.isNotEmpty) {
        queryParams['keyword'] = keyword;
      }
      if (category != null) {
        queryParams['category'] = category;
      }
      if (college != null) {
        queryParams['college'] = college;
      }
      if (gradeCode != null) {
        queryParams['gradeCode'] = gradeCode;
      }
      if (programCode != null) {
        queryParams['programCode'] = programCode;
      }
      if (programType != null) {
        queryParams['programType'] = programType;
      }
      if (timeSlots != null && timeSlots.isNotEmpty) {
        queryParams['timeSlots'] = jsonEncode(timeSlots);
      }

      final response = await _dio.get(
        '/search',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> courses = response.data['data'] ?? [];
        print('[CourseSearch] 找到 ${courses.length} 筆課程');
        return courses.cast<Map<String, dynamic>>();
      } else {
        print('[CourseSearch] 搜尋課程失敗: ${response.data}');
        return [];
      }
    } catch (e) {
      print('[CourseSearch] 搜尋課程錯誤: $e');
      return [];
    }
  }

  /// 取得學院/系所/班級結構
  /// 
  /// [year] 學年度
  /// [semester] 學期
  Future<Map<String, dynamic>?> getColleges({
    String year = '114',
    String semester = '1',
  }) async {
    try {
      print('[CourseSearch] 取得學院結構: year=$year, semester=$semester');

      final response = await _dio.get(
        '/colleges',
        queryParameters: {
          'year': year,
          'semester': semester,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('[CourseSearch] 成功取得學院結構');
        return response.data['data'];
      } else {
        print('[CourseSearch] 取得學院結構失敗: ${response.data}');
        return null;
      }
    } catch (e) {
      print('[CourseSearch] 取得學院結構錯誤: $e');
      return null;
    }
  }

  /// 根據班級代碼查詢課程
  /// 
  /// [gradeCode] 班級代碼
  /// [year] 學年度
  /// [semester] 學期
  Future<List<Map<String, dynamic>>> getCoursesByGrade({
    required String gradeCode,
    String year = '114',
    String semester = '1',
  }) async {
    try {
      print('[CourseSearch] 查詢班級課程: gradeCode=$gradeCode, year=$year, semester=$semester');

      final response = await _dio.get(
        '/by-grade',
        queryParameters: {
          'gradeCode': gradeCode,
          'year': year,
          'semester': semester,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> courses = response.data['data'] ?? [];
        print('[CourseSearch] 找到 ${courses.length} 筆班級課程');
        return courses.cast<Map<String, dynamic>>();
      } else {
        print('[CourseSearch] 查詢班級課程失敗: ${response.data}');
        return [];
      }
    } catch (e) {
      print('[CourseSearch] 查詢班級課程錯誤: $e');
      return [];
    }
  }

  /// 取得學程/微學程列表
  /// 
  /// [year] 學年度
  /// [semester] 學期
  Future<Map<String, dynamic>?> getPrograms({
    String year = '114',
    String semester = '1',
  }) async {
    try {
      print('[CourseSearch] 取得學程列表: year=$year, semester=$semester');

      final response = await _dio.get(
        '/programs',
        queryParameters: {
          'year': year,
          'semester': semester,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('[CourseSearch] 成功取得學程列表');
        return response.data['data'];
      } else {
        print('[CourseSearch] 取得學程列表失敗: ${response.data}');
        return null;
      }
    } catch (e) {
      print('[CourseSearch] 取得學程列表錯誤: $e');
      return null;
    }
  }

  /// 根據學程代碼查詢課程
  /// 
  /// [programCode] 學程代碼
  /// [type] 學程類型 ('micro-program' 或 'program')
  /// [year] 學年度
  /// [semester] 學期
  Future<List<Map<String, dynamic>>> getCoursesByProgram({
    required String programCode,
    String type = 'micro-program',
    String year = '114',
    String semester = '1',
  }) async {
    try {
      print('[CourseSearch] 查詢學程課程: programCode=$programCode, type=$type, year=$year, semester=$semester');

      final response = await _dio.get(
        '/by-program',
        queryParameters: {
          'programCode': programCode,
          'type': type,
          'year': year,
          'semester': semester,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> courses = response.data['data'] ?? [];
        print('[CourseSearch] 找到 ${courses.length} 筆學程課程');
        return courses.cast<Map<String, dynamic>>();
      } else {
        print('[CourseSearch] 查詢學程課程失敗: ${response.data}');
        return [];
      }
    } catch (e) {
      print('[CourseSearch] 查詢學程課程錯誤: $e');
      return [];
    }
  }

  /// 取得課程詳細資料（包含評分標準等大綱資訊）
  /// 
  /// [courseId] 課程代碼
  /// [year] 學年度
  /// [semester] 學期
  Future<Map<String, dynamic>?> getCourseDetail(
    String courseId, {
    String year = '114',
    String semester = '1',
  }) async {
    try {
      print('[CourseSearch] 查詢課程詳細資料: courseId=$courseId, year=$year, semester=$semester');

      final response = await _dio.get(
        '/detail/$courseId',
        queryParameters: {
          'year': year,
          'semester': semester,
        },
      );

      if (response.statusCode == 200) {
        print('[CourseSearch] 成功取得課程 $courseId 的詳細資料');
        return response.data;
      } else if (response.statusCode == 404) {
        print('[CourseSearch] 課程 $courseId 沒有詳細資料');
        return null;
      } else {
        print('[CourseSearch] 查詢課程詳細資料失敗: ${response.data}');
        return null;
      }
    } catch (e) {
      print('[CourseSearch] 查詢課程詳細資料錯誤: $e');
      return null;
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
      print('[CourseSearch] 查詢空教室: $dayOfWeek, periods: $periods');

      final queryParams = <String, dynamic>{
        'dayOfWeek': dayOfWeek,
        if (periods != null && periods.isNotEmpty) 'periods': jsonEncode(periods),
        if (year != null) 'year': year,
        if (semester != null) 'semester': semester,
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      };

      debugPrint('[CourseSearch] Request URL: $backendUrl/empty-classrooms');
      debugPrint('[CourseSearch] Query params: $queryParams');

      final response = await _dio.get(
        '/empty-classrooms',
        queryParameters: queryParams,
      );

      debugPrint('[CourseSearch] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = EmptyClassroomResponse.fromJson(response.data);
        print('[CourseSearch] 找到 ${result.count} 間空教室');
        return result;
      }

      print('[CourseSearch] 查詢空教室失敗: ${response.statusCode}');
      return null;
    } catch (e) {
      print('[CourseSearch] 查詢空教室失敗: $e');
      return null;
    }
  }

  void dispose() {
    _dio.close();
  }
}
