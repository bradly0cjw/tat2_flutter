import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

/// 北科大課程系統連接器
/// 完全按照 TAT 的實作方式，從 aps.ntut.edu.tw 獲取課程標準資料
class NtutCourseConnector {
  static const String _creditUrl = "https://aps.ntut.edu.tw/course/tw/Cprog.jsp";
  
  /// 獲取所有學年度列表
  /// 對應 TAT 的 getYearList
  static Future<List<String>> getYearList() async {
    try {
      final response = await http.post(
        Uri.parse(_creditUrl),
        body: {"format": "-1"},
      );
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      
      final document = parse(response.body);
      final nodes = document.getElementsByTagName("a");
      final resultList = <String>[];
      
      for (final node in nodes) {
        resultList.add(node.text);
      }
      
      return resultList;
    } catch (e) {
      print('[NtutCourseConnector] getYearList error: $e');
      rethrow;
    }
  }
  
  /// 獲取學制列表
  /// 對應 TAT 的 getDivisionList
  /// 返回 Map 包含 name 和 code
  static Future<List<Map<String, dynamic>>> getDivisionList(String year) async {
    try {
      final response = await http.post(
        Uri.parse(_creditUrl),
        body: {"format": "-2", "year": year},
      );
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      
      final document = parse(response.body);
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
      print('[NtutCourseConnector] getDivisionList error: $e');
      rethrow;
    }
  }
  
  /// 獲取系所列表
  /// 對應 TAT 的 getDepartmentList
  static Future<List<Map<String, dynamic>>> getDepartmentList(
    Map<String, String> code,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(_creditUrl),
        body: code,
      );
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      
      final document = parse(response.body);
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
      print('[NtutCourseConnector] getDepartmentList error: $e');
      rethrow;
    }
  }
  
  /// 獲取課程標準資訊（畢業學分標準）
  /// 對應 TAT 的 getCreditInfo
  static Future<Map<String, dynamic>?> getCreditInfo(
    Map<String, String> code,
    String select,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(_creditUrl),
        body: code,
      );
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      
      final document = parse(response.body);
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
          
          print('[NtutCourseConnector] 找到 $select 的課程標準: $result');
          return result;
        }
      }
      
      print('[NtutCourseConnector] 找不到 $select 的課程標準');
      return null;
    } catch (e) {
      print('[NtutCourseConnector] getCreditInfo error: $e');
      rethrow;
    }
  }

  /// 獲取課程大綱資訊（包含 category、openClass 和 dimension）
  /// 對應 TAT 的 getCourseCategory
  static Future<Map<String, String>?> getCourseSyllabus(String courseId) async {
    try {
      // 修正：使用正確的 URL (ShowSyllabus.jsp 而非 Select.jsp)
      const syllabusUrl = "https://aps.ntut.edu.tw/course/tw/ShowSyllabus.jsp";
      
      // 修正：使用 GET 方法並透過 query parameters 傳遞參數
      final uri = Uri.parse(syllabusUrl).replace(
        queryParameters: {"snum": courseId},
      );
      
      final response = await http.get(uri);
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      
      final document = parse(response.body);
      final tables = document.getElementsByTagName("table");
      
      if (tables.isEmpty) {
        print('[NtutCourseConnector] 找不到課程大綱 table: $courseId');
        return null;
      }
      
      final trs = tables[0].getElementsByTagName("tr");
      if (trs.length < 2) {
        print('[NtutCourseConnector] 課程大綱格式錯誤: $courseId');
        return null;
      }
      
      final syllabusRow = trs[1].getElementsByTagName("td");
      if (syllabusRow.length < 9) {
        print('[NtutCourseConnector] 課程大綱欄位不足: $courseId (只有 ${syllabusRow.length} 個欄位)');
        return null;
      }
      
      final category = syllabusRow[6].text.trim(); // 課程類別（例如：●必、△、☆）
      final openClass = syllabusRow[8].text.trim(); // 開課班級（例如：資工一甲、博雅課程(八)）
      
      // 新增：取得備註欄的向度資訊（第 11 欄）
      final dimension = syllabusRow.length >= 12 
          ? syllabusRow[11].text.trim() 
          : ''; // 博雅向度（例如：人文與藝術向度、社會科學向度）
      
      // 取得額外資訊以便調試
      final yearSemester = syllabusRow[0].text.trim();
      final courseName = syllabusRow[2].text.trim();
      
      print('[NtutCourseConnector] 成功取得課程 $courseId ($courseName): '
            'category="$category", openClass="$openClass", dimension="$dimension", yearSem="$yearSemester"');
      
      return {
        'category': category,
        'openClass': openClass,
        'dimension': dimension, // 向度資訊
        'yearSemester': yearSemester,
        'courseName': courseName,
      };
    } catch (e) {
      print('[NtutCourseConnector] getCourseSyllabus error for $courseId: $e');
      return null;
    }
  }
}
