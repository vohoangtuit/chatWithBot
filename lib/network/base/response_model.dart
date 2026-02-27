import '../../utils/validators.dart';

class ResponseModel<T> {
  int? status;
  int? code;
  String? message;
  T? response;
  int? totalRecord;

  ResponseModel(
      {this.status, this.code, this.message, this.response, this.totalRecord});

  ResponseModel.fromJson(
      Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJsonT) {
    status = json['status'];
    code = json['code'];
    message = json['message'] != null && Utils.isNotEmpty(json['message'])
        ? json['message']
        : '';
    totalRecord = json['totalRecord'] ?? 0;

    if (json['response'] != null &&
        Utils.isNotEmpty(json['response'].toString())) {
      if (json['response'] is Map<String, dynamic>) {
        response = fromJsonT(json['response'] as Map<String, dynamic>);
      } else {
        response = json['response'] as T;
      }
    }
  }

  @override
  String toString() {
    return 'ResponseModel{status: $status, message: $message, response: $response}';
  }
}
