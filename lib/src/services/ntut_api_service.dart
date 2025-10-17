import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// NTUT Portal API Service
/// 提供北科大校務系統登入、課表查詢、成績查詢等功能
class NtutApiService {
  late final Dio _dio;
  late final CookieJar _cookieJar;

  static const String baseUrl = 'https://app.ntut.edu.tw';
  static const String courseBaseUrl = 'https://aps.ntut.edu.tw';
  static const String userAgent = 'Direk ios App';

  String? _jsessionId;
  String? _courseJSessionId;
  String? _userIdentifier;

  bool get isLoggedIn => _jsessionId != null && _userIdentifier != null;
  
  CookieJar get cookieJar => _cookieJar;

  Future<List<Cookie>> getCookiesForUrl(Uri url) async {
    return await _cookieJar.loadForRequest(url);
  }

  NtutApiService() {
    _cookieJar = CookieJar();
    
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

  String? _extractJSessionId(List<String>? cookies) {
    if (cookies == null || cookies.isEmpty) return null;
    for (final cookie in cookies) {
      final match = RegExp(r'JSESSIONID=([^;]+)').firstMatch(cookie);
      if (match != null) return match.group(1);
    }
    return null;
  }

  /// 檢測回應中的 Session 過期標誌
  void _checkSessionExpired(Response response) {
    // 檢測重定向到登入頁
    if (response.statusCode == 302) {
      final location = response.headers['location']?.first ?? '';
      if (location.contains('login') || location.contains('ssoIndex')) {
        print('[NTUT API] 檢測到 Session 過期（重定向到登入頁）');
        _jsessionId = null;
        _courseJSessionId = null;
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
          print('[NTUT API] 檢測到 Session 過期標誌: $pattern');
          _jsessionId = null;
          _courseJSessionId = null;
          _userIdentifier = null;
          break;
        }
      }
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      print('[NTUT API] 登入請求: $username');

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
          print('[NTUT API] 成功取得 JSESSIONID');
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
          
          print('[NTUT API] 登入成功: $userName ($username)');
          
          return {
            'success': true,
            'sessionId': _jsessionId,
            'givenName': userName,
            'userMail': userMail,
            'message': '登入成功',
          };
        } else {
          final errorMsg = result['errorMsg']?.toString() ?? '未知錯誤';
          print('[NTUT API] 登入失敗: $errorMsg');
          return {'success': false, 'message': errorMsg};
        }
      } catch (e) {
        print('[NTUT API] JSON 解析失敗: $e');
        return {'success': false, 'message': 'API 回應格式錯誤: $e'};
      }
    } catch (e) {
      print('[NTUT API] 登入錯誤: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

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
      print('[NTUT API] Session 檢查失敗: $e');
      return false;
    }
  }

  Future<bool> _transferToCourseSystem() async {
    if (_jsessionId == null || _userIdentifier == null) {
      throw Exception('請先登入');
    }

    try {
      print('[NTUT API] 開始 SSO 轉移到課程系統');

      final baseUri = Uri.parse(baseUrl);
      final freshCookie = Cookie('JSESSIONID', _jsessionId!);
      await _cookieJar.saveFromResponse(baseUri, [freshCookie]);

      const serviceCode = 'aa_0010-oauth';
      final ssoUri = Uri.parse('$baseUrl/ssoIndex.do').replace(
        queryParameters: {'apOu': serviceCode},
      );
      
      final ssoResponse = await _dio.getUri(ssoUri);
      
      final htmlContent = ssoResponse.data?.toString() ?? '';
      if (htmlContent.isEmpty || htmlContent.length < 100) {
        print('[NTUT API] OAuth2 表單回應為空');
        return false;
      }

      final RegExp inputPattern = RegExp(r"<input[^>]*name='([^']+)'[^>]*value='([^']*)'");
      final Map<String, String> formData = {};
      
      for (final match in inputPattern.allMatches(htmlContent)) {
        final name = match.group(1);
        final value = match.group(2);
        if (name != null) {
          formData[name] = value ?? '';
        }
      }
      
      final actionMatch = RegExp(r"action='([^']+)'").firstMatch(htmlContent);
      if (actionMatch == null || formData.isEmpty) {
        print('[NTUT API] 無法解析 OAuth2 表單');
        return false;
      }
      
      final action = actionMatch.group(1)!;

      final oauth2Url = Uri.parse('$baseUrl/$action');
      final oauth2Response = await _dio.postUri(oauth2Url, data: formData);
      
      if (oauth2Response.statusCode != 302) {
        print('[NTUT API] OAuth2 授權失敗: ${oauth2Response.statusCode}');
        return false;
      }
      
      final locationHeader = oauth2Response.headers['location'];
      if (locationHeader == null || locationHeader.isEmpty) {
        print('[NTUT API] 未找到 OAuth2 重定向 URL');
        return false;
      }
      
      final redirectUrl = locationHeader.first;

      // Step 5: 訪問重定向 URL 以完成 SSO（禁用自動重定向避免 port 錯誤）
      final courseDio = Dio(BaseOptions(
        headers: {'User-Agent': userAgent},
        followRedirects: false,  // 關鍵：禁用自動重定向
        validateStatus: (status) => status! < 500,
      ));
      
      // 禁用系統代理（避免 port 重定向問題）
      (courseDio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
        client.findProxy = (uri) => 'DIRECT';
        return client;
      };
      
      courseDio.interceptors.add(CookieManager(_cookieJar));
      
      final redirectUri = Uri.parse(redirectUrl);
      final redirectResponse = await courseDio.getUri(redirectUri);
      
      final courseSystemUri = Uri.parse(courseBaseUrl);
      final courseCookies = await _cookieJar.loadForRequest(courseSystemUri);
      
      _courseJSessionId = null;
      for (final cookie in courseCookies) {
        if (cookie.name == 'JSESSIONID') {
          _courseJSessionId = cookie.value;
          print('[NTUT API] 成功獲取課程系統 JSESSIONID');
          break;
        }
      }
      
      if (_courseJSessionId == null) {
        print('[NTUT API] 未獲取到課程系統 JSESSIONID');
        return false;
      }

      return true;
    } catch (e) {
      print('[NTUT API] SSO 轉移失敗: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableSemesters() async {
    if (_jsessionId == null || _userIdentifier == null) {
      throw Exception('請先登入');
    }

    if (_courseJSessionId == null) {
      final success = await _transferToCourseSystem();
      if (!success) {
        throw Exception('SSO 轉移到課程系統失敗');
      }
    }

    try {
      print('[NTUT API] 獲取可用學年度列表');

      // 使用與 SSO 相同的 CookieManager 來自動管理 cookies
      final courseDio = Dio(BaseOptions(
        baseUrl: courseBaseUrl,
        headers: {'User-Agent': userAgent},
        validateStatus: (status) => status! < 500,
      ));
      
      // 禁用系統代理
      (courseDio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
        client.findProxy = (uri) => 'DIRECT';
        return client;
      };
      
      courseDio.interceptors.add(CookieManager(_cookieJar));

      // 訪問 Select.jsp 主頁面（format=-3 會返回學期列表）
      final response = await courseDio.get(
        '/course/tw/Select.jsp',
        queryParameters: {
          'code': _userIdentifier,
          'format': '-3',
        },
      );

      if (response.statusCode == 200) {
        final htmlContent = response.data.toString();
        
        try {
          final document = html_parser.parse(htmlContent);
          final List<Map<String, dynamic>> semesters = [];
          
          final tables = document.getElementsByTagName('table');
          if (tables.isEmpty) {
            return [];
          }
          
          final table = tables[0];
          final rows = table.getElementsByTagName('tr');
          
          for (int i = 1; i < rows.length; i++) {
            final row = rows[i];
            final links = row.getElementsByTagName('a');
            
            if (links.isEmpty) continue;
            
            final linkText = links[0].text.trim();
            final parts = linkText.split(' ');
            if (parts.length >= 4) {
              try {
                final year = int.parse(parts[0]);
                final semester = int.parse(parts[2]);
                
                semesters.add({
                  'year': year,
                  'semester': semester,
                });
              } catch (e) {
                debugPrint('[NTUT API] 解析學期失敗: $linkText, 錯誤: $e');
              }
            }
          }
          
          semesters.sort((a, b) {
            final yearCompare = (b['year'] as int).compareTo(a['year'] as int);
            if (yearCompare != 0) return yearCompare;
            return (b['semester'] as int).compareTo(a['semester'] as int);
          });
          
          print('[NTUT API] 找到 ${semesters.length} 個可用學期');
          return semesters;
        } catch (e) {
          print('[NTUT API] 解析 HTML 失敗: $e');
          return [];
        }
      }
      
      return [];
    } catch (e) {
      print('[NTUT API] 獲取可用學年度列表失敗: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCourseTableList() async {
    if (_jsessionId == null || _userIdentifier == null) {
      throw Exception('請先登入');
    }

    if (_courseJSessionId == null) {
      final success = await _transferToCourseSystem();
      if (!success) {
        throw Exception('SSO 轉移到課程系統失敗');
      }
    }

    try {

      final courseDio = Dio(BaseOptions(
        baseUrl: courseBaseUrl,
        headers: {'User-Agent': 'Direk Android App'},
      ));

      final response = await courseDio.post(
        '/course/tw/Select.jsp',
        data: {'code': _userIdentifier, 'format': '-3'},
        options: Options(
          headers: {
            'Cookie': 'JSESSIONID=$_courseJSessionId',  // 使用課程系統的 session
            'Referer': courseBaseUrl,
          },
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200) {
        return [];
      }
      return [];
    } catch (e) {
      print('[NTUT API] 獲取課表列表失敗: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCourseTable({
    required String year,
    required int semester,
  }) async {
    if (_jsessionId == null || _userIdentifier == null) {
      throw Exception('請先登入');
    }

    if (_courseJSessionId == null) {
      final success = await _transferToCourseSystem();
      if (!success) {
        throw Exception('SSO 轉移到課程系統失敗');
      }
    }

    try {
      print('[NTUT API] 獲取課表: $year-$semester');

      // 使用與 SSO 相同的 CookieManager 來自動管理 cookies
      final courseDio = Dio(BaseOptions(
        baseUrl: courseBaseUrl,
        headers: {'User-Agent': userAgent},
        validateStatus: (status) => status! < 500,
      ));
      
      // 禁用系統代理（避免 port 問題）
      (courseDio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
        client.findProxy = (uri) => 'DIRECT';
        return client;
      };
      
      courseDio.interceptors.add(CookieManager(_cookieJar));

      final response = await courseDio.get(
        '/course/tw/Select.jsp',
        queryParameters: {
          'format': '-2',
          'code': _userIdentifier,
          'year': year,
          'sem': semester.toString(),
        },
      );

      if (response.statusCode == 200) {
        final htmlContent = response.data.toString();
        
        if (htmlContent.contains('姓名')) {
          print('[NTUT API] 成功獲取課表 HTML');
          return _parseCourseTableHtml(htmlContent);
        } else {
          print('[NTUT API] HTML 不包含課表數據');
          return [];
        }
      }
      return [];
    } catch (e) {
      print('[NTUT API] 獲取課表失敗: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> _parseCourseTableHtml(String html) {
    try {
      final document = html_parser.parse(html);
      final courses = <Map<String, dynamic>>[];
      
      final tables = document.querySelectorAll('table');
      if (tables.length < 2) {
        return courses;
      }
      
      final courseTable = tables[1];
      final allRows = courseTable.querySelectorAll('tr');
      
      for (int i = 2; i < allRows.length - 1; i++) {
        final row = allRows[i];
        final cells = row.querySelectorAll('td');
        
        if (cells.length < 4) {
          continue;
        }
        
        try {
          final courseId = cells[0].text.trim();
          final courseName = cells[1].text.trim();
          final step = cells.length > 2 ? cells[2].text.trim() : '';
          final credits = cells.length > 3 ? cells[3].text.trim() : '0.0';
          final hours = cells.length > 4 ? cells[4].text.trim() : '0';
          final required = cells.length > 5 ? cells[5].text.trim() : '';
          final instructor = cells.length > 6 ? cells[6].text.trim() : '';
          final classGroup = cells.length > 7 ? cells[7].text.trim() : '';
          final classroom = cells.length > 15 ? cells[15].text.trim() : '';
          
          final scheduleMap = <String, String>{};
          if (cells.length > 14) {
            final days = ['日', '一', '二', '三', '四', '五', '六'];
            for (int d = 0; d < 7 && (8 + d) < cells.length; d++) {
              final timeSlot = cells[8 + d].text.trim();
              if (timeSlot.isNotEmpty) {
                scheduleMap[days[d]] = timeSlot;
              }
            }
          }
          
          String? syllabusNumber;
          String? teacherCode;
          
          for (final cell in cells) {
            final links = cell.querySelectorAll('a[href*="ShowSyllabus.jsp"]');
            if (links.isNotEmpty) {
              final href = links.first.attributes['href'];
              if (href != null) {
                final uri = Uri.parse(href);
                syllabusNumber = uri.queryParameters['snum'];
                teacherCode = uri.queryParameters['code'];
              }
              break;
            }
          }
          
          if (courseName.isEmpty) {
            continue;
          }
          
          final course = {
            'courseId': courseId.isEmpty ? 'NO_ID_${courseName.hashCode}' : courseId,
            'courseName': courseName,
            'step': step,
            'credits': double.tryParse(credits) ?? 0.0,
            'hours': int.tryParse(hours) ?? 0,
            'required': required,
            'instructor': instructor,
            'classGroup': classGroup,
            'classroom': classroom,
            'schedule': json.encode(scheduleMap),
            if (syllabusNumber != null) 'syllabusNumber': syllabusNumber,
            if (teacherCode != null) 'teacherCode': teacherCode,
          };
          
          courses.add(course);
          
        } catch (e) {
          debugPrint('[NTUT API] 解析第 $i 行時發生錯誤: $e');
        }
      }
      
      print('[NTUT API] 成功解析 ${courses.length} 門課程');
      return courses;
      
    } catch (e) {
      print('[NTUT API] 解析課表 HTML 失敗: $e');
      return [];
    }
  }

  void logout() {
    _jsessionId = null;
    _userIdentifier = null;
    print('[NTUT API] 已登出');
  }

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
      print('[NTUT API] 獲取系統樹失敗: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getGrades(String sessionId) async {
    try {
      print('[NTUT API] 獲取成績資料');
      
      final loginSuccess = await _loginToScoreSystem();
      if (!loginSuccess) {
        throw Exception('SSO 登入成績系統失敗');
      }
      
      final scoreDio = Dio(BaseOptions(
        baseUrl: 'https://aps-course.ntut.edu.tw',
        headers: {'User-Agent': userAgent},
        validateStatus: (status) => status! < 500,
      ));
      
      (scoreDio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
        client.findProxy = (uri) => 'DIRECT';
        return client;
      };
      
      scoreDio.interceptors.add(CookieManager(_cookieJar));
      
      final response = await scoreDio.get(
        '/StuQuery/QryScore.jsp',
        queryParameters: {'format': '-2'},
      );
      
      if (response.statusCode != 200) {
        throw Exception('獲取成績頁面失敗: ${response.statusCode}');
      }
      
      final htmlDoc = html_parser.parse(response.data);
      final grades = <Map<String, dynamic>>[];
      
      final titleNodes = htmlDoc.querySelectorAll('input[type=submit]');
      
      for (final titleNode in titleNodes) {
        final semesterText = titleNode.attributes['value'] ?? '';
        if (semesterText.isEmpty) continue;
        
        final semesterParts = semesterText.split(' ');
        if (semesterParts.length < 4) continue;
        
        final year = semesterParts[0];
        final semester = semesterParts[3];
        final semesterCode = '$year-$semester';
        
        final siblingOfTitle = titleNode.parent?.localName == 'form'
            ? titleNode.parent?.nextElementSibling
            : titleNode.nextElementSibling;
        
        if (siblingOfTitle == null || siblingOfTitle.localName != 'table') continue;
        
        final scoreRows = siblingOfTitle.querySelectorAll('tr');
        
        int scoreEnd = scoreRows.length - 5;
        for (int i = scoreRows.length - 1; i >= 0; i--) {
          final text = scoreRows[i].text.replaceAll(RegExp(r'[\n\s]'), '') ?? '';
          if (text.contains('ThisSemesterScore')) {
            scoreEnd = i;
            break;
          }
        }
        
        for (int j = 1; j < scoreEnd - 1 && j < scoreRows.length; j++) {
          final scoreRow = scoreRows[j];
          final cells = scoreRow.querySelectorAll('th');
          
          if (cells.length < 8) continue;
          
          try {
            final courseId = cells[0].text.replaceAll(RegExp(r'[\s\n]'), '');
            final courseName = cells[2].text.replaceAll(RegExp(r'[\s\n]'), '');
            final creditText = cells[6].text;
            final gradeText = cells[7].text.replaceAll(RegExp(r'[\s\n]'), '');
            
            final creditMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(creditText);
            final credits = creditMatch != null ? double.tryParse(creditMatch.group(1)!) : null;
            
            final gradePoint = _convertGradeToPoint(gradeText);
            final score = _convertGradeToScore(gradeText);
            
            grades.add({
              'semester': semesterCode,
              'courseId': courseId,
              'courseName': courseName,
              'credits': credits,
              'grade': gradeText,
              'gradePoint': gradePoint,
              'score': score,
              'semesterStats': {
                'semester': semesterCode,
              },
            });
          } catch (e) {
            debugPrint('[NTUT API] 解析第 $j 行成績失敗: $e');
            continue;
          }
        }
        
        try {
          if (scoreEnd >= 5 && scoreRows.length >= scoreEnd) {
            final averageRow = scoreRows[scoreRows.length - 5];
            final performanceRow = scoreRows[scoreRows.length - 4];
            final totalCreditRow = scoreRows[scoreRows.length - 3];
            final takeCreditRow = scoreRows[scoreRows.length - 2];
            
            final averageScore = double.tryParse(
              averageRow.querySelectorAll('td').isNotEmpty 
                  ? averageRow.querySelectorAll('td')[0].text.trim() 
                  : ''
            );
            final performanceScore = double.tryParse(
              performanceRow.querySelectorAll('td').isNotEmpty 
                  ? performanceRow.querySelectorAll('td')[0].text.trim() 
                  : ''
            );
            final totalCredit = double.tryParse(
              totalCreditRow.querySelectorAll('td').isNotEmpty 
                  ? totalCreditRow.querySelectorAll('td')[0].text.trim() 
                  : ''
            );
            final takeCredit = double.tryParse(
              takeCreditRow.querySelectorAll('td').isNotEmpty 
                  ? takeCreditRow.querySelectorAll('td')[0].text.trim() 
                  : ''
            );
            
            final semesterGrades = grades.where((g) => g['semester'] == semesterCode).toList();
            for (final grade in semesterGrades) {
              grade['semesterStats'] = {
                'semester': semesterCode,
                'averageScore': averageScore,
                'performanceScore': performanceScore,
                'totalCredits': totalCredit,
                'earnedCredits': takeCredit,
              };
            }
          }
        } catch (e) {
          debugPrint('[NTUT API] 解析學期 $semesterCode 統計失敗: $e');
        }
      }
      
      print('[NTUT API] 成功獲取 ${grades.length} 筆成績');
      return grades;
    } catch (e) {
      print('[NTUT API] 獲取成績失敗: $e');
      return [];
    }
  }
  
  /// 獲取排名資料
  Future<Map<String, Map<String, dynamic>>> getScoreRanks() async {
    try {
      print('[NTUT API] 獲取排名資料');
      
      // Step 1: 確保已登入成績系統
      final loginSuccess = await _loginToScoreSystem();
      if (!loginSuccess) {
        throw Exception('SSO 登入成績系統失敗');
      }
      
      // Step 2: 建立成績系統專用的 Dio
      final scoreDio = Dio(BaseOptions(
        baseUrl: 'https://aps-course.ntut.edu.tw',
        headers: {'User-Agent': userAgent},
        validateStatus: (status) => status! < 500,
      ));
      
      (scoreDio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
        client.findProxy = (uri) => 'DIRECT';
        return null;
      };
      
      scoreDio.interceptors.add(CookieManager(_cookieJar));
      
      // Step 3: 獲取排名頁面
      print('[NTUT API] 請求排名頁面...');
      final response = await scoreDio.get(
        '/StuQuery/QryRank.jsp',
        queryParameters: {'format': '-2'},
      );
      
      if (response.statusCode != 200) {
        throw Exception('獲取排名頁面失敗: ${response.statusCode}');
      }
      
      // Step 4: 解析 HTML
      final htmlDoc = html_parser.parse(response.data);
      final rankMap = <String, Map<String, dynamic>>{};
      
      final tbody = htmlDoc.querySelector('tbody');
      if (tbody == null) {
        print('[NTUT API] 找不到排名表格');
        return rankMap;
      }
      
      final rankRows = tbody.querySelectorAll('tr')
          .where((row) => row.querySelectorAll('td').length >= 7)
          .toList()
          .reversed
          .toList();
      
      // 存儲總排名
      Map<String, dynamic>? overallRank;
      
      // 每三行代表一個學期（系排名、班排名、學期資訊）
      for (int i = 0; i < (rankRows.length / 3).floor(); i++) {
        try {
          final semesterRow = rankRows[i * 3 + 2];
          final classRankRow = rankRows[i * 3 + 2];
          final deptRankRow = rankRows[i * 3];
          
          // 解析學期
          final semesterText = semesterRow.querySelectorAll('td')[0].innerHtml.split('<br>').first.trim();
          final semesterParts = semesterText.split(' ');
          if (semesterParts.length < 2) continue;
          
          final year = semesterParts[0];
          final semester = semesterParts.last;
          final semesterCode = '$year-$semester';
          
          // 解析班排名（當前學期）
          final classRankCells = classRankRow.querySelectorAll('td');
          final classRank = double.tryParse(classRankCells[2].text.trim());
          final classTotal = double.tryParse(classRankCells[3].text.trim());
          final classPercentage = double.tryParse(
            classRankCells[4].text.replaceAll(RegExp(r'[%|\s]'), '').trim()
          );
          
          // 解析系排名（當前學期）
          final deptRankCells = deptRankRow.querySelectorAll('td');
          final deptRank = double.tryParse(deptRankCells[1].text.trim());
          final deptTotal = double.tryParse(deptRankCells[2].text.trim());
          final deptPercentage = double.tryParse(
            deptRankCells[3].text.replaceAll(RegExp(r'[%|\s]'), '').trim()
          );
          
          // 解析歷年成績排名（總排名）- 從同一行的後面幾列
          if (classRankCells.length >= 8) {
            final overallClassRank = double.tryParse(classRankCells[5].text.trim());
            final overallClassTotal = double.tryParse(classRankCells[6].text.trim());
            final overallDeptRank = double.tryParse(deptRankCells[4].text.trim());
            final overallDeptTotal = double.tryParse(deptRankCells[5].text.trim());
            
            // 只在最後一個學期（最新）保存總排名
            if (i == (rankRows.length / 3).floor() - 1) {
              overallRank = {
                'classRank': overallClassRank != null && overallClassTotal != null
                    ? {'rank': overallClassRank, 'total': overallClassTotal}
                    : null,
                'departmentRank': overallDeptRank != null && overallDeptTotal != null
                    ? {'rank': overallDeptRank, 'total': overallDeptTotal}
                    : null,
              };
            }
          }
          
          rankMap[semesterCode] = {
            'classRank': classRank != null && classTotal != null
                ? {'rank': classRank, 'total': classTotal, 'percentage': classPercentage}
                : null,
            'departmentRank': deptRank != null && deptTotal != null
                ? {'rank': deptRank, 'total': deptTotal, 'percentage': deptPercentage}
                : null,
          };
        } catch (e) {
          print('[NTUT API] 解析第 $i 個排名失敗: $e');
          continue;
        }
      }
      
      // 添加總排名到結果中
      if (overallRank != null) {
        rankMap['_overall'] = overallRank;
      }
      
      print('[NTUT API] 成功獲取 ${rankMap.length} 個學期的排名（含總排名）');
      return rankMap;
    } catch (e) {
      print('[NTUT API] 獲取排名失敗: $e');
      return {};
    }
  }
  
  /// SSO 登入到成績系統（依照 TAT-Core 的實作方式）
  Future<bool> _loginToScoreSystem() async {
    try {
      print('[NTUT API] 開始 SSO 登入到成績系統...');
      
      // 檢查是否已登入
      if (!isLoggedIn) {
        throw Exception('尚未登入 NTUT 系統，請先登入');
      }
      
      // Step 1: 請求 SSO index 頁面（使用 GET，參考 TAT）
      const ssoIndexUrl = '$baseUrl/ssoIndex.do';
      debugPrint('[NTUT API] Step 1: 請求 SSO index 頁面...');
      final ssoIndexResponse = await _dio.get(
        ssoIndexUrl,
        queryParameters: {
          'apOu': 'aa_003_LB_oauth',
          'datetime1': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      
      if (ssoIndexResponse.statusCode != 200) {
        throw Exception('SSO index 請求失敗: ${ssoIndexResponse.statusCode}');
      }
      
      // Step 2: 解析 OAuth2 表單
      debugPrint('[NTUT API] Step 2: 解析 OAuth2 表單...');
      debugPrint('[NTUT API] Response data type: ${ssoIndexResponse.data.runtimeType}');
      
      // 確保 data 是字串
      String htmlContent;
      if (ssoIndexResponse.data is String) {
        htmlContent = ssoIndexResponse.data as String;
      } else {
        htmlContent = ssoIndexResponse.data.toString();
      }
      
      debugPrint('[NTUT API] HTML 內容長度: ${htmlContent.length} bytes');
      debugPrint('[NTUT API] HTML 內容前 200 字元: ${htmlContent.substring(0, htmlContent.length > 200 ? 200 : htmlContent.length)}');
      
      final htmlDoc = html_parser.parse(htmlContent);
      final inputNodes = htmlDoc.querySelectorAll('input');
      final formNodes = htmlDoc.querySelectorAll('form');
      
      debugPrint('[NTUT API] 找到 ${formNodes.length} 個 form 標籤');
      debugPrint('[NTUT API] 找到 ${inputNodes.length} 個 input 標籤');
      
      if (formNodes.isEmpty) {
        print('[NTUT API] HTML 內容: $htmlContent');
        throw Exception('找不到 OAuth2 表單');
      }
      
      final formNode = formNodes.first;
      final jumpUrl = formNode.attributes['action'];
      if (jumpUrl == null || jumpUrl.isEmpty) {
        throw Exception('找不到跳轉 URL');
      }
      
      // 收集表單數據
      final oauthData = <String, String>{};
      for (final input in inputNodes) {
        final name = input.attributes['name'];
        final value = input.attributes['value'];
        if (name != null && value != null) {
          oauthData[name] = value;
        }
      }
      
      debugPrint('[NTUT API] OAuth 表單數據: ${oauthData.keys.join(", ")}');
      debugPrint('[NTUT API] 跳轉 URL: $jumpUrl');
      
      // Step 3: POST 提交 OAuth2 表單（重試最多 3 次，參考 TAT）
      String fullJumpUrl;
      if (jumpUrl.startsWith('http')) {
        fullJumpUrl = jumpUrl;
      } else if (jumpUrl.startsWith('/')) {
        fullJumpUrl = '$baseUrl$jumpUrl';
      } else {
        fullJumpUrl = '$baseUrl/$jumpUrl';
      }
      debugPrint('[NTUT API] Step 3: POST 提交 OAuth2 表單到: $fullJumpUrl');
      
      for (int retry = 0; retry < 3; retry++) {
        try {
          final jumpResponse = await _dio.post(
            fullJumpUrl,
            data: oauthData,
            options: Options(
              followRedirects: false,
              validateStatus: (status) => status! < 500,
              contentType: Headers.formUrlEncodedContentType,
            ),
          );
          
          debugPrint('[NTUT API] Jump response status: ${jumpResponse.statusCode}');
          
          // 期望得到 302 重定向
          if (jumpResponse.statusCode != 302) {
            print('[NTUT API] 未收到預期的 302 重定向，狀態碼: ${jumpResponse.statusCode}，重試 ${retry + 1}/3');
            await Future.delayed(const Duration(milliseconds: 100));
            continue;
          }
          
          // Step 4: 跟隨重定向到成績系統
          final location = jumpResponse.headers.value('location');
          if (location == null) {
            print('[NTUT API] 302 響應中找不到 location header，重試 ${retry + 1}/3');
            await Future.delayed(const Duration(milliseconds: 100));
            continue;
          }
          
          debugPrint('[NTUT API] Step 4: 跟隨重定向到: $location');
          
          final finalResponse = await _dio.post(
            location,
            options: Options(
              followRedirects: true,
              validateStatus: (status) => status! < 500,
            ),
          );
          
          // 檢查是否連線中斷
          final responseText = finalResponse.data.toString();
          if (responseText.contains('中斷連線')) {
            print('[NTUT API] 連線中斷，重試 ${retry + 1}/3');
            await Future.delayed(const Duration(milliseconds: 100));
            continue;
          }
          
          print('[NTUT API] SSO 登入成績系統成功');
          return true;
        } catch (e) {
          print('[NTUT API] 第 ${retry + 1} 次嘗試失敗: $e');
          if (retry == 2) rethrow;
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      print('[NTUT API] SSO 登入流程重試 3 次後仍失敗');
      return false;
    } catch (e, stack) {
      print('[NTUT API] SSO 登入成績系統失敗: $e');
      print('[NTUT API] Stack trace: $stack');
      return false;
    }
  }
  
  /// 將成績文字轉換為績分
  double? _convertGradeToPoint(String grade) {
    final gradeMap = {
      'A+': 4.3, 'A': 4.0, 'A-': 3.7,
      'B+': 3.3, 'B': 3.0, 'B-': 2.7,
      'C+': 2.3, 'C': 2.0, 'C-': 1.7,
      'D': 1.0, 'F': 0.0, 'X': 0.0,
    };
    return gradeMap[grade.toUpperCase()];
  }

  /// 將成績轉換為 0-100 分數（支持數字和等第）
  double? _convertGradeToScore(String grade) {
    if (grade.isEmpty) return null;
    
    // 先嘗試直接解析為數字
    final numericScore = double.tryParse(grade);
    if (numericScore != null) {
      return numericScore;
    }
    
    // 如果不是數字，則使用等第對應表
    final scoreMap = {
      'A+': 95.0, 'A': 90.0, 'A-': 85.0,
      'B+': 82.0, 'B': 78.0, 'B-': 75.0,
      'C+': 72.0, 'C': 68.0, 'C-': 65.0,
      'D': 60.0, 'F': 50.0, 'X': 0.0,
    };
    final result = scoreMap[grade.toUpperCase()];
    
    if (result == null) {
      print('[NTUT API] 無法轉換成績: "$grade"');
    }
    
    return result;
  }

  /// 獲取課程大綱
  /// 
  /// 參數：
  /// - [syllabusNumber]: 課程大綱編號（snum）
  /// - [teacherCode]: 教師代碼（code）
  /// 
  /// 返回課程大綱資訊，包含：
  /// - courseName: 課程名稱
  /// - courseId: 課號
  /// - credits: 學分
  /// - instructor: 教師
  /// - department: 開課系所
  /// - objective: 教學目標
  /// - outline: 課程大綱
  /// - textbooks: 老師聯絡資訊
  /// - gradingCriteria: 成績評定
  /// - schedule: 評量標準/評分規則
  Future<Map<String, dynamic>?> getCourseSyllabus({
    required String syllabusNumber,
    required String teacherCode,
  }) async {
    try {
      print('[NTUT API] 獲取課程大綱: snum=$syllabusNumber, code=$teacherCode');
      
      // 如果沒有課程系統的 session，先進行 SSO 轉移
      if (_courseJSessionId == null) {
        print('[NTUT API] 尚未取得課程系統 session，開始 SSO 轉移...');
        final success = await _transferToCourseSystem();
        if (!success) {
          throw Exception('SSO 轉移到課程系統失敗');
        }
      }
      
      // 創建專用的 Dio 實例
      final courseDio = Dio(BaseOptions(
        baseUrl: courseBaseUrl,
        headers: {'User-Agent': userAgent},
        validateStatus: (status) => status! < 500,
      ));
      
      // 禁用系統代理
      (courseDio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
        client.findProxy = (uri) => 'DIRECT';
        return client;
      };
      
      // 使用 CookieManager
      courseDio.interceptors.add(CookieManager(_cookieJar));
      
      // 請求課程大綱頁面
      final response = await courseDio.get(
        '/course/tw/ShowSyllabus.jsp',
        queryParameters: {
          'snum': syllabusNumber,
          'code': teacherCode,
        },
      );
      
      if (response.statusCode == 200) {
        final htmlContent = response.data.toString();
        debugPrint('[NTUT API] 課程大綱 HTML 長度: ${htmlContent.length} bytes');
        
        return _parseCourseSyllabusHtml(htmlContent);
      } else {
        print('[NTUT API] 獲取課程大綱失敗: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[NTUT API] 獲取課程大綱異常: $e');
      return null;
    }
  }
  
  /// 解析課程大綱 HTML
  Map<String, dynamic> _parseCourseSyllabusHtml(String html) {
    try {
      final document = html_parser.parse(html);
      final result = <String, dynamic>{};
      
      // 解析標題（課程名稱）
      final titleElement = document.querySelector('h2');
      if (titleElement != null) {
        result['courseName'] = titleElement.text.trim();
      }
      
      // 解析表格資料
      final tables = document.querySelectorAll('table');
      
      if (tables.isNotEmpty) {
        // 第一個表格：基本資訊
        final basicInfoTable = tables[0];
        final rows = basicInfoTable.querySelectorAll('tr');
        
        for (final row in rows) {
          final cells = row.querySelectorAll('td');
          if (cells.length >= 2) {
            final label = cells[0].text.trim().replaceAll('：', '').replaceAll(':', '');
            final value = cells[1].text.trim();
            
            switch (label) {
              case '課號':
              case '科目代碼':
                result['courseId'] = value;
                break;
              case '學分':
                result['credits'] = value;
                break;
              case '教師':
              case '授課教師':
                result['instructor'] = value;
                break;
              case '開課系所':
              case '系所':
                result['department'] = value;
                break;
              case '修別':
                result['required'] = value;
                break;
              case '上課時間':
                result['classTime'] = value;
                break;
              case '上課教室':
                result['classroom'] = value;
                break;
            }
          }
        }
      }
      
      // 解析詳細內容區塊
      final contentTables = tables.length > 1 ? tables.sublist(1) : <html_dom.Element>[];
      
      for (final table in contentTables) {
        final rows = table.querySelectorAll('tr');
        
        for (int i = 0; i < rows.length; i++) {
          final row = rows[i];
          final headerCell = row.querySelector('th');
          
          if (headerCell != null) {
            final sectionTitle = headerCell.text.trim();
            
            // 嘗試獲取下一行的內容
            String content = '';
            if (i + 1 < rows.length) {
              final contentRow = rows[i + 1];
              final contentCell = contentRow.querySelector('td');
              if (contentCell != null) {
                content = contentCell.text.trim();
              }
            }
            
            if (sectionTitle.contains('教學目標') || sectionTitle.contains('目標')) {
              result['objective'] = content;
            } else if (sectionTitle.contains('課程大綱') || sectionTitle.contains('大綱')) {
              result['outline'] = content;
            } else if (sectionTitle.contains('教科書') || sectionTitle.contains('教材')) {
              result['textbooks'] = content;
            } else if (sectionTitle.contains('參考書目') || sectionTitle.contains('參考資料')) {
              result['references'] = content;
            } else if (sectionTitle.contains('成績評定') || sectionTitle.contains('評分標準')) {
              result['gradingCriteria'] = content;
            } else if (sectionTitle.contains('課程進度') || sectionTitle.contains('進度')) {
              result['schedule'] = content;
            }
          }
        }
      }
      
      print('成功解析課程大綱: ${result['courseName']}');
      return result;
      
    } catch (e) {
      print('[NTUT API] 解析課程大綱 HTML 失敗: $e');
      return {};
    }
  }

  // ==================== Course Search API (使用 qaq_backend) ====================

  // 從環境變數讀取後端 URL，如果沒有則使用預設值
  // 使用 Cloudflare Workers 部署的 API
  static String get backendUrl {
    final baseUrl = dotenv.env['BACKEND_URL'] ?? 'https://qaq-api-v2.ntut.org/api';
    return '$baseUrl/courses';
  }

  /// 搜尋課程
  /// [keyword] 關鍵字（課程名稱、教師、課號）
  /// [year] 學年度
  /// [semester] 學期
  /// [category] 博雅類別
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
      print('[NTUT API] 搜尋課程: keyword=$keyword, year=$year, semester=$semester, college=$college');

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
        '$backendUrl/search',
        queryParameters: queryParams,
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> courses = response.data['data'] ?? [];
        print('[NTUT API] 找到 ${courses.length} 筆課程');
        return courses.cast<Map<String, dynamic>>();
      } else {
        print('[NTUT API] 搜尋課程失敗: ${response.data}');
        return [];
      }
    } catch (e) {
      print('[NTUT API] 搜尋課程錯誤: $e');
      return [];
    }
  }

  /// 取得學院/系所/班級結構
  Future<Map<String, dynamic>?> getColleges({
    String year = '114',
    String semester = '1',
  }) async {
    try {
      print('[NTUT API] 取得學院結構: year=$year, semester=$semester');

      final response = await _dio.get(
        '$backendUrl/colleges',
        queryParameters: {
          'year': year,
          'semester': semester,
        },
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('[NTUT API] 成功取得學院結構');
        return response.data['data'];
      } else {
        print('[NTUT API] 取得學院結構失敗: ${response.data}');
        return null;
      }
    } catch (e) {
      print('[NTUT API] 取得學院結構錯誤: $e');
      return null;
    }
  }

  /// 根據班級代碼查詢課程
  Future<List<Map<String, dynamic>>> getCoursesByGrade({
    required String gradeCode,
    String year = '114',
    String semester = '1',
  }) async {
    try {
      print('[NTUT API] 查詢班級課程: gradeCode=$gradeCode, year=$year, semester=$semester');

      final response = await _dio.get(
        '$backendUrl/by-grade',
        queryParameters: {
          'gradeCode': gradeCode,
          'year': year,
          'semester': semester,
        },
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> courses = response.data['data'] ?? [];
        print('[NTUT API] 找到 ${courses.length} 筆班級課程');
        return courses.cast<Map<String, dynamic>>();
      } else {
        print('[NTUT API] 查詢班級課程失敗: ${response.data}');
        return [];
      }
    } catch (e) {
      print('[NTUT API] 查詢班級課程錯誤: $e');
      return [];
    }
  }

  /// 取得學程/微學程列表
  Future<Map<String, dynamic>?> getPrograms({
    String year = '114',
    String semester = '1',
  }) async {
    try {
      print('[NTUT API] 取得學程列表: year=$year, semester=$semester');

      final response = await _dio.get(
        '$backendUrl/programs',
        queryParameters: {
          'year': year,
          'semester': semester,
        },
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        print('[NTUT API] 成功取得學程列表');
        return response.data['data'];
      } else {
        print('[NTUT API] 取得學程列表失敗: ${response.data}');
        return null;
      }
    } catch (e) {
      print('[NTUT API] 取得學程列表錯誤: $e');
      return null;
    }
  }

  /// 根據學程代碼查詢課程
  Future<List<Map<String, dynamic>>> getCoursesByProgram({
    required String programCode,
    String type = 'micro-program',
    String year = '114',
    String semester = '1',
  }) async {
    try {
      print('[NTUT API] 查詢學程課程: programCode=$programCode, type=$type, year=$year, semester=$semester');

      final response = await _dio.get(
        '$backendUrl/by-program',
        queryParameters: {
          'programCode': programCode,
          'type': type,
          'year': year,
          'semester': semester,
        },
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> courses = response.data['data'] ?? [];
        print('[NTUT API] 找到 ${courses.length} 筆學程課程');
        return courses.cast<Map<String, dynamic>>();
      } else {
        print('[NTUT API] 查詢學程課程失敗: ${response.data}');
        return [];
      }
    } catch (e) {
      print('[NTUT API] 查詢學程課程錯誤: $e');
      return [];
    }
  }

  /// 取得課程詳細資料（包含評分標準等大綱資訊）
  Future<Map<String, dynamic>?> getCourseDetail(
    String courseId, {
    String year = '114',
    String semester = '1',
  }) async {
    try {
      print('[NTUT API] 查詢課程詳細資料: courseId=$courseId, year=$year, semester=$semester');

      final response = await _dio.get(
        '$backendUrl/detail/$courseId',
        queryParameters: {
          'year': year,
          'semester': semester,
        },
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        print('[NTUT API] 成功取得課程 $courseId 的詳細資料');
        return response.data;
      } else if (response.statusCode == 404) {
        print('[NTUT API] 課程 $courseId 沒有詳細資料');
        return null;
      } else {
        print('[NTUT API] 查詢課程詳細資料失敗: ${response.data}');
        return null;
      }
    } catch (e) {
      print('[NTUT API] 查詢課程詳細資料錯誤: $e');
      return null;
    }
  }

  /// 通用的校務系統 SSO 登入方法
  /// 參數 serviceCode 為校務系統代碼（如 AdminSystemCodes 中定義的代碼）
  /// 返回系統的 URL，可用於 WebView 訪問
  Future<String?> getAdminSystemUrl(String serviceCode) async {
    if (_jsessionId == null || _userIdentifier == null) {
      throw Exception('請先登入');
    }

    try {
      print('[NTUT API] 開始 SSO 轉移到校務系統: $serviceCode');

      // Step 1: 確保 JSESSIONID 在 CookieJar 中
      final baseUri = Uri.parse(baseUrl);
      final freshCookie = Cookie('JSESSIONID', _jsessionId!);
      await _cookieJar.saveFromResponse(baseUri, [freshCookie]);
      debugPrint('[NTUT API] 已重新儲存 JSESSIONID');

      // Step 2: 請求 SSO 授權（獲取轉移資訊）
      final ssoUri = Uri.parse('$baseUrl/ssoIndex.do').replace(
        queryParameters: {'apOu': serviceCode},
      );
      
      debugPrint('[NTUT API] 請求 SSO 授權: $ssoUri');
      final ssoResponse = await _dio.getUri(ssoUri);
      
      final htmlContent = ssoResponse.data?.toString() ?? '';
      if (htmlContent.isEmpty || htmlContent.length < 100) {
        print('[NTUT API] SSO 授權回應為空');
        return null;
      }
      
      debugPrint('[NTUT API] 成功獲取 SSO 授權表單 (${htmlContent.length} bytes)');

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
        print('[NTUT API] 無法解析 SSO 表單');
        return null;
      }
      
      final action = actionMatch.group(1)!;
      debugPrint('[NTUT API] SSO 表單參數: ${formData.keys.join(", ")}');
      debugPrint('[NTUT API] Form action: $action');

      // Step 4: 提交表單
      final submitUrl = action.startsWith('http') 
          ? Uri.parse(action) 
          : Uri.parse('$baseUrl/$action');
      
      debugPrint('[NTUT API] 提交 SSO 表單到: $submitUrl');
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
          print('[NTUT API] SSO 成功，系統 URL: $redirectUrl');
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
          print('[NTUT API] SSO 成功，從 JavaScript 提取 URL: $targetUrl');
          return targetUrl;
        }
        
        // 返回提交的 URL（某些系統不需要重定向）
        print('[NTUT API] SSO 成功，使用提交 URL');
        return submitUrl.toString();
      }
      
      print('[NTUT API] SSO 轉移失敗: ${submitResponse.statusCode}');
      return null;
    } catch (e) {
      print('[NTUT API] 校務系統 SSO 失敗: $e');
      return null;
    }
  }

  /// 取得校務系統主頁的系統樹狀結構
  /// 用於顯示所有可用的系統分類和連結
  Future<Map<String, dynamic>?> getAdminSystemTree({String? apDn}) async {
    print('[NTUT API] [getAdminSystemTree] 開始');
    print('[NTUT API] [getAdminSystemTree] _jsessionId: ${_jsessionId != null ? "存在" : "null"}');
    print('[NTUT API] [getAdminSystemTree] _userIdentifier: $_userIdentifier');
    print('[NTUT API] [getAdminSystemTree] apDn: $apDn');
    
    if (_jsessionId == null || _userIdentifier == null) {
      print('[NTUT API] [getAdminSystemTree] 未登入！');
      throw Exception('請先登入');
    }

    try {
      final data = apDn != null ? {'apDn': apDn} : null;
      print('[NTUT API] [getAdminSystemTree] 發送請求到 /aptreeList.do, data: $data');
      
      final response = await _dio.post(
        '/aptreeList.do',
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      ).timeout(const Duration(seconds: 10));

      print('[NTUT API] [getAdminSystemTree] 回應狀態碼: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseText = response.data.toString();
        debugPrint('[NTUT API] [getAdminSystemTree] 回應長度: ${responseText.length} bytes');
        debugPrint('[NTUT API] [getAdminSystemTree] 回應前 200 字元: ${responseText.substring(0, responseText.length > 200 ? 200 : responseText.length)}');
        
        final result = json.decode(responseText);
        print('[NTUT API] [getAdminSystemTree] 成功解析 JSON');
        
        if (result is Map<String, dynamic>) {
          print('[NTUT API] [getAdminSystemTree] 返回的是 Map，包含 ${result.keys.length} 個 key: ${result.keys.join(", ")}');
          if (result.containsKey('apList')) {
            final apList = result['apList'];
            if (apList is List) {
              print('[NTUT API] [getAdminSystemTree] apList 包含 ${apList.length} 個項目');
            }
          }
        }
        
        return result;
      } else {
        print('[NTUT API] [getAdminSystemTree] HTTP 狀態碼錯誤: ${response.statusCode}');
        print('[NTUT API] [getAdminSystemTree] 回應內容: ${response.data}');
        return null;
      }
    } catch (e, stackTrace) {
      print('[NTUT API] [getAdminSystemTree] 錯誤: $e');
      print('[NTUT API] [getAdminSystemTree] StackTrace: $stackTrace');
      return null;
    }
  }
}



