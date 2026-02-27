import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class CustomLogInterceptor extends LogInterceptor {
  CustomLogInterceptor()
      : super(
    request: true,
    requestHeader: true,
    requestBody: true,
    responseHeader: false,
    responseBody: true,
    error: true,
    logPrint: (object) {
    printLongLog('VTV: ${object.toString()}');
  },
  );


}  void printLongLog(String text) {
  const int maxLogSize = 1000;
  for (var i = 0; i < text.length; i += maxLogSize) {
    final endIndex = (i + maxLogSize < text.length) ? i + maxLogSize : text.length;
    debugPrint(text.substring(i, endIndex));
  }
}