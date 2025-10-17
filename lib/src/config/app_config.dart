import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App 配置類
class AppConfig {
  // Backend API
  static String get backendUrl => dotenv.env['BACKEND_URL'] ?? 'https://qaq-api-v2.ntut.org/api';
  
  // NTUT API (直接調用)
  static String get ntutApiBaseUrl => dotenv.env['NTUT_API_BASE_URL'] ?? 'https://app.ntut.edu.tw';
  static String get ntutCourseBaseUrl => dotenv.env['NTUT_COURSE_BASE_URL'] ?? 'https://aps.ntut.edu.tw/course/tw';
  
  // NTUT API Endpoints
  static const String loginEndpoint = '/login.do';
  static const String sessionCheckEndpoint = '/sessionCheckApp.do';
  static const String systemTreeEndpoint = '/aptreeList.do';
  static const String courseTableEndpoint = '/courseTable.do';
  
  // Backend Endpoints
  static const String syncDataEndpoint = '/data/sync';
  static const String profileEndpoint = '/data/:studentId/profile';
  static const String coursesEndpoint = '/data/:studentId/courses';
  static const String gradesEndpoint = '/data/:studentId/grades';
  
  // HTTP Headers
  static const String userAgent = 'Direk ios App'; // 重要！NTUT API 要求
  
  // App Info
  static String get appName => dotenv.env['APP_NAME'] ?? 'QAQ';
  static String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';
  
  // Session
  static const Duration sessionTimeout = Duration(minutes: 30);
}
