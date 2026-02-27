class ErrorAuthenticate{
  int? status;
  String? message;

  ErrorAuthenticate({this.status, this.message});

  @override
  String toString() {
    return 'ErrorAuthenticate{status: $status, message: $message}';
  }
}