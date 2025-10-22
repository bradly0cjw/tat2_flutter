import 'package:flutter/foundation.dart';
import '../adapters/ntut_school_adapter.dart';
import '../services/ischool_plus_service.dart';

/// iSchool+ Adapter Extension
/// 
/// 擴展 NTUT Adapter，加入 iSchool+ 相關功能
/// 不繼承 SchoolAdapter，因為 iSchool+ 是輔助系統，不是主要學校系統
class ISchoolPlusAdapter {
  final NtutSchoolAdapter _ntutAdapter;
  final ISchoolPlusService _service;
  
  bool _isLoggedIn = false;

  ISchoolPlusAdapter({
    required NtutSchoolAdapter ntutAdapter,
    required ISchoolPlusService service,
  })  : _ntutAdapter = ntutAdapter,
        _service = service;

  /// 是否已登入 iSchool+
  bool get isLoggedIn => _isLoggedIn;

  /// 登入 iSchool+
  /// 
  /// 前提：必須先登入 NTUT Portal
  Future<bool> login({bool autoRetry = true}) async {
    try {
      // 檢查是否已登入 NTUT
      if (!_ntutAdapter.isLoggedIn) {
        throw SchoolAdapterException('必須先登入 NTUT Portal 才能登入 iSchool+');
      }

      debugPrint('[ISchoolPlus] 開始登入');
      
      final success = await _service.login();
      _isLoggedIn = success;
      
      if (success) {
        debugPrint('[ISchoolPlus] 登入成功');
      } else {
        debugPrint('[ISchoolPlus] 登入失敗');
      }
      
      return success;
    } catch (e) {
      debugPrint('[ISchoolPlus] 登入錯誤: $e');
      
      if (_isSessionExpired(e)) {
        throw SessionExpiredException('iSchool+ Session 已過期');
      }
      
      throw SchoolAdapterException('iSchool+ 登入錯誤: $e', e);
    }
  }

  /// 確保已登入（如果未登入則自動登入）
  Future<void> _ensureLoggedIn() async {
    if (!_isLoggedIn) {
      debugPrint('[ISchoolPlus] 尚未登入，自動登入');
      final success = await login();
      if (!success) {
        throw SchoolAdapterException('iSchool+ 自動登入失敗');
      }
    }
  }

  /// 帶自動重新登入的操作執行器
  Future<T> _executeWithAutoRelogin<T>({
    required Future<T> Function() operation,
    required String operationName,
  }) async {
    try {
      await _ensureLoggedIn();
      return await operation();
    } on SessionExpiredException {
      debugPrint('[$operationName] iSchool+ Session 過期，重新登入');
      
      // 重置登入狀態
      _isLoggedIn = false;
      _service.resetLoginState();
      
      // 重新登入
      final reloginSuccess = await login();
      if (!reloginSuccess) {
        throw SchoolAdapterException('iSchool+ 重新登入失敗');
      }
      
      debugPrint('[$operationName] 重新登入成功，重新執行操作');
      return await operation();
    } catch (e) {
      if (_isSessionExpired(e)) {
        debugPrint('[$operationName] 偵測到 Session 過期，重新登入');
        
        _isLoggedIn = false;
        _service.resetLoginState();
        
        final reloginSuccess = await login();
        if (!reloginSuccess) {
          throw SchoolAdapterException('iSchool+ 重新登入失敗: $e', e);
        }
        
        debugPrint('[$operationName] 重新登入成功，重新執行操作');
        return await operation();
      }
      
      rethrow;
    }
  }

  /// 登出
  Future<void> logout() async {
    debugPrint('[ISchoolPlus] 登出');
    await _service.logout();
    _isLoggedIn = false;
  }

  /// 獲取課程列表
  Future<List<CourseInfo>> getCourses() async {
    return _executeWithAutoRelogin(
      operation: () => _service.connector.getCourseList(),
      operationName: '獲取課程列表',
    );
  }

  /// 獲取課程公告
  Future<List<Announcement>> getCourseAnnouncements(String courseId) async {
    return _executeWithAutoRelogin(
      operation: () => _service.connector.getCourseAnnouncements(courseId),
      operationName: '獲取課程公告',
    );
  }

  /// 獲取課程檔案
  Future<List<CourseFile>> getCourseFiles(String courseId) async {
    return _executeWithAutoRelogin(
      operation: () => _service.connector.getCourseFiles(courseId),
      operationName: '獲取課程檔案',
    );
  }

  /// 下載檔案
  Future<void> downloadFile({
    required String fileId,
    required String fileName,
    required String savePath,
    Function(int, int)? onProgress,
  }) async {
    return _executeWithAutoRelogin(
      operation: () => _service.connector.downloadFile(
        fileId: fileId,
        fileName: fileName,
        savePath: savePath,
        onProgress: onProgress,
      ),
      operationName: '下載檔案',
    );
  }

  /// 判斷錯誤是否為 Session 過期
  bool _isSessionExpired(dynamic error) {
    if (error is SessionExpiredException) {
      return true;
    }
    
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('session') ||
        errorStr.contains('lost') ||
        errorStr.contains('login') ||
        errorStr.contains('登入') ||
        errorStr.contains('unauthorized');
  }
}
