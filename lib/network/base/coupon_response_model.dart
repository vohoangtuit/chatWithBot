class CouponResponseModel{
  bool? status;
  String? message;
  int? error;
  String? url;
  String? time;
  String? sendOtp;

  CouponResponseModel({this.status, this.message, this.error, this.url,this.time,this.sendOtp});

  CouponResponseModel.fromJson(Map<String, dynamic> json) {
    if(json['status']!=null){
      status = json['status'];
    }else{
      status =false;
    }
    if(json['message']!=null){
      message = json['message'];
    }else{
      message='';
    }
    if(json['url']!=null){
      url = json['url'];
    }else{
      url='';
    }
    time = json['time']??'';
    if(json['sendOtp']!=null){
      sendOtp = json['sendOtp'];
    }else{
      sendOtp ='0';
    }

    //print('response $response');
  }
  factory CouponResponseModel.fromModel(CouponResponseModel json)=>CouponResponseModel(
    status: json.status??false,
    message: json.message??'',
    url: json.url??'',
    time: json.time??'0',
    sendOtp: json.sendOtp??'0',
  );

  @override
  String toString() {
    return 'CouponResponseModel{status: $status, message: $message, error: $error, url: $url, time: $time, sendOtp: $sendOtp}';
  }
}