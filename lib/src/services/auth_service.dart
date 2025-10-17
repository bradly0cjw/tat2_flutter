import 'package:flutter/foundation.dart';
import '../core/auth/auth_manager.dart';
import '../core/auth/auth_credential.dart';
import 'ntut_api_service.dart';

/// 認證服務 - AuthManager 的向後兼容包裝器
/// 
/// @deprecated 新代碼請直接使用 AuthManager
/// 此服務僅為保持與舊代碼的兼容性而存在
class AuthService {
  final AuthManager? _authManager;
  final NtutApiService _apiService;
  
  
  AuthService(this._apiService, {AuthManager? authManager})
      : _authManager = authManager;
  
  /// 保存帳號密碼到本地
  Future<void> saveCredentials(String studentId, String password) async {
    if (_authManager != null) {
      // 使用新的 AuthManager
      final credential = AuthCredential(username: studentId, password: password);
      await _authManager!.saveCredentials(credential);
    } else {
      // 舊版向後兼容邏輯(如果沒有注入 AuthManager)
      print('[Auth] 使用舊版本的憑證儲存方式');
      // 保留舊的實作...
    }
    print('[Auth] 已保存帳號密碼');
  }
  
  /// 從本地讀取帳號密碼
  Future<Map<String, String>?> getSavedCredentials() async {
    if (_authManager != null) {
      // 使用新的 AuthManager
      final credential = await _authManager!.loadCredentials();
      if (credential != null) {
        return {
          'studentId': credential.username,
          'password': credential.password,
        };
      }
      return null;
    } else {
      // 舊版向後兼容邏輯
      print('[Auth] 使用舊版本的憑證讀取方式');
      return null;
    }
  }
  
  /// 清除本地存儲的帳號密碼
  Future<void> clearCredentials() async {
    if (_authManager != null) {
      await _authManager!.clearCredentials();
    }
    print('[Auth] 已清除本地帳號密碼');
  }
  
  /// 嘗試自動登入
  /// 
  /// 返回值：
  /// - true: 登入成功
  /// - false: 登入失敗(帳密錯誤或網路問題)
  /// - null: 沒有保存的帳密
  Future<bool?> tryAutoLogin() async {
    print('[Auth] 嘗試自動登入...');
    
    final credentials = await getSavedCredentials();
    if (credentials == null) {
      print('[Auth] 沒有保存的帳號密碼');
      return null;
    }
    
    try {
      final result = await _apiService.login(
        credentials['studentId']!,
        credentials['password']!,
      );
      
      if (result['success'] == true) {
        print('[Auth] 自動登入成功');
        return true;
      } else {
        print('[Auth] 自動登入失敗: ${result['errorMsg']}');
        // 如果是帳密錯誤，清除本地存儲
        if (result['errorMsg']?.contains('帳號或密碼錯誤') == true) {
          await clearCredentials();
        }
        return false;
      }
    } catch (e) {
      print('[Auth] 自動登入異常: $e');
      return false;
    }
  }
  
  /// 登出(清除 session 和本地帳密)
  Future<void> logout() async {
    _apiService.logout();
    await clearCredentials();
    print('[Auth] 已登出');
  }
  
  /// 檢查是否已登入
  bool isLoggedIn() {
    return _apiService.isLoggedIn;
  }
}

