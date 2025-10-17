import 'dart:io';
import 'package:dio/dio.dart';

/// Cookie 過濾器，用於排除響應中的某些無效 Cookie
/// 
/// i學院的伺服器會設置一些不符合規範的 Cookie（例如名稱包含斜線 /），
/// 這會導致 dio_cookie_manager 解析錯誤。
/// 此攔截器會在響應到達 CookieManager 之前過濾掉這些 Cookie。
class ResponseCookieFilter extends Interceptor {
  /// 黑名單機制：通過 [blockedCookieNamePatterns] 傳入需要移除的 Cookie 名稱模式
  const ResponseCookieFilter({
    required List<RegExp> blockedCookieNamePatterns,
  }) : _blockedCookieNamePatterns = blockedCookieNamePatterns;

  final List<RegExp> _blockedCookieNamePatterns;

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    try {
      final clearedResponse = _removeCookiesFrom(response);
      handler.next(clearedResponse);
    } on Exception catch (e) {
      final err = DioException(
        requestOptions: response.requestOptions,
        error: e,
      )..stackTrace;
      handler.reject(err, true);
    }
  }

  Response<dynamic> _removeCookiesFrom(Response<dynamic> response) {
    final cookies = response.headers[HttpHeaders.setCookieHeader]
        ?.where((cookie) => _blockedCookieNamePatterns.every(
              (pattern) => !pattern.hasMatch(cookie),
            ))
        .toList();

    if (cookies != null) {
      response.headers.set(HttpHeaders.setCookieHeader, cookies);
    }
    return response;
  }
}

/// 需要被封鎖的 Cookie 名稱模式列表
/// 
/// 北科大的後端伺服器會在響應頭中添加一個 Cookie，
/// 其名稱格式為 BIGipServerVPFl/...，
/// 在這個名稱中，有不符合規範的字符（/），
/// 這會導致 dio 解析錯誤，因此需要將其過濾掉。
/// 
/// 參考文章：https://juejin.cn/post/6844903934042046472
final List<RegExp> blockedCookieNamePatterns = [
  RegExp('BIGipServer'),
];
