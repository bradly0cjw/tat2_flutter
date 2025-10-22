import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'ntut_auth_service.dart';

/// NTUT 校務系統服務
/// 處理校務系統 SSO 登入、系統樹狀結構等功能
class NtutAdminService {
  final NtutAuthService _authService;
  late final Dio _dio;
  late final CookieJar _cookieJar;

  static const String userAgent = 'Direk ios App';

  NtutAdminService({required NtutAuthService authService})
      : _authService = authService {
    _cookieJar = _authService.cookieJar;
    
    _dio = Dio(BaseOptions(
      baseUrl: NtutAuthService.baseUrl,
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
    
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  /// 通用的校務系統 SSO 登入方法
  /// 
  /// [serviceCode] 校務系統代碼（如 AdminSystemCodes 中定義的代碼）
  /// 
  /// Returns: 系統的 URL，可用於 WebView 訪問
  Future<String?> getAdminSystemUrl(String serviceCode) async {
    if (!_authService.isLoggedIn) {
      throw Exception('請先登入');
    }

    try {
      print('[NTUT Admin] 開始 SSO 轉移到校務系統: $serviceCode');

      // Step 1: 確保 JSESSIONID 在 CookieJar 中
      final baseUri = Uri.parse(NtutAuthService.baseUrl);
      final freshCookie = Cookie('JSESSIONID', _authService.jsessionId!);
      await _cookieJar.saveFromResponse(baseUri, [freshCookie]);
      debugPrint('[NTUT Admin] 已重新儲存 JSESSIONID');

      // Step 2: 請求 SSO 授權（獲取轉移資訊）
      final ssoUri = Uri.parse('${NtutAuthService.baseUrl}/ssoIndex.do').replace(
        queryParameters: {'apOu': serviceCode},
      );
      
      debugPrint('[NTUT Admin] 請求 SSO 授權: $ssoUri');
      final ssoResponse = await _dio.getUri(ssoUri);
      
      final htmlContent = ssoResponse.data?.toString() ?? '';
      if (htmlContent.isEmpty || htmlContent.length < 100) {
        print('[NTUT Admin] SSO 授權回應為空');
        return null;
      }
      
      debugPrint('[NTUT Admin] 成功獲取 SSO 授權表單 (${htmlContent.length} bytes)');

      // Step 3: 解析表單參數
      final RegExp inputPattern = RegExp(r"<input[^>]*name='([^']+)'[^>]*value='([^']*)'");
      final Map<String, String> formData = {};
      
      for (final match in inputPattern.allMatches(htmlContent)) {
        final name = match.group(1);
        final value = match.group(2);
        if (name != null) {
          formData[name] = value ?? '';
        }
      }
      
      // 提取 form action
      final actionMatch = RegExp(r"action='([^']+)'").firstMatch(htmlContent);
      if (actionMatch == null || formData.isEmpty) {
        print('[NTUT Admin] 無法解析 SSO 表單');
        return null;
      }
      
      final action = actionMatch.group(1)!;
      debugPrint('[NTUT Admin] SSO 表單參數: ${formData.keys.join(", ")}');
      debugPrint('[NTUT Admin] Form action: $action');

      // Step 4: 提交表單
      final submitUrl = action.startsWith('http') 
          ? Uri.parse(action) 
          : Uri.parse('${NtutAuthService.baseUrl}/$action');
      
      debugPrint('[NTUT Admin] 提交 SSO 表單到: $submitUrl');
      final submitResponse = await _dio.postUri(
        submitUrl, 
        data: formData,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status! < 500,
        ),
      );
      
      // Step 5: 處理重定向
      if (submitResponse.statusCode == 302 || submitResponse.statusCode == 301) {
        final locationHeader = submitResponse.headers['location'];
        if (locationHeader != null && locationHeader.isNotEmpty) {
          final redirectUrl = locationHeader.first;
          print('[NTUT Admin] SSO 成功，系統 URL: $redirectUrl');
          return redirectUrl;
        }
      }
      
      // 如果沒有重定向，可能直接返回內容
      if (submitResponse.statusCode == 200) {
        // 有些系統可能在表單中包含最終 URL
        final urlMatch = RegExp(r'''window\.location\.href\s*=\s*["']([^"']+)["']''')
            .firstMatch(submitResponse.data?.toString() ?? '');
        if (urlMatch != null) {
          final targetUrl = urlMatch.group(1)!;
          print('[NTUT Admin] SSO 成功，從 JavaScript 提取 URL: $targetUrl');
          return targetUrl;
        }
        
        // 返回提交的 URL（某些系統不需要重定向）
        print('[NTUT Admin] SSO 成功，使用提交 URL');
        return submitUrl.toString();
      }
      
      print('[NTUT Admin] SSO 轉移失敗: ${submitResponse.statusCode}');
      return null;
    } catch (e) {
      print('[NTUT Admin] 校務系統 SSO 失敗: $e');
      return null;
    }
  }

  /// 取得校務系統主頁的系統樹狀結構
  /// 用於顯示所有可用的系統分類和連結
  /// 
  /// [apDn] 可選的系統節點參數
  Future<Map<String, dynamic>?> getAdminSystemTree({String? apDn}) async {
    print('[NTUT Admin] [getAdminSystemTree] 開始');
    
    if (!_authService.isLoggedIn) {
      print('[NTUT Admin] [getAdminSystemTree] 未登入！');
      throw Exception('請先登入');
    }

    try {
      final data = apDn != null ? {'apDn': apDn} : null;
      print('[NTUT Admin] [getAdminSystemTree] 發送請求到 /aptreeList.do, data: $data');
      
      final response = await _dio.post(
        '/aptreeList.do',
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      ).timeout(const Duration(seconds: 10));

      print('[NTUT Admin] [getAdminSystemTree] 回應狀態碼: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseText = response.data.toString();
        debugPrint('[NTUT Admin] [getAdminSystemTree] 回應長度: ${responseText.length} bytes');
        
        final result = json.decode(responseText);
        print('[NTUT Admin] [getAdminSystemTree] 成功解析 JSON');
        
        if (result is Map<String, dynamic>) {
          print('[NTUT Admin] [getAdminSystemTree] 返回的是 Map，包含 ${result.keys.length} 個 key');
          if (result.containsKey('apList')) {
            final apList = result['apList'];
            if (apList is List) {
              print('[NTUT Admin] [getAdminSystemTree] apList 包含 ${apList.length} 個項目');
            }
          }
        }
        
        return result;
      } else {
        print('[NTUT Admin] [getAdminSystemTree] HTTP 狀態碼錯誤: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      print('[NTUT Admin] [getAdminSystemTree] 錯誤: $e');
      debugPrint('[NTUT Admin] [getAdminSystemTree] StackTrace: $stackTrace');
      return null;
    }
  }

  /// 取得系統樹（已廢棄，使用 getAdminSystemTree 代替）
  @Deprecated('使用 getAdminSystemTree 代替')
  Future<Map<String, dynamic>> getSystemTree(String sessionId, String apDn) async {
    try {
      final response = await _dio.post(
        '/aptreeList.do',
        data: {'apdn': apDn},
        options: Options(headers: {'Cookie': 'JSESSIONID=$sessionId'}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.data.toString());
      }
      return {'success': false};
    } catch (e) {
      print('[NTUT Admin] 獲取系統樹失敗: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
