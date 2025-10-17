/// 認證結果
class AuthResult {
  final bool success;
  final String? message;
  final String? sessionId;
  final Map<String, dynamic>? userData;

  const AuthResult({
    required this.success,
    this.message,
    this.sessionId,
    this.userData,
  });

  factory AuthResult.success({
    String? message,
    String? sessionId,
    Map<String, dynamic>? userData,
  }) {
    return AuthResult(
      success: true,
      message: message ?? '登入成功',
      sessionId: sessionId,
      userData: userData,
    );
  }

  factory AuthResult.failure({
    required String message,
  }) {
    return AuthResult(
      success: false,
      message: message,
    );
  }

  @override
  String toString() => 'AuthResult(success: $success, message: $message)';
}
