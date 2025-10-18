import 'package:flutter/foundation.dart';
import '../core/auth/auth_manager.dart';
import '../core/auth/auth_credential.dart';
import '../core/auth/auth_result.dart';

/// 認證狀態 Provider(重構版)
/// 
/// 使用 AuthManager 統一管理認證,簡化邏輯
class AuthProviderV2 with ChangeNotifier {
  final AuthManager _authManager;

  bool _isLoading = false;
  String? _error;
  AuthResult? _lastAuthResult;

  AuthProviderV2({required AuthManager authManager})
      : _authManager = authManager;

  // Getters
  bool get isLoggedIn => _authManager.isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AuthCredential? get currentCredential => _authManager.currentCredential;
  String? get username => _authManager.currentCredential?.username;
  AuthState get authState => _authManager.authState;
  bool get isOfflineMode => _authManager.isOfflineMode;
  
  /// 是否可以使用需要登入的功能
  bool get canUseAuthenticatedFeatures => isLoggedIn;
  
  /// 是否可以使用本地緩存功能（離線模式）
  bool get canUseOfflineFeatures => true; // 永遠為 true

  /// 登入
  /// 
  /// [username] 帳號
  /// [password] 密碼
  /// [rememberMe] 是否記住帳號密碼
  Future<bool> login({
    required String username,
    required String password,
    bool rememberMe = true,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('[AuthProvider] 開始登入: $username');

      final credential = AuthCredential(
        username: username,
        password: password,
      );

      final result = await _authManager.login(
        credential,
        saveCredentials: rememberMe,
      );

      _lastAuthResult = result;

      if (result.success) {
        debugPrint('[AuthProvider] 登入成功');
        _error = null;
      } else {
        debugPrint('[AuthProvider] 登入失敗: ${result.message}');
        _error = result.message;
      }

      _isLoading = false;
      notifyListeners();

      return result.success;
    } catch (e, stackTrace) {
      _error = '登入錯誤: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('[AuthProvider] 登入錯誤: $e\n$stackTrace');
      return false;
    }
  }

  /// 嘗試自動登入
  Future<bool> tryAutoLogin() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('[AuthProvider] 嘗試自動登入...');

      final result = await _authManager.tryAutoLogin();

      _lastAuthResult = result;

      if (result == null) {
        debugPrint('[AuthProvider] 沒有保存的憑證');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (result.success) {
        debugPrint('[AuthProvider] 自動登入成功');
        _error = null;
      } else {
        final errorMsg = result.message ?? '';
        debugPrint('[AuthProvider] 自動登入失敗: $errorMsg');
        _error = errorMsg;
        
        // 如果是網路錯誤，不視為致命錯誤
        if (errorMsg.contains('connection') ||
            errorMsg.contains('host lookup') ||
            errorMsg.contains('network') ||
            errorMsg.contains('Socket')) {
          debugPrint('[AuthProvider] 網路連接失敗，進入離線模式');
        }
      }

      _isLoading = false;
      notifyListeners();

      return result.success;
    } catch (e, stackTrace) {
      final errorStr = e.toString();
      _error = '自動登入錯誤: $errorStr';
      _isLoading = false;
      notifyListeners();
      debugPrint('[AuthProvider] 自動登入錯誤: $e\n$stackTrace');
      
      // 檢查是否為網路錯誤
      if (errorStr.contains('connection') ||
          errorStr.contains('host lookup') ||
          errorStr.contains('network') ||
          errorStr.contains('Socket')) {
        debugPrint('[AuthProvider] 網路異常，進入離線模式');
      }
      
      return false;
    }
  }

  /// 登出
  /// 
  /// [clearCredentials] 是否清除本地保存的帳號密碼
  Future<void> logout({bool clearCredentials = false}) async {
    try {
      debugPrint('[AuthProvider] 登出');

      await _authManager.logout(clearLocalCredentials: clearCredentials);

      _error = null;
      _lastAuthResult = null;
      notifyListeners();

      debugPrint('[AuthProvider] 登出成功');
    } catch (e, stackTrace) {
      debugPrint('[AuthProvider] 登出錯誤: $e\n$stackTrace');
    }
  }

  /// 檢查 Session 是否有效
  Future<bool> checkSession() async {
    try {
      return await _authManager.checkSession();
    } catch (e) {
      debugPrint('[AuthProvider] 檢查 Session 失敗: $e');
      return false;
    }
  }

  /// 清除錯誤訊息
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
