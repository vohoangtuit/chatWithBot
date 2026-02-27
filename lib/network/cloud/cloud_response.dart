import '../../utils/validators.dart';

class CloudResponse{
  bool? success;
  String? message;
  String? reply;
  String? error;

  dynamic data;
  CloudResponse({this.success, this.message, this.data,this.error});

  CloudResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'] ?? false;
    message = json['message'] ?? "Error";
    reply = json['reply']??'' ;
    error = json['error']??'' ;
    if(json['data']!=null){
      if(Utils.isNotEmpty(json['data'].toString())){
        data = json['data'];
      }
    }
  }

}