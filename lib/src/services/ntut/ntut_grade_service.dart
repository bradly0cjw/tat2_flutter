import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'ntut_auth_service.dart';

/// NTUT 成績服務
/// 處理成績查詢、排名查詢等功能
class NtutGradeService {
  final NtutAuthService _authService;
  late final Dio _dio;
  late final CookieJar _cookieJar;

  static const String userAgent = 'Direk ios App';

  NtutGradeService({required NtutAuthService authService})
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

  /// SSO 登入到成績系統
  Future<bool> _loginToScoreSystem() async {
    try {
      print('[NTUT Grade] 開始 SSO 登入到成績系統...');
      
      if (!_authService.isLoggedIn) {
        throw Exception('尚未登入 NTUT 系統，請先登入');
      }
      
      const ssoIndexUrl = '${NtutAuthService.baseUrl}/ssoIndex.do';
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
      
      String htmlContent;
      if (ssoIndexResponse.data is String) {
        htmlContent = ssoIndexResponse.data as String;
      } else {
        htmlContent = ssoIndexResponse.data.toString();
      }
      
      final htmlDoc = html_parser.parse(htmlContent);
      final inputNodes = htmlDoc.querySelectorAll('input');
      final formNodes = htmlDoc.querySelectorAll('form');
      
      if (formNodes.isEmpty) {
        throw Exception('找不到 OAuth2 表單');
      }
      
      final formNode = formNodes.first;
      final jumpUrl = formNode.attributes['action'];
      if (jumpUrl == null || jumpUrl.isEmpty) {
        throw Exception('找不到跳轉 URL');
      }
      
      final oauthData = <String, String>{};
      for (final input in inputNodes) {
        final name = input.attributes['name'];
        final value = input.attributes['value'];
        if (name != null && value != null) {
          oauthData[name] = value;
        }
      }
      
      String fullJumpUrl;
      if (jumpUrl.startsWith('http')) {
        fullJumpUrl = jumpUrl;
      } else if (jumpUrl.startsWith('/')) {
        fullJumpUrl = '${NtutAuthService.baseUrl}$jumpUrl';
      } else {
        fullJumpUrl = '${NtutAuthService.baseUrl}/$jumpUrl';
      }
      
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
          
          if (jumpResponse.statusCode != 302) {
            await Future.delayed(const Duration(milliseconds: 100));
            continue;
          }
          
          final location = jumpResponse.headers.value('location');
          if (location == null) {
            await Future.delayed(const Duration(milliseconds: 100));
            continue;
          }
          
          final finalResponse = await _dio.post(
            location,
            options: Options(
              followRedirects: true,
              validateStatus: (status) => status! < 500,
            ),
          );
          
          final responseText = finalResponse.data.toString();
          if (responseText.contains('中斷連線')) {
            await Future.delayed(const Duration(milliseconds: 100));
            continue;
          }
          
          print('[NTUT Grade] SSO 登入成績系統成功');
          return true;
        } catch (e) {
          if (retry == 2) rethrow;
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      return false;
    } catch (e, stack) {
      print('[NTUT Grade] SSO 登入成績系統失敗: $e');
      debugPrint('[NTUT Grade] Stack trace: $stack');
      return false;
    }
  }

  /// 取得成績
  Future<List<Map<String, dynamic>>> getGrades() async {
    try {
      print('[NTUT Grade] 獲取成績資料');
      
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
            debugPrint('[NTUT Grade] 解析第 $j 行成績失敗: $e');
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
          debugPrint('[NTUT Grade] 解析學期 $semesterCode 統計失敗: $e');
        }
      }
      
      print('[NTUT Grade] 成功獲取 ${grades.length} 筆成績');
      return grades;
    } catch (e) {
      print('[NTUT Grade] 獲取成績失敗: $e');
      return [];
    }
  }

  /// 取得排名資料
  Future<Map<String, Map<String, dynamic>>> getScoreRanks() async {
    try {
      print('[NTUT Grade] 獲取排名資料');
      
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
        return null;
      };
      
      scoreDio.interceptors.add(CookieManager(_cookieJar));
      
      final response = await scoreDio.get(
        '/StuQuery/QryRank.jsp',
        queryParameters: {'format': '-2'},
      );
      
      if (response.statusCode != 200) {
        throw Exception('獲取排名頁面失敗: ${response.statusCode}');
      }
      
      final htmlDoc = html_parser.parse(response.data);
      final rankMap = <String, Map<String, dynamic>>{};
      
      final tbody = htmlDoc.querySelector('tbody');
      if (tbody == null) {
        print('[NTUT Grade] 找不到排名表格');
        return rankMap;
      }
      
      final rankRows = tbody.querySelectorAll('tr')
          .where((row) => row.querySelectorAll('td').length >= 7)
          .toList()
          .reversed
          .toList();
      
      Map<String, dynamic>? overallRank;
      
      for (int i = 0; i < (rankRows.length / 3).floor(); i++) {
        try {
          final semesterRow = rankRows[i * 3 + 2];
          final classRankRow = rankRows[i * 3 + 2];
          final deptRankRow = rankRows[i * 3];
          
          final semesterText = semesterRow.querySelectorAll('td')[0].innerHtml.split('<br>').first.trim();
          final semesterParts = semesterText.split(' ');
          if (semesterParts.length < 2) continue;
          
          final year = semesterParts[0];
          final semester = semesterParts.last;
          final semesterCode = '$year-$semester';
          
          final classRankCells = classRankRow.querySelectorAll('td');
          final classRank = double.tryParse(classRankCells[2].text.trim());
          final classTotal = double.tryParse(classRankCells[3].text.trim());
          final classPercentage = double.tryParse(
            classRankCells[4].text.replaceAll(RegExp(r'[%|\s]'), '').trim()
          );
          
          final deptRankCells = deptRankRow.querySelectorAll('td');
          final deptRank = double.tryParse(deptRankCells[1].text.trim());
          final deptTotal = double.tryParse(deptRankCells[2].text.trim());
          final deptPercentage = double.tryParse(
            deptRankCells[3].text.replaceAll(RegExp(r'[%|\s]'), '').trim()
          );
          
          if (classRankCells.length >= 8) {
            final overallClassRank = double.tryParse(classRankCells[5].text.trim());
            final overallClassTotal = double.tryParse(classRankCells[6].text.trim());
            final overallDeptRank = double.tryParse(deptRankCells[4].text.trim());
            final overallDeptTotal = double.tryParse(deptRankCells[5].text.trim());
            
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
          print('[NTUT Grade] 解析第 $i 個排名失敗: $e');
          continue;
        }
      }
      
      if (overallRank != null) {
        rankMap['_overall'] = overallRank;
      }
      
      print('[NTUT Grade] 成功獲取 ${rankMap.length} 個學期的排名（含總排名）');
      return rankMap;
    } catch (e) {
      print('[NTUT Grade] 獲取排名失敗: $e');
      return {};
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
    
    final numericScore = double.tryParse(grade);
    if (numericScore != null) {
      return numericScore;
    }
    
    final scoreMap = {
      'A+': 95.0, 'A': 90.0, 'A-': 85.0,
      'B+': 82.0, 'B': 78.0, 'B-': 75.0,
      'C+': 72.0, 'C': 68.0, 'C-': 65.0,
      'D': 60.0, 'F': 50.0, 'X': 0.0,
    };
    return scoreMap[grade.toUpperCase()];
  }
}
