import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:robot/network/cloud/cloud_api_provider.dart';
import 'package:robot/screens/general/base_screen.dart';

class CloudApiConfig{
  static String baseUrl ="https://us-central1-vietravel-app.cloudfunctions.net/";
  late CloudApiProvider apiCloud;
  final BaseScreen screen;
  CloudApiConfig.internal(this.screen){
    Dio dio = Dio();

    dio.interceptors.add(BigQueryInterceptors());
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: true));
    }
    apiCloud = CloudApiProvider(dio, baseUrl: baseUrl);
  }
  void showLoading(bool show) {
    screen.showLoading(show);
  }
}
class BigQueryInterceptors extends InterceptorsWrapper {
  @override
  Future onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final headers = <String, dynamic>{};
    headers['Content-Type'] = 'application/json';
    options.headers = headers;
    if(kDebugMode){
      if(options.data!=null){
        print(" 🚀json: ${jsonEncode(options.data)}");
      }
    }
    return super.onRequest(options, handler);
  }


  @override
  onResponse(Response response, ResponseInterceptorHandler handler) {
    // print('response ${response.data.toString()}');
    return super.onResponse(response, handler);
  }

  @override
  onError(DioException err, ErrorInterceptorHandler handler) {
    // var url = err.request.uri;
    // print("************************************************");
    // print(err);
    super.onError(err, handler);
  }
}