import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'ntut_auth_service.dart';

/// NTUT 課程服務
/// 處理課表查詢、可用學期、課程大綱等功能
class NtutCourseService {
  final NtutAuthService _authService;
  late final Dio _dio;
  late final CookieJar _cookieJar;

  static const String courseBaseUrl = 'https://aps.ntut.edu.tw';
  static const String userAgent = 'Direk ios App';

  String? _courseJSessionId;

  NtutCourseService({required NtutAuthService authService})
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

  /// SSO 轉移到課程系統
  Future<bool> _transferToCourseSystem() async {
    if (!_authService.isLoggedIn) {
      throw Exception('請先登入');
    }

    try {
      print('[NTUT Course] 開始 SSO 轉移到課程系統');

      final baseUri = Uri.parse(NtutAuthService.baseUrl);
      final freshCookie = Cookie('JSESSIONID', _authService.jsessionId!);
      await _cookieJar.saveFromResponse(baseUri, [freshCookie]);

      const serviceCode = 'aa_0010-oauth';
      final ssoUri = Uri.parse('${NtutAuthService.baseUrl}/ssoIndex.do').replace(
        queryParameters: {'apOu': serviceCode},
      );
      
      final ssoResponse = await _dio.getUri(ssoUri);
      
      final htmlContent = ssoResponse.data?.toString() ?? '';
      if (htmlContent.isEmpty || htmlContent.length < 100) {
        print('[NTUT Course] OAuth2 表單回應為空');
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
        print('[NTUT Course] 無法解析 OAuth2 表單');
        return false;
      }
      
      final action = actionMatch.group(1)!;

      final oauth2Url = Uri.parse('${NtutAuthService.baseUrl}/$action');
      final oauth2Response = await _dio.postUri(oauth2Url, data: formData);
      
      if (oauth2Response.statusCode != 302) {
        print('[NTUT Course] OAuth2 授權失敗: ${oauth2Response.statusCode}');
        return false;
      }
      
      final locationHeader = oauth2Response.headers['location'];
      if (locationHeader == null || locationHeader.isEmpty) {
        print('[NTUT Course] 未找到 OAuth2 重定向 URL');
        return false;
      }
      
      final redirectUrl = locationHeader.first;

      // 訪問重定向 URL 以完成 SSO（禁用自動重定向避免 port 錯誤）
      final courseDio = Dio(BaseOptions(
        headers: {'User-Agent': userAgent},
        followRedirects: false,
        validateStatus: (status) => status! < 500,
      ));
      
      // 禁用系統代理（避免 port 重定向問題）
      (courseDio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
        client.findProxy = (uri) => 'DIRECT';
        return client;
      };
      
      courseDio.interceptors.add(CookieManager(_cookieJar));
      
      final redirectUri = Uri.parse(redirectUrl);
      await courseDio.getUri(redirectUri);
      
      final courseSystemUri = Uri.parse(courseBaseUrl);
      final courseCookies = await _cookieJar.loadForRequest(courseSystemUri);
      
      _courseJSessionId = null;
      for (final cookie in courseCookies) {
        if (cookie.name == 'JSESSIONID') {
          _courseJSessionId = cookie.value;
          print('[NTUT Course] 成功獲取課程系統 JSESSIONID');
          break;
        }
      }
      
      if (_courseJSessionId == null) {
        print('[NTUT Course] 未獲取到課程系統 JSESSIONID');
        return false;
      }

      return true;
    } catch (e) {
      print('[NTUT Course] SSO 轉移失敗: $e');
      return false;
    }
  }

  /// 取得可用學期列表
  Future<List<Map<String, dynamic>>> getAvailableSemesters() async {
    if (!_authService.isLoggedIn) {
      throw Exception('請先登入');
    }

    // 確保已轉移到課程系統
    if (_courseJSessionId == null) {
      print('[NTUT Course] 尚未轉移到課程系統，開始轉移');
      final success = await _transferToCourseSystem();
      if (!success) {
        throw Exception('SSO 轉移到課程系統失敗');
      }
    }

    try {
      print('[NTUT Course] 獲取可用學年度列表');

      final courseDio = Dio(BaseOptions(
        baseUrl: courseBaseUrl,
        headers: {'User-Agent': userAgent},
        validateStatus: (status) => status! < 500,
      ));
      
      (courseDio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
        client.findProxy = (uri) => 'DIRECT';
        return client;
      };
      
      courseDio.interceptors.add(CookieManager(_cookieJar));

      final response = await courseDio.get(
        '/course/tw/Select.jsp',
        queryParameters: {
          'code': _authService.userIdentifier,
          'format': '-3',
        },
      );

      if (response.statusCode == 200) {
        final htmlContent = response.data.toString();
        
        if (htmlContent.contains('帳號') && htmlContent.contains('密碼')) {
          throw Exception('Session 已失效，請重新登入');
        }
        
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
                debugPrint('[NTUT Course] 解析學期失敗: $linkText, 錯誤: $e');
              }
            }
          }
          
