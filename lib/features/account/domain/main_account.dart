/// A dynamic_asoul account. [email] is the verified address; an account
/// without one must bind it before collections sync.
class MainUser {
  const MainUser(this.id, this.username, {this.email});
  final String id;
  final String username;
  final String? email;

  factory MainUser.fromJson(Map<String, dynamic> value) => MainUser(
    value['id'] as String,
    value['username'] as String,
    email: value['email'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
  };
}

class MainSession {
  const MainSession(this.token, this.user);
  final String token;
  final MainUser user;
}

abstract interface class MainCredentialVault {
  Future<MainSession?> read();
  Future<void> write(MainSession session);
  Future<void> clear();
}

class MainAccountFailure implements Exception {
  const MainAccountFailure(this.message, {this.expired = false});
  final String message;
  final bool expired;
  @override
  String toString() => message;
}
