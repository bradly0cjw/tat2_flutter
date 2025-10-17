/// 認證憑證 - 統一的帳密封裝
class AuthCredential {
  final String username;
  final String password;

  const AuthCredential({
    required this.username,
    required this.password,
  });

  @override
  String toString() => 'AuthCredential(username: $username, password: ***)';
}
