
import 'package:dio/dio.dart';
import 'package:retrofit/error_logger.dart';
import 'package:retrofit/http.dart';
import 'package:robot/model/chat_model.dart';

import 'cloud_response.dart';

part 'cloud_api_provider.g.dart';
@RestApi(baseUrl: '')
abstract class CloudApiProvider{
  factory CloudApiProvider(Dio dio, {String? baseUrl}) {
    return _CloudApiProvider(dio, baseUrl: baseUrl);
  }

  @POST('chatWithAi')
  Future<CloudResponse> chatWithAi(@Body() ChatModel data);
}



