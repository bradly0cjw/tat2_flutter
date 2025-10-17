import 'dart:async';
import 'package:flutter/foundation.dart';
import '../adapter/school_adapter.dart';
import '../auth/auth_manager.dart';

/// 重試策略
class RetryPolicy {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;

  RetryPolicy({
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.backoffMultiplier = 2.0,
  });

  /// 執行帶重試的操作
  /// 
  /// [operation] 要執行的操作
  /// [operationName] 操作名稱（用於日誌）
  /// [shouldRetry] 判斷是否應該重試（可選）
  Future<T> execute<T>({
    required Future<T> Function() operation,
    required String operationName,
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (true) {
      attempt++;
      
      try {
        return await operation();
      } catch (e) {
        final canRetry = shouldRetry?.call(e) ?? _defaultShouldRetry(e);
        
        if (attempt >= maxRetries || !canRetry) {
          debugPrint('[RetryPolicy] [$operationName] 失敗，已達最大重試次數: $e');
          rethrow;
        }
        
        debugPrint('[RetryPolicy] [$operationName] 嘗試 $attempt 失敗，${delay.inMilliseconds}ms 後重試');
        await Future.delayed(delay);
        delay *= backoffMultiplier;
      }
    }
  }

  bool _defaultShouldRetry(dynamic error) {
    // 網路錯誤、超時等可以重試
    // 帳密錯誤不應重試
    if (error is AuthenticationException) {
      return false;
    }
    return true;
  }
}

/// 帶自動重新登入的重試策略
class RetryWithReloginPolicy {
  final RetryPolicy retryPolicy;
  final AuthManager authManager;

  RetryWithReloginPolicy({
    required this.authManager,
    RetryPolicy? retryPolicy,
  }) : retryPolicy = retryPolicy ?? RetryPolicy();

  /// 執行操作，如果遇到 Session 過期則自動重新登入後重試
  /// 
  /// [operation] 要執行的操作
  /// [operationName] 操作名稱
  /// [maxReloginAttempts] 最大重新登入嘗試次數（預設1次）
  Future<T> execute<T>({
    required Future<T> Function() operation,
    required String operationName,
    int maxReloginAttempts = 1,
  }) async {
    int reloginAttempts = 0;
    
    while (true) {
      try {
        // 在執行操作前，檢查 Session 是否可能已過期
        if (authManager.isSessionLikelyExpired && reloginAttempts == 0) {
          debugPrint('[RetryPolicy] [$operationName] Session 可能已過期，先嘗試刷新');
          final refreshResult = await authManager.relogin();
          if (!refreshResult.success) {
            debugPrint('[RetryPolicy] [$operationName] 刷新失敗，繼續執行操作');
          }
        }
        
        return await retryPolicy.execute(
          operation: operation,
          operationName: operationName,
        );
      } on SessionExpiredException catch (e) {
        reloginAttempts++;
        
        if (reloginAttempts > maxReloginAttempts) {
          debugPrint('[RetryPolicy] [$operationName] 已達最大重新登入次數 ($maxReloginAttempts)');
          throw SchoolAdapterException(
            '多次重新登入失敗，請手動重新登入',
            e,
          );
        }
        
        debugPrint('[RetryPolicy] [$operationName] Session 過期，嘗試重新登入（第 $reloginAttempts 次）');
        
        // 重新登入
        final reloginResult = await authManager.relogin();
        if (!reloginResult.success) {
          throw SchoolAdapterException(
            '重新登入失敗: ${reloginResult.message}',
            e,
          );
        }
        
        debugPrint('[RetryPolicy] [$operationName] 重新登入成功，重新執行操作');
        
        // 繼續迴圈，重新執行操作
        continue;
      } catch (e) {
        // 檢查錯誤訊息中是否包含 Session 過期的關鍵字
        final errorMessage = e.toString().toLowerCase();
        final sessionExpiredKeywords = [
          'session',
          'expired',
          'timeout',
          '過期',
          '逾時',
          'unauthorized',
          '401',
        ];
        
        final isSessionError = sessionExpiredKeywords.any(
          (keyword) => errorMessage.contains(keyword),
        );
        
        if (isSessionError && reloginAttempts < maxReloginAttempts) {
          reloginAttempts++;
          debugPrint('[RetryPolicy] [$operationName] 檢測到可能的 Session 錯誤，嘗試重新登入（第 $reloginAttempts 次）');
          
          final reloginResult = await authManager.relogin();
          if (reloginResult.success) {
            debugPrint('[RetryPolicy] [$operationName] 重新登入成功，重新執行操作');
            continue;
          }
        }
        
        // 非 Session 錯誤或重新登入失敗，直接拋出
        rethrow;
      }
    }
  }
}