          semesters.sort((a, b) {
            final yearCompare = (b['year'] as int).compareTo(a['year'] as int);
            if (yearCompare != 0) return yearCompare;
            return (b['semester'] as int).compareTo(a['semester'] as int);
          });
          
          print('[NTUT Course] 找到 ${semesters.length} 個可用學期');
          return semesters;
        } catch (e) {
          print('[NTUT Course] 解析 HTML 失敗: $e');
          return [];
        }
      }
      
      return [];
    } catch (e) {
      print('[NTUT Course] 獲取可用學年度列表失敗: $e');
      rethrow;
    }
  }

  /// 取得課表
  /// 
  /// [year] 學年度
  /// [semester] 學期
  Future<List<Map<String, dynamic>>> getCourseTable({
    required String year,
    required int semester,
  }) async {
    if (!_authService.isLoggedIn) {
      throw Exception('請先登入');
    }

    if (_courseJSessionId == null) {
      final success = await _transferToCourseSystem();
      if (!success) {
        throw Exception('SSO 轉移到課程系統失敗');
      }
    }

    try {
      print('[NTUT Course] 獲取課表: $year-$semester');

      final courseDio = Dio(BaseOptions(
        baseUrl: courseBaseUrl,
        headers: {'User-Agent': userAgent},
        validateStatus: (status) => status! < 500,
      ));
      
      (courseDio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
        client.findProxy = (uri) => 'DIRECT';
        return client;
      };
      
      courseDio.interceptors.add(CookieManager(_cookieJar));

      final response = await courseDio.get(
        '/course/tw/Select.jsp',
        queryParameters: {
          'format': '-2',
          'code': _authService.userIdentifier,
          'year': year,
          'sem': semester.toString(),
        },
      );

      if (response.statusCode == 200) {
        final htmlContent = response.data.toString();
        
        if (htmlContent.contains('帳號') && htmlContent.contains('密碼')) {
          throw Exception('Session 已失效，請重新登入');
        }
        
        if (htmlContent.contains('姓名')) {
          final courses = _parseCourseTableHtml(htmlContent);
          print('[NTUT Course] 成功解析 ${courses.length} 門課程');
          return courses;
        }
      }
      return [];
    } catch (e) {
      print('[NTUT Course] 獲取課表失敗: $e');
      rethrow;
    }
  }

  /// 解析課表 HTML
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
          debugPrint('[NTUT Course] 解析第 $i 行時發生錯誤: $e');
        }
      }
      
      return courses;
      
    } catch (e) {
      print('[NTUT Course] 解析課表 HTML 失敗: $e');
      return [];
    }
  }

  /// 取得課程大綱
  /// 
  /// [syllabusNumber] 課程大綱編號
  /// [teacherCode] 教師代碼
  Future<Map<String, dynamic>?> getCourseSyllabus({
    required String syllabusNumber,
    required String teacherCode,
  }) async {
    try {
      print('[NTUT Course] 獲取課程大綱: snum=$syllabusNumber, code=$teacherCode');
      
      if (_courseJSessionId == null) {
        final success = await _transferToCourseSystem();
        if (!success) {
          throw Exception('SSO 轉移到課程系統失敗');
        }
      }
      
      final courseDio = Dio(BaseOptions(
        baseUrl: courseBaseUrl,
        headers: {'User-Agent': userAgent},
        validateStatus: (status) => status! < 500,
      ));
      
      (courseDio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
        client.findProxy = (uri) => 'DIRECT';
        return client;
      };
      
      courseDio.interceptors.add(CookieManager(_cookieJar));
      
      final response = await courseDio.get(
        '/course/tw/ShowSyllabus.jsp',
        queryParameters: {
          'snum': syllabusNumber,
          'code': teacherCode,
        },
      );
      
      if (response.statusCode == 200) {
        final htmlContent = response.data.toString();
        return _parseCourseSyllabusHtml(htmlContent);
      }
      return null;
    } catch (e) {
      print('[NTUT Course] 獲取課程大綱異常: $e');
      return null;
    }
  }

  /// 解析課程大綱 HTML
  Map<String, dynamic> _parseCourseSyllabusHtml(String html) {
    try {
      final document = html_parser.parse(html);
      final result = <String, dynamic>{};
      
      final titleElement = document.querySelector('h2');
      if (titleElement != null) {
        result['courseName'] = titleElement.text.trim();
      }
      
      final tables = document.querySelectorAll('table');
      
      if (tables.isNotEmpty) {
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
      
      final contentTables = tables.length > 1 ? tables.sublist(1) : [];
      
      for (final table in contentTables) {
        final rows = table.querySelectorAll('tr');
        
        for (int i = 0; i < rows.length; i++) {
          final row = rows[i];
          final headerCell = row.querySelector('th');
          
          if (headerCell != null) {
            final sectionTitle = headerCell.text.trim();
            
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
      
      return result;
      
    } catch (e) {
      print('[NTUT Course] 解析課程大綱 HTML 失敗: $e');
      return {};
    }
  }

  // ===== 課程標準與畢業學分相關 API（公開 API，無需登入）=====

  static const String _creditUrl = "https://aps.ntut.edu.tw/course/tw/Cprog.jsp";

  /// 獲取所有學年度列表（用於查詢課程標準）
  /// 不需要登入
  Future<List<String>> getYearList() async {
    try {
      final response = await _dio.post(
        _creditUrl,
        data: {"format": "-1"},
      );
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      
      final document = html_parser.parse(response.data);
      final nodes = document.getElementsByTagName("a");
      final resultList = <String>[];
      
      for (final node in nodes) {
        resultList.add(node.text);
      }
      
      return resultList;
    } catch (e) {
      debugPrint('[NTUT Course] getYearList error: $e');
      rethrow;
    }
  }

  /// 獲取學制列表（用於查詢課程標準）
  /// 返回 List<Map> 包含 name 和 code
  /// 不需要登入
  Future<List<Map<String, dynamic>>> getDivisionList(String year) async {
    try {
      final response = await _dio.post(
        _creditUrl,
        data: {"format": "-2", "year": year},
      );
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      
      final document = html_parser.parse(response.data);
      final nodes = document.getElementsByTagName("a");
      final resultList = <Map<String, dynamic>>[];
      
      for (final node in nodes) {
        final href = node.attributes["href"];
        if (href == null) continue;
        
        final code = Uri.parse(href).queryParameters;
        resultList.add({
          "name": node.text,
          "code": code,
        });
      }
      
      return resultList;
    } catch (e) {
      debugPrint('[NTUT Course] getDivisionList error: $e');
      rethrow;
    }
  }

  /// 獲取系所列表（用於查詢課程標準）
  /// 不需要登入
  Future<List<Map<String, dynamic>>> getDepartmentList(
    Map<String, String> code,
  ) async {
    try {
      final response = await _dio.post(
        _creditUrl,
        data: code,
      );
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      
      final document = html_parser.parse(response.data);
      final tableNode = document.getElementsByTagName("table").first;
      final nodes = tableNode.getElementsByTagName("a");
      final resultList = <Map<String, dynamic>>[];
      
      for (final node in nodes) {
        final href = node.attributes["href"];
        if (href == null) continue;
        
        final code = Uri.parse(href).queryParameters;
        final name = node.text.replaceAll(RegExp(r"[ |\s]"), "");
        resultList.add({
          "name": name,
          "code": code,
        });
      }
      
      return resultList;
    } catch (e) {
      debugPrint('[NTUT Course] getDepartmentList error: $e');
      rethrow;
    }
  }

  /// 獲取課程標準資訊（畢業學分標準）
  /// 不需要登入
  Future<Map<String, dynamic>?> getCreditInfo(
    Map<String, String> code,
    String select,
  ) async {
    try {
      final response = await _dio.post(
        _creditUrl,
        data: code,
      );
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      
      final document = html_parser.parse(response.data);
      final tableNode = document.getElementsByTagName("table").first;
      final trNodes = tableNode.getElementsByTagName("tr");
      
      // 移除表頭
      trNodes.removeAt(0);
      
      for (final trNode in trNodes) {
        final aNodes = trNode.getElementsByTagName("a");
        if (aNodes.isEmpty) continue;
        
        final aNode = aNodes.first;
        final name = aNode.text.replaceAll(RegExp(r"[ |\s]"), "");
        
        if (name.contains(select)) {
          final tdNodes = trNode.getElementsByTagName("td");
          final result = <String, int>{};
          
          // 解析各類學分
          for (int j = 1; j < tdNodes.length; j++) {
            final tdNode = tdNodes[j];
            final creditString = tdNode.text.replaceAll(RegExp(r"[\s|\n]"), "");
            
            try {
              final creditValue = int.parse(creditString);
              
              switch (j - 1) {
                case 0:
                  result["○"] = creditValue; // 部訂共同必修
                  break;
                case 1:
                  result["△"] = creditValue; // 校訂共同必修
                  break;
                case 2:
                  result["☆"] = creditValue; // 共同選修
                  break;
                case 3:
                  result["●"] = creditValue; // 部訂專業必修
                  break;
                case 4:
                  result["▲"] = creditValue; // 校訂專業必修
                  break;
                case 5:
                  result["★"] = creditValue; // 專業選修
                  break;
                case 6:
                  result["outerDepartmentMaxCredit"] = creditValue; // 外系最多承認學分
                  break;
                case 7:
                  result["lowCredit"] = creditValue; // 最低畢業學分
                  break;
              }
            } catch (e) {
              // 解析失敗，跳過
              continue;
            }
          }
          
          debugPrint('[NTUT Course] 找到 $select 的課程標準: $result');
          return result;
        }
      }
      
      debugPrint('[NTUT Course] 找不到 $select 的課程標準');
      return null;
    } catch (e) {
      debugPrint('[NTUT Course] getCreditInfo error: $e');
      rethrow;
    }
  }

  /// 獲取公開的課程大綱資訊（包含 category、openClass 和 dimension）
  /// 與 getCourseSyllabus 不同，這個方法不需要登入，從公開 API 獲取
  /// 用於獲取課程類別、開課班級、博雅向度等資訊
  Future<Map<String, String>?> getPublicCourseSyllabus(String courseId) async {
    try {
      const syllabusUrl = "https://aps.ntut.edu.tw/course/tw/ShowSyllabus.jsp";
      
      final response = await _dio.get(
        syllabusUrl,
        queryParameters: {"snum": courseId},
      );
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      
      final document = html_parser.parse(response.data);
      final tables = document.getElementsByTagName("table");
      
      if (tables.isEmpty) {
        debugPrint('[NTUT Course] 找不到課程大綱 table: $courseId');
        return null;
      }
      
      final trs = tables[0].getElementsByTagName("tr");
      if (trs.length < 2) {
        debugPrint('[NTUT Course] 課程大綱格式錯誤: $courseId');
        return null;
      }
      
      final syllabusRow = trs[1].getElementsByTagName("td");
      if (syllabusRow.length < 9) {
        debugPrint('[NTUT Course] 課程大綱欄位不足: $courseId (只有 ${syllabusRow.length} 個欄位)');
        return null;
      }
      
      final category = syllabusRow[6].text.trim(); // 課程類別（例如：●必、△、☆）
      final openClass = syllabusRow[8].text.trim(); // 開課班級（例如：資工一甲、博雅課程(八)）
      
      // 取得備註欄的向度資訊（第 11 欄）
      final dimension = syllabusRow.length >= 12 
          ? syllabusRow[11].text.trim() 
          : ''; // 博雅向度（例如：人文與藝術向度、社會科學向度）
      
      // 取得額外資訊以便調試
      final yearSemester = syllabusRow[0].text.trim();
      final courseName = syllabusRow[2].text.trim();
      
      debugPrint('[NTUT Course] 成功取得課程 $courseId ($courseName): '
            'category="$category", openClass="$openClass", dimension="$dimension", yearSem="$yearSemester"');
      
      return {
        'category': category,
        'openClass': openClass,
        'dimension': dimension, // 向度資訊
        'yearSemester': yearSemester,
        'courseName': courseName,
      };
    } catch (e) {
      debugPrint('[NTUT Course] getPublicCourseSyllabus error for $courseId: $e');
      return null;
    }
  }
}
