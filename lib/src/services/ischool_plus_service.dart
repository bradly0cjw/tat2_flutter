import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import '../connectors/ischool_plus_connector.dart';
import '../interceptors/response_cookie_filter.dart';
import 'ntut_api_service.dart';

/// i學院服務管理類
/// 管理登入狀態、Cookie 和共享實例
/// 
/// 重要：使用 NtutApiService 的 CookieJar 來共享登入狀態
class ISchoolPlusService {
  static ISchoolPlusService? _instance;
  
  /// 初始化 i學院服務
  /// 
  /// 必須先調用此方法並傳入 NtutApiService 實例
  static void initialize(NtutApiService ntutApiService) {
    _instance = ISchoolPlusService._(ntutApiService);
  }
  
  /// 取得 i學院服務實例
  /// 
  /// 使用前必須先調用 initialize()
  static ISchoolPlusService get instance {
    if (_instance == null) {
      throw StateError('ISchoolPlusService 尚未初始化。請先調用 ISchoolPlusService.initialize(ntutApiService)');
    }
    return _instance!;
  }

  late final Dio _dio;
  late final ISchoolPlusConnector _connector;
  final NtutApiService _ntutApiService;
  
  bool _isLoggedIn = false;
  
  ISchoolPlusService._(this._ntutApiService) {
    // 創建專用於 i學院的 Dio 實例，但使用共享的 CookieJar
    _dio = Dio();
    // 重要：ResponseCookieFilter 必須在 CookieManager 之前添加
    // 這樣才能在 Cookie 被解析之前過濾掉無效的 Cookie
    _dio.interceptors.add(
      ResponseCookieFilter(blockedCookieNamePatterns: blockedCookieNamePatterns),
    );
    _dio.interceptors.add(CookieManager(_ntutApiService.cookieJar));
    _dio.options.followRedirects = true;
    _dio.options.maxRedirects = 5;
    _dio.options.validateStatus = (status) => status != null && status < 500;
    _dio.options.contentType = 'application/x-www-form-urlencoded';  // 重要：使用 form-urlencoded 格式
    _dio.options.headers = {
      'User-Agent': NtutApiService.userAgent,  // 使用相同的 User-Agent
    };
    
    _connector = ISchoolPlusConnector(dio: _dio);
  }
  
  /// 取得 NTUT API 服務實例（用於檢查登入狀態）
  NtutApiService get ntutApi => _ntutApiService;

  /// 取得連接器實例
  ISchoolPlusConnector get connector => _connector;

  /// 是否已登入 i學院
  bool get isLoggedIn => _isLoggedIn;

  /// 登入 i學院
  /// 
  /// 前提：必須先登入 NTUT Portal
  /// 如果第一次登入失敗，會自動重試一次
  Future<bool> login() async {
    if (_isLoggedIn) {
      return true;
    }
    
    // 檢查是否已登入 NTUT Portal
    if (!_ntutApiService.isLoggedIn) {
      throw Exception('必須先登入 NTUT Portal 才能登入 i學院');
    }

    // 第一次嘗試登入
    bool success = await _connector.login();
    
    // 如果第一次失敗，重試一次
    if (!success) {
      print('[ISchoolPlusService] 第一次登入失敗，正在重試...');
      await Future.delayed(const Duration(seconds: 1)); // 稍微等待一下
      success = await _connector.login();
      if (success) {
        print('[ISchoolPlusService] 重試登入成功');
      } else {
        print('[ISchoolPlusService] 重試登入仍失敗');
      }
    }
    
    _isLoggedIn = success;
    return success;
  }

  /// 登出
  Future<void> logout() async {
    _isLoggedIn = false;
    // 不需要清除 cookies，因為我們使用的是共享的 CookieJar
    // 如果清除會影響到 NTUT Portal 的登入狀態
  }

  /// 重置登入狀態（當登入過期時使用）
  void resetLoginState() {
    _isLoggedIn = false;
  }
}
