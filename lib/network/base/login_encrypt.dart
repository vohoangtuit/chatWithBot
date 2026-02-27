class LoginEncrypt{
  String? username;

  LoginEncrypt({this.username});

  Map<String, dynamic> toJson(){
    final data = <String, dynamic>{};
    data['username'] = username;
    return data;
  }

  @override
  String toString() {
    return 'LoginEncrypt{username: $username}';
  }
}