import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

/// NTUT 認證服務
/// 處理登入、登出、Session 管理
class NtutAuthService {
  late final Dio _dio;
  late final CookieJar _cookieJar;

  static const String baseUrl = 'https://app.ntut.edu.tw';
  static const String userAgent = 'Direk ios App';

  String? _jsessionId;
  String? _userIdentifier;

  bool get isLoggedIn => _jsessionId != null && _userIdentifier != null;
  String? get jsessionId => _jsessionId;
  String? get userIdentifier => _userIdentifier;
  CookieJar get cookieJar => _cookieJar;

  NtutAuthService({CookieJar? cookieJar}) {
    _cookieJar = cookieJar ?? CookieJar();
    
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': userAgent,
        'Accept': 'application/json, text/plain, */*',
      },
      contentType: Headers.formUrlEncodedContentType,
      followRedirects: true,
      validateStatus: (status) => status! < 500,
    ));
    
    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        final setCookies = response.headers['set-cookie'];
        if (setCookies != null) {
          final filteredCookies = setCookies.where((cookie) => !cookie.contains('BIGipServer')).toList();
          if (filteredCookies.length != setCookies.length) {
            response.headers.set('set-cookie', filteredCookies);
          }
        }
        
        // 檢測 Session 過期的標誌
        _checkSessionExpired(response);
        
        handler.next(response);
      },
      onError: (error, handler) {
        // 檢查錯誤回應中的 Session 過期標誌
        if (error.response != null) {
          _checkSessionExpired(error.response!);
        }
        handler.next(error);
      },
    ));
    
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  /// 檢測回應中的 Session 過期標誌
  void _checkSessionExpired(Response response) {
    // 檢測重定向到登入頁
    if (response.statusCode == 302) {
      final location = response.headers['location']?.first ?? '';
      if (location.contains('login') || location.contains('ssoIndex')) {
        print('[NTUT Auth] 檢測到 Session 過期（重定向到登入頁）');
        _jsessionId = null;
        _userIdentifier = null;
      }
    }
    
    // 檢測回應內容中的 Session 過期標誌
    if (response.statusCode == 200) {
      final responseText = response.data?.toString() ?? '';
      
      // 常見的 Session 過期標誌
      final sessionExpiredPatterns = [
        'session expired',
        'session timeout',
        '登入逾時',
        '請重新登入',
        'Please login again',
        '中斷連線',
      ];
      
      for (final pattern in sessionExpiredPatterns) {
        if (responseText.toLowerCase().contains(pattern.toLowerCase())) {
          print('[NTUT Auth] 檢測到 Session 過期標誌: $pattern');
          _jsessionId = null;
          _userIdentifier = null;
          break;
        }
      }
    }
  }

  String? _extractJSessionId(List<String>? cookies) {
    if (cookies == null || cookies.isEmpty) return null;
    for (final cookie in cookies) {
      final match = RegExp(r'JSESSIONID=([^;]+)').firstMatch(cookie);
      if (match != null) return match.group(1);
    }
    return null;
  }

  /// 登入
  /// 
  /// [username] 使用者名稱（學號）
  /// [password] 密碼
  /// 
  /// Returns: 登入結果包含 success, sessionId, givenName, userMail, message
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      print('[NTUT Auth] 登入請求: $username');

      final requestBody = {
        'muid': username,
        'mpassword': password,
      };

      final loginResponse = await _dio.post(
        '/login.do',
        data: requestBody,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      if (loginResponse.statusCode != 200) {
        throw Exception('登入請求失敗: ${loginResponse.statusCode}');
      }

      final baseUri = Uri.parse(baseUrl);
      final cookies = await _cookieJar.loadForRequest(baseUri);
      
      for (final cookie in cookies) {
        if (cookie.name == 'JSESSIONID') {
          _jsessionId = cookie.value;
          print('[NTUT Auth] 成功取得 JSESSIONID');
        }
      }
      
      if (_jsessionId == null) {
        final setCookies = loginResponse.headers['set-cookie'];
        _jsessionId = _extractJSessionId(setCookies);
      }

      final responseData = loginResponse.data;
      
      String responseText;
      if (responseData is String) {
        responseText = responseData.trim();
      } else {
        responseText = responseData.toString().trim();
      }

      try {
        final Map<String, dynamic> result = json.decode(responseText);
        final isSuccess = result['success'] == true;
        
        if (isSuccess) {
          _userIdentifier = username;
          final userName = result['givenName']?.toString() ?? '';
          final userMail = result['userMail']?.toString() ?? '';
          
          print('[NTUT Auth] 登入成功: $userName ($username)');
          
          return {
            'success': true,
            'sessionId': _jsessionId,
            'givenName': userName,
            'userMail': userMail,
            'message': '登入成功',
          };
        } else {
          final errorMsg = result['errorMsg']?.toString() ?? '未知錯誤';
          print('[NTUT Auth] 登入失敗: $errorMsg');
          return {'success': false, 'message': errorMsg};
        }
      } catch (e) {
        print('[NTUT Auth] JSON 解析失敗: $e');
        return {'success': false, 'message': 'API 回應格式錯誤: $e'};
      }
    } catch (e) {
      print('[NTUT Auth] 登入錯誤: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 檢查 Session 是否有效
  Future<bool> checkSession() async {
    if (_jsessionId == null) {
      return false;
    }

    try {
      final response = await _dio.get('/sessionCheckApp.do');

      if (response.statusCode == 200) {
        final result = json.decode(response.data.toString());
        final isValid = result['success'] == true;
        return isValid;
      }
      return false;
    } catch (e) {
      print('[NTUT Auth] Session 檢查失敗: $e');
      return false;
    }
  }

  /// 登出
  void logout() {
    _jsessionId = null;
    _userIdentifier = null;
    print('[NTUT Auth] 已登出');
  }

  /// 取得指定 URL 的 Cookies
  Future<List<Cookie>> getCookiesForUrl(Uri url) async {
    return await _cookieJar.loadForRequest(url);
  }
}
